import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:video_player/video_player.dart';

import '../services/document_converter.dart';
import '../services/file_tools.dart';
import '../services/temporary_media_copy.dart';
import '../services/viewer_format.dart';
import 'latest_request_guard.dart';
import 'video_playback_clock.dart';

/// A separate, read-only route. It never mutates the selected file or the PDF
/// editor's unsaved state. All decoding happens on-device.
class FilePreviewPage extends StatefulWidget {
  const FilePreviewPage({
    super.key,
    required this.file,
    this.temporaryDirectory,
    this.availableTempBytes,
    this.audioPlayerLoader,
    this.videoControllerLoader,
  });

  final PlatformFile file;
  final Future<Directory> Function()? temporaryDirectory;
  final Future<int?> Function()? availableTempBytes;
  final Future<AudioPlayer> Function(String path)? audioPlayerLoader;
  final Future<VideoPlayerController> Function(String path)?
  videoControllerLoader;

  @override
  State<FilePreviewPage> createState() => _FilePreviewPageState();
}

class _FilePreviewPageState extends State<FilePreviewPage> {
  static const _maxTextBytes = 2 * 1024 * 1024;
  static const _maxPdfBytes = 50 * 1024 * 1024;
  static const _maxImageBytes = 40 * 1024 * 1024;
  static const _maxAudioBytes = 200 * 1024 * 1024;
  static const _maxVideoBytes = 1024 * 1024 * 1024;

  late final ViewerKind _kind = ViewerFormat.forName(widget.file.name);
  bool _loading = true;
  String? _error;
  String? _text;
  List<String>? _textLines;
  String? _mediaPath;
  String? _ownedTempPath;
  String? _warning;
  PdfControllerPinch? _pdf;
  AudioPlayer? _audio;
  VideoPlayerController? _video;
  Timer? _videoUiTimer;
  final Stopwatch _videoElapsed = Stopwatch();
  Duration _videoAnchor = Duration.zero;
  bool _videoPlayRequested = false;
  bool _abandoned = false;
  bool? _nativeWasPlaying;
  bool? _nativeWasBuffering;
  Duration _lastNativePosition = Duration.zero;
  Duration? _pendingVideoSeek;
  Timer? _seekDebounce;
  final LatestRequestGuard _videoSeekGuard = LatestRequestGuard();
  StreamSubscription<PlaybackEvent>? _audioEvents;
  Timer? _audioSeekDebounce;
  Duration? _pendingAudioSeek;
  final LatestRequestGuard _audioSeekGuard = LatestRequestGuard();
  TemporaryMediaCopy? _mediaCopy;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _abandoned = true;
    _videoUiTimer?.cancel();
    _seekDebounce?.cancel();
    _videoSeekGuard.invalidate();
    _audioSeekDebounce?.cancel();
    _audioSeekGuard.invalidate();
    unawaited(_mediaCopy?.cancel() ?? Future<void>.value());
    unawaited(_audioEvents?.cancel() ?? Future<void>.value());
    // An in-flight Office conversion or codec initialization may finish after
    // the user presses Back. In that case _prepare's finally block owns
    // cleanup; disposing here too would race with initialization.
    if (!_loading) {
      _pdf?.dispose();
      unawaited(_releaseMedia());
    }
    super.dispose();
  }

  Future<void> _releaseMedia() async {
    try {
      await _audioEvents?.cancel();
      await _audio?.dispose();
    } catch (error) {
      if (kDebugMode) debugPrint('Could not release audio preview: $error');
    }
    try {
      await _video?.dispose();
    } catch (error) {
      if (kDebugMode) debugPrint('Could not release video preview: $error');
    }
    final owned = _ownedTempPath;
    _ownedTempPath = null;
    if (owned != null) {
      try {
        await File(owned).delete();
      } on FileSystemException {
        // Cache cleanup is best effort; never touch a user-owned source.
      }
    }
  }

  Future<Uint8List> _readBounded(int maxBytes) async {
    final reported = widget.file.lengthSync() ?? await widget.file.length();
    if (reported != null && reported > maxBytes) {
      throw FormatException(
        'Preview limited to ${maxBytes ~/ (1024 * 1024)} MB for this format.',
      );
    }
    final buffer = BytesBuilder(copy: false);
    var count = 0;
    await for (final chunk in widget.file.readAsByteStream()) {
      if (_abandoned || !mounted) throw const PreviewCopyCancelled();
      count += chunk.length;
      if (count > maxBytes) {
        throw const FormatException('File is too large for this preview.');
      }
      buffer.add(chunk);
    }
    if (count == 0) throw const FormatException('This file is empty.');
    return buffer.takeBytes();
  }

  /// Media codecs require a local file path. Prefer the picker-provided cache
  /// path; otherwise stream into a bounded temporary file without loading the
  /// entire video or song into RAM.
  Future<String> _localMediaFile(int maxBytes) async {
    final reported = widget.file.lengthSync() ?? await widget.file.length();
    if (reported != null && reported > maxBytes) {
      throw FormatException(
        'Preview limited to ${maxBytes ~/ (1024 * 1024)} MB for this format.',
      );
    }
    final path = widget.file.path;
    if (path != null && await File(path).exists()) {
      final length = await File(path).length();
      if (length == 0 || length > maxBytes) {
        throw const FormatException('The selected file is empty or too large.');
      }
      return path;
    }

    final cache =
        await (widget.temporaryDirectory?.call() ?? getTemporaryDirectory());
    if (_abandoned || !mounted) throw const PreviewCopyCancelled();
    await TemporaryMediaCopy.cleanupAfterRestart(cache);
    if (_abandoned || !mounted) throw const PreviewCopyCancelled();
    if (reported != null) {
      final available =
          await (widget.availableTempBytes?.call() ??
              TemporaryStorageProbe.availableBytes());
      if (_abandoned || !mounted) throw const PreviewCopyCancelled();
      const reserve = 16 * 1024 * 1024;
      if (available != null && available < reported + reserve) {
        throw const FormatException(
          'Not enough temporary storage is available to preview this media file.',
        );
      }
    }
    final extension = ViewerFormat.extension(widget.file.name);
    final stem =
        '${cache.path}/frog_preview_${DateTime.now().microsecondsSinceEpoch}';
    final partial = File('$stem.$extension.partial');
    final completed = File('$stem.$extension');
    final copy = TemporaryMediaCopy();
    _mediaCopy = copy;
    try {
      final copiedPath = await copy.copy(
        chunks: widget.file.readAsByteStream(),
        partialFile: partial,
        completedFile: completed,
        maxBytes: maxBytes,
      );
      _ownedTempPath = copiedPath;
      if (_abandoned || !mounted) {
        throw const PreviewCopyCancelled();
      }
      return copiedPath;
    } finally {
      if (identical(_mediaCopy, copy)) _mediaCopy = null;
    }
  }

  Future<void> _prepare() async {
    try {
      switch (_kind) {
        case ViewerKind.pdf:
          final bytes = await _readBounded(_maxPdfBytes);
          if (!FileTools.looksLikePdf(bytes)) {
            throw const FormatException(
              'The selected file is not a valid PDF.',
            );
          }
          _pdf = PdfControllerPinch(document: PdfDocument.openData(bytes));
        case ViewerKind.office:
          final bytes = await _readBounded(DocumentConverter.maxInputBytes);
          final fontData = await rootBundle.load(
            DocumentConverter.bundledFontAsset,
          );
          final result = await compute(
            DocumentConverter.convert,
            ConversionRequest(
              bytes: bytes,
              fileName: widget.file.name,
              outputExtension: 'pdf',
              fontBytes: fontData.buffer.asUint8List(
                fontData.offsetInBytes,
                fontData.lengthInBytes,
              ),
            ),
          );
          if (result.bytes.length > _maxPdfBytes) {
            throw const FormatException('Generated preview is too large.');
          }
          _pdf = PdfControllerPinch(
            document: PdfDocument.openData(result.bytes),
          );
          _warning =
              'Read-only PDF-based preview. This is a temporary '
              'conversion, not the original Office layout. Complex tables, '
              'charts, fonts and formatting may change. Nothing was saved.';
          if (ViewerFormat.extension(widget.file.name) == 'odt') {
            _warning =
                'ODT preview is best effort. Text is reconstructed when '
                'available, and image-only files may use an embedded PDF. '
                'Tables and styling can change. Nothing was saved.';
          }
        case ViewerKind.text:
          final bytes = await _readBounded(_maxTextBytes);
          try {
            _text = utf8.decode(bytes, allowMalformed: false);
          } on FormatException {
            throw const FormatException(
              'Text preview currently requires UTF-8 encoding.',
            );
          }
          if (_text!.startsWith('\uFEFF')) {
            _text = _text!.substring(1);
          }
          if (_text!.length >= 100000) {
            _textLines = _text!.split('\n');
          }
          if ({
            'html',
            'htm',
            'xml',
            'svg',
          }.contains(ViewerFormat.extension(widget.file.name))) {
            _warning =
                'Markup is shown as text; scripts and external '
                'resources are never executed.';
          }
        case ViewerKind.image:
          _mediaPath = await _localMediaFile(_maxImageBytes);
          if (ViewerFormat.extension(widget.file.name) == 'heic' ||
              ViewerFormat.extension(widget.file.name) == 'heif' ||
              ViewerFormat.extension(widget.file.name) == 'avif') {
            _warning =
                'This image requires a compatible decoder on this '
                'Android device. Unsupported files will not be converted.';
          }
        case ViewerKind.audio:
          final audioLoader = widget.audioPlayerLoader;
          final player = audioLoader == null
              ? AudioPlayer()
              : await audioLoader(widget.file.path ?? widget.file.name);
          _audio = player;
          _audioEvents = player.playbackEventStream.listen(
            (_) {},
            onError: (Object error, StackTrace stackTrace) {
              if (!mounted) return;
              setState(() {
                _error = 'Audio playback failed on this device.';
              });
            },
          );
          if (audioLoader == null) {
            _mediaPath = await _localMediaFile(_maxAudioBytes);
            await player.setFilePath(_mediaPath!);
          }
        case ViewerKind.video:
          final videoLoader = widget.videoControllerLoader;
          final controller = videoLoader == null
              ? VideoPlayerController.file(
                  File(_mediaPath = await _localMediaFile(_maxVideoBytes)),
                )
              : await videoLoader(widget.file.path ?? widget.file.name);
          _video = controller;
          if (videoLoader == null) {
            await controller.initialize();
          }
          controller.addListener(_videoChanged);
          _warning =
              'Playback depends on the codecs supported by this '
              'Android device. This viewer does not transcode videos.';
        case ViewerKind.unsupported:
          _error = ViewerFormat.extension(widget.file.name) == 'avi'
              ? 'AVI preview is not supported by Android\'s bundled media '
                    'player. The original file was not changed.'
              : 'No built-in preview for this file type yet. '
                    'Legacy DOC, XLS, PPT, RTF, ODS and ODP still need '
                    'a compatible offline renderer.';
      }
    } catch (error, stackTrace) {
      if (mounted && !_abandoned) {
        if (kDebugMode) {
          debugPrint('Local preview failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
        _error = error is FormatException
            ? error.message
            : 'This file could not be opened on this device. '
                  'It may be damaged or use an unsupported encoding or codec.';
      }
    } finally {
      if (!mounted) {
        _pdf?.dispose();
        await _releaseMedia();
      } else {
        setState(() => _loading = false);
      }
    }
  }

  void _videoChanged() {
    final controller = _video;
    if (controller == null) return;
    final value = controller.value;
    var changed =
        _nativeWasPlaying != value.isPlaying ||
        _nativeWasBuffering != value.isBuffering;
    _nativeWasPlaying = value.isPlaying;
    _nativeWasBuffering = value.isBuffering;

    if (value.hasError) {
      _videoPlayRequested = false;
      _videoElapsed.stop();
      _videoUiTimer?.cancel();
      _error = 'This video stopped because the device could not decode it.';
      changed = true;
    } else if (value.isCompleted) {
      _videoPlayRequested = false;
      _videoElapsed.stop();
      _videoUiTimer?.cancel();
      changed = true;
    } else {
      final canAdvance =
          _videoPlayRequested && value.isPlaying && !value.isBuffering;
      if (_videoElapsed.isRunning && !canAdvance) {
        // Preserve the already-observed fallback position when buffering
        // starts, but never advance elapsed wall time while stalled.
        _videoAnchor += _videoElapsed.elapsed;
        _videoElapsed
          ..stop()
          ..reset();
        changed = true;
      } else if (!_videoElapsed.isRunning && canAdvance) {
        if (value.position > _videoAnchor) _videoAnchor = value.position;
        _videoElapsed
          ..reset()
          ..start();
        changed = true;
      }

      if (value.position >
          _lastNativePosition + const Duration(milliseconds: 150)) {
        _lastNativePosition = value.position;
        // Prefer the true decoder clock when it approaches our estimate.
        // MKV decoders that never advance keep the gated fallback instead.
        if (value.position >=
            _videoPosition(value) - const Duration(seconds: 2)) {
          _videoAnchor = value.position;
          _videoElapsed
            ..stop()
            ..reset();
          if (canAdvance) _videoElapsed.start();
        }
      }
    }
    if (changed && mounted) setState(() {});
  }

  Duration _videoPosition(VideoPlayerValue value) {
    return VideoPlaybackClock.displayPosition(
      native: value.position,
      fallbackAnchor: _videoAnchor,
      fallbackElapsed: _videoElapsed.elapsed,
      duration: value.duration,
      playRequested: _videoPlayRequested,
      actuallyPlaying: value.isPlaying,
      buffering: value.isBuffering,
      hasError: value.hasError,
    );
  }

  void _startVideoUiClock() {
    _videoUiTimer?.cancel();
    _videoUiTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final controller = _video;
      if (!mounted || controller == null || !_videoPlayRequested) return;
      final value = controller.value;
      // The decoder, not a speculative wall clock, decides completion.
      if (VideoPlaybackClock.actuallyCompleted(
        nativeCompleted: value.isCompleted,
        native: value.position,
        duration: value.duration,
      )) {
        _videoPlayRequested = false;
        _videoElapsed.stop();
        _videoUiTimer?.cancel();
      }
      setState(() {});
    });
  }

  Future<void> _toggleVideo() async {
    final controller = _video!;
    try {
      final value = controller.value;
      final playing = _videoPlayRequested || value.isPlaying;
      if (playing) {
        _videoAnchor = _videoPosition(value);
        _videoPlayRequested = false;
        _videoElapsed
          ..stop()
          ..reset();
        _videoUiTimer?.cancel();
        await controller.pause();
      } else {
        var start = _videoPosition(value);
        if (VideoPlaybackClock.actuallyCompleted(
          nativeCompleted: value.isCompleted,
          native: value.position,
          duration: value.duration,
        )) {
          start = Duration.zero;
          await controller.seekTo(Duration.zero);
          if (!mounted || _abandoned || !identical(_video, controller)) return;
        }
        _videoAnchor = start;
        _lastNativePosition = value.position;
        _videoPlayRequested = true;
        await controller.play();
        if (!mounted || _abandoned || !identical(_video, controller)) return;
        _startVideoUiClock();
      }
      if (mounted) setState(() {});
    } catch (error) {
      _videoPlayRequested = false;
      _videoElapsed.stop();
      _videoUiTimer?.cancel();
      if (mounted) {
        setState(
          () => _error = 'This video could not be played on this device.',
        );
      }
    }
  }

  /// Debounce slider drags so a native decoder does not receive dozens of
  /// overlapping seeks per second on slower Android hardware.
  void _scheduleVideoSeek(Duration position) {
    _pendingVideoSeek = position;
    final request = _videoSeekGuard.begin();
    _seekDebounce?.cancel();
    _seekDebounce = Timer(const Duration(milliseconds: 140), () {
      final pending = _pendingVideoSeek;
      if (pending != null && mounted) {
        unawaited(_seekVideo(pending, request));
      }
    });
    if (mounted) setState(() {});
  }

  Future<void> _seekVideo(Duration position, int request) async {
    final controller = _video!;
    try {
      await controller.seekTo(position);
      if (!mounted || !_videoSeekGuard.isLatest(request)) return;
      _videoAnchor = position;
      _lastNativePosition = position;
      _videoElapsed
        ..stop()
        ..reset();
      if (_videoPlayRequested &&
          controller.value.isPlaying &&
          !controller.value.isBuffering) {
        _videoElapsed.start();
      }
      _pendingVideoSeek = null;
      setState(() {});
    } catch (error) {
      if (_videoSeekGuard.isLatest(request)) _pendingVideoSeek = null;
      if (mounted && _videoSeekGuard.isLatest(request)) {
        setState(
          () => _error = 'This device could not seek in the selected video.',
        );
      }
    }
  }

  static String _clock(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Widget _seekBar({
    required Duration position,
    required Duration duration,
    required ValueChanged<Duration> onSeek,
  }) {
    final end = duration.inMilliseconds;
    return Column(
      children: [
        Slider(
          value: end > 0 ? position.inMilliseconds.clamp(0, end).toDouble() : 0,
          max: end > 0 ? end.toDouble() : 1,
          onChanged: end > 0
              ? (value) => onSeek(Duration(milliseconds: value.round()))
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(_clock(position)), Text(_clock(duration))],
          ),
        ),
      ],
    );
  }

  Widget _audioBody() {
    final player = _audio!;
    // The scroll view protects controls on short landscape phones and
    // with large accessibility text scales.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.album_outlined,
                size: 104,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                widget.file.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, snapshot) => _seekBar(
                  position: _pendingAudioSeek ?? snapshot.data ?? Duration.zero,
                  duration: player.duration ?? Duration.zero,
                  onSeek: _scheduleAudioSeek,
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<PlayerState>(
                stream: player.playerStateStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('This audio stopped unexpectedly.');
                  }
                  final playing = snapshot.data?.playing ?? player.playing;
                  final finished =
                      snapshot.data?.processingState ==
                      ProcessingState.completed;
                  return IconButton.filled(
                    iconSize: 40,
                    tooltip: playing ? 'Pause audio' : 'Play audio',
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: () async {
                      try {
                        if (playing) {
                          await player.pause();
                        } else {
                          if (finished) await player.seek(Duration.zero);
                          await player.play();
                        }
                      } catch (error) {
                        if (mounted) {
                          setState(
                            () => _error =
                                'Audio playback failed on this device.',
                          );
                        }
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scheduleAudioSeek(Duration position) {
    _pendingAudioSeek = position;
    final request = _audioSeekGuard.begin();
    _audioSeekDebounce?.cancel();
    _audioSeekDebounce = Timer(const Duration(milliseconds: 140), () {
      if (mounted) unawaited(_safeAudioSeek(position, request));
    });
    if (mounted) setState(() {});
  }

  Future<void> _safeAudioSeek(Duration position, int request) async {
    try {
      await _audio?.seek(position);
      if (!mounted || !_audioSeekGuard.isLatest(request)) return;
      _pendingAudioSeek = null;
      setState(() {});
    } catch (error) {
      if (_audioSeekGuard.isLatest(request)) _pendingAudioSeek = null;
      if (mounted && _audioSeekGuard.isLatest(request)) {
        setState(
          () => _error = 'This device could not seek in the selected audio.',
        );
      }
    }
  }

  Widget _videoBody() {
    final controller = _video!;
    final value = controller.value;
    final playing = _videoPlayRequested || value.isPlaying;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
              child: VideoPlayer(controller),
            ),
            const SizedBox(height: 12),
            _seekBar(
              position: _pendingVideoSeek ?? _videoPosition(value),
              duration: value.duration,
              onSeek: _scheduleVideoSeek,
            ),
            if (value.isBuffering)
              const Padding(
                padding: EdgeInsets.all(6),
                child: Text('Buffering…'),
              ),
            IconButton.filled(
              iconSize: 38,
              tooltip: playing ? 'Pause video' : 'Play video',
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              onPressed: _toggleVideo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Preparing an offline preview…'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    switch (_kind) {
      case ViewerKind.pdf:
      case ViewerKind.office:
        return PdfViewPinch(
          controller: _pdf!,
          onDocumentError: (error) {
            if (mounted) {
              setState(() {
                _error = 'Cannot render these PDF pages on this device.';
              });
            }
          },
        );
      case ViewerKind.text:
        if (_textLines != null) {
          // Large logs/source files should build visible rows lazily rather
          // than laying out two megabytes inside one SelectableText.
          final lines = _textLines!;
          return SelectionArea(
            child: ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: lines.length,
              itemBuilder: (context, index) => Text(
                lines[index],
                softWrap: true,
                style: const TextStyle(fontFamily: 'monospace', height: 1.4),
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: SelectableText(
            _text!,
            style: const TextStyle(fontFamily: 'monospace', height: 1.4),
          ),
        );
      case ViewerKind.image:
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Center(
            child: Image.file(
              File(_mediaPath!),
              fit: BoxFit.contain,
              cacheWidth: 2048,
              errorBuilder: (context, error, stackTrace) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Android cannot decode this image on this device.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      case ViewerKind.audio:
        return _audioBody();
      case ViewerKind.video:
        return _videoBody();
      case ViewerKind.unsupported:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.name, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              '${ViewerFormat.description(_kind)} · Original unchanged',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (_warning != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Card.outlined(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_warning!),
                ),
              ),
            ),
          Expanded(child: _previewBody()),
        ],
      ),
    );
  }
}
