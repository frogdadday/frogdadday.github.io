import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/file_tools.dart';
import '../services/scan_export_service.dart';

enum _Stage { camera, crop, review }

enum _Format { pdf, jpg, png }

class _Page {
  const _Page(this.id, this.bytes);
  final int id;
  final Uint8List bytes;
}

/// An on-device scanner. No Google services, uploads, or external camera intents.
class DocumentScannerPage extends StatefulWidget {
  const DocumentScannerPage({super.key});

  @override
  State<DocumentScannerPage> createState() => _DocumentScannerPageState();
}

class _DocumentScannerPageState extends State<DocumentScannerPage>
    with WidgetsBindingObserver {
  static const _cameraPermissionChannel = MethodChannel(
    'frog_file_viewer/camera',
  );
  final CropController _cropController = CropController();
  final List<_Page> _pages = [];
  CameraController? _camera;
  _Stage _stage = _Stage.camera;
  Uint8List? _pending;
  int? _editIndex;
  int _cameraGeneration = 0;
  int _cropRevision = 0;
  int _pageId = 0;
  bool _startingCamera = false;
  bool _busy = false;
  bool _finished = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startCamera());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final hadCamera = _camera != null;
      _stopCamera();
      if (hadCamera && mounted && _stage == _Stage.camera) {
        setState(
          () => _cameraError =
              'Camera was interrupted. Return to the app and tap Retry.',
        );
      }
    }
  }

  void _stopCamera() {
    _cameraGeneration++;
    final old = _camera;
    _camera = null;
    if (old != null) unawaited(old.dispose());
  }

  Future<void> _startCamera() async {
    if (!mounted || _stage != _Stage.camera || _startingCamera) return;
    _startingCamera = true;
    _stopCamera();
    var generation = _cameraGeneration;
    setState(() => _cameraError = null);
    CameraController? controller;
    try {
      final allowed =
          await _cameraPermissionChannel.invokeMethod<bool>(
            'requestPermission',
          ) ??
          false;
      if (!allowed) {
        if (mounted && _stage == _Stage.camera) {
          setState(
            () => _cameraError = 'Camera permission was denied. Allow camera access in Android settings, then try again.',
          );
        }
        return;
      }
      // The permission dialog pauses the activity and invalidates the old
      // generation. Start CameraX only after Android has returned a definite
      // grant, using a fresh generation for the resumed activity.
      _stopCamera();
      generation = _cameraGeneration;
      final devices = await availableCameras();
      if (devices.isEmpty) {
        throw const FormatException('There is no available camera.');
      }
      final rear = devices.where(
        (device) => device.lensDirection == CameraLensDirection.back,
      );
      controller = CameraController(
        rear.isEmpty ? devices.first : rear.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted ||
          _stage != _Stage.camera ||
          generation != _cameraGeneration) {
        await controller.dispose();
        if (mounted && _stage == _Stage.camera) {
          setState(
            () => _cameraError =
                'Camera was interrupted. Return to the app and try again.',
          );
        }
        return;
      }
      setState(() => _camera = controller);
    } catch (_) {
      if (controller != null) await controller.dispose();
      if (mounted && generation == _cameraGeneration) {
        setState(
          () => _cameraError =
              'Camera unavailable. Check camera permission and try again.',
        );
      }
    } finally {
      _startingCamera = false;
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _takePhoto() async {
    final camera = _camera;
    if (_busy || camera == null || !camera.value.isInitialized) return;
    setState(() => _busy = true);
    try {
      final picture = await camera.takePicture();
      final file = File(picture.path);
      Uint8List original;
      try {
        if (await file.length() > ScanExportService.maxPageBytes) {
          throw const FormatException('Photo exceeds the 15 MB safety limit.');
        }
        original = await file.readAsBytes();
      } finally {
        try {
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          // Android may remove the temporary camera file before we do.
        }
      }
      final prepared = await compute(ScanExportService.preparePage, original);
      if (!mounted) return;
      _stopCamera();
      setState(() {
        _pending = prepared;
        _cropRevision++;
        _stage = _Stage.crop;
      });
    } on FormatException catch (error) {
      _notice(error.message);
    } catch (_) {
      _notice('Could not capture the page. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rotate() async {
    final original = _pending;
    if (_busy || original == null) return;
    setState(() => _busy = true);
    try {
      final rotated = await compute(
        ScanExportService.rotateClockwise,
        original,
      );
      if (mounted) {
        setState(() {
          _pending = rotated;
          _cropRevision++;
        });
      }
    } catch (_) {
      _notice('Could not rotate this page.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyCrop() {
    if (_busy || _pending == null) return;
    setState(() => _busy = true);
    try {
      _cropController.crop();
    } catch (_) {
      _notice('Could not start cropping.');
      setState(() => _busy = false);
    }
  }

  Future<void> _onCropped(CropResult result) async {
    switch (result) {
      case CropSuccess(:final croppedImage):
        try {
          final jpeg = await compute(
            ScanExportService.preparePage,
            croppedImage,
          );
          if (!mounted) return;
          final replacement = List<_Page>.of(_pages);
          if (_editIndex == null) {
            if (replacement.length == ScanExportService.maxPages) {
              throw const FormatException('Maximum 30 pages per scan.');
            }
            replacement.add(_Page(_pageId++, jpeg));
          } else {
            replacement[_editIndex!] = _Page(replacement[_editIndex!].id, jpeg);
          }
          final total = replacement.fold<int>(
            0,
            (sum, page) => sum + page.bytes.length,
          );
          if (total > ScanExportService.maxTotalBytes) {
            throw const FormatException('Scans exceed the 60 MB safety limit.');
          }
          setState(() {
            _pages
              ..clear()
              ..addAll(replacement);
            _pending = null;
            _editIndex = null;
            _stage = _Stage.review;
          });
        } on FormatException catch (error) {
          _notice(error.message);
        } catch (_) {
          _notice('Could not prepare the cropped page.');
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      case CropFailure():
        _notice('Crop failed. Adjust the rectangle and try again.');
        if (mounted) setState(() => _busy = false);
    }
  }

  void _newPage() {
    if (_busy) return;
    if (_pages.length >= ScanExportService.maxPages) {
      _notice('Maximum 30 pages per scan.');
      return;
    }
    setState(() {
      _pending = null;
      _editIndex = null;
      _stage = _Stage.camera;
    });
    unawaited(_startCamera());
  }

  void _edit(int index) {
    if (_busy) return;
    setState(() {
      _pending = _pages[index].bytes;
      _editIndex = index;
      _cropRevision++;
      _stage = _Stage.crop;
    });
  }

  Future<void> _retake() async {
    if (_busy) return;
    setState(() {
      _pending = null;
      _stage = _Stage.camera;
    });
    await _startCamera();
  }

  Future<void> _save() async {
    if (_busy || _pages.isEmpty) return;
    var filename = 'frog_scan';
    var selected = _Format.pdf;
    final choice = await showDialog<({String name, _Format format})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('Save scanned document'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: 'frog_scan',
                  onChanged: (value) => filename = value,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Filename'),
                ),
                if (_pages.length == 1) ...[
                  const Text('Format'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final format in _Format.values)
                        ChoiceChip(
                          label: Text(format.name.toUpperCase()),
                          selected: selected == format,
                          onSelected: (_) => update(() => selected = format),
                        ),
                    ],
                  ),
                ] else
                  const Text('Save all pages as one PDF.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, (
                name: filename,
                format: selected,
              )),
              child: const Text('Choose location'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final pages = _pages.map((page) => page.bytes).toList(growable: false);
      final format = pages.length > 1 ? _Format.pdf : choice.format;
      final Uint8List bytes = switch (format) {
        _Format.pdf => await compute(ScanExportService.asPdf, pages),
        _Format.jpg => pages.single,
        _Format.png => await compute(ScanExportService.asPng, pages.single),
      };
      if (!mounted) return;
      final stem = FileTools.withoutExtension(choice.name);
      final mime = switch (format) {
        _Format.pdf => 'application/pdf',
        _Format.jpg => 'image/jpeg',
        _Format.png => 'image/png',
      };
      final location = await FilePicker.saveFile(
        fileName: '$stem.${format.name}',
        bytes: bytes,
        mimeType: mime,
        type: FileType.custom,
        allowedExtensions: [format.name],
      );
      if (!mounted) return;
      if (location == null) {
        _notice('Save cancelled. Your scanned pages are still here.');
      } else {
        _finishAndPop();
      }
    } on FormatException catch (error) {
      _notice(error.message);
    } catch (_) {
      _notice('Save failed. Your scanned pages are still here.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    if (_busy) return;
    if (_pages.isNotEmpty || _pending != null) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Discard unsaved scan?'),
          content: const Text('Unsaved photos will be removed from memory.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep scanning'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (!mounted) return;
    _finishAndPop();
  }

  void _finishAndPop() {
    setState(() => _finished = true);
    // Let PopScope rebuild with canPop=true before navigating.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _finished || (!_busy && _pages.isEmpty && _pending == null),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_finished) unawaited(_close());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(switch (_stage) {
            _Stage.camera => 'Scan document',
            _Stage.crop => 'Crop page',
            _Stage.review => 'Review pages',
          }),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close scanner',
            onPressed: _busy ? null : _close,
          ),
        ),
        body: SafeArea(
          child: switch (_stage) {
            _Stage.camera => _buildCamera(),
            _Stage.crop => _buildCrop(),
            _Stage.review => _buildReview(),
          },
        ),
      ),
    );
  }

  Widget _buildCamera() {
    final camera = _camera;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: _cameraError != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_cameraError!, textAlign: TextAlign.center),
                  )
                : camera == null || !camera.value.isInitialized
                ? const CircularProgressIndicator()
                : CameraPreview(camera),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              if (_pages.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          _stopCamera();
                          setState(() => _stage = _Stage.review);
                        },
                  icon: const Icon(Icons.collections_outlined),
                  label: Text('Review ${_pages.length} pages'),
                ),
              if (_cameraError != null)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _startCamera,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              FilledButton.icon(
                onPressed: _busy || camera == null ? null : _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take picture'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCrop() {
    final image = _pending;
    if (image == null) return const Center(child: Text('No photo selected.'));
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Crop(
              key: ValueKey(_cropRevision),
              image: image,
              controller: _cropController,
              onCropped: _onCropped,
            ),
          ),
        ),
        const Text('Drag the rectangle around the document.'),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: _busy ? null : _retake,
                icon: const Icon(Icons.refresh),
                label: const Text('Retake'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _rotate,
                icon: const Icon(Icons.rotate_right),
                label: const Text('Rotate'),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : _applyCrop,
                icon: const Icon(Icons.crop),
                label: const Text('Use page'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReview() {
    return Column(
      children: [
        Expanded(
          child: _pages.isEmpty
              ? const Center(child: Text('No pages yet.'))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _pages.length,
                  buildDefaultDragHandles: false,
                  onReorderItem: (oldIndex, newIndex) {
                    if (_busy) return;
                    setState(() {
                      _pages.insert(newIndex, _pages.removeAt(oldIndex));
                    });
                  },
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Card(
                      key: ValueKey(page.id),
                      child: ListTile(
                        leading: Image.memory(
                          page.bytes,
                          width: 54,
                          height: 70,
                          cacheWidth: 108,
                          fit: BoxFit.contain,
                        ),
                        title: Text('Page ${index + 1}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Recrop page',
                              onPressed: _busy ? null : () => _edit(index),
                              icon: const Icon(Icons.crop),
                            ),
                            IconButton(
                              tooltip: 'Remove page',
                              onPressed: _busy
                                  ? null
                                  : () =>
                                        setState(() => _pages.removeAt(index)),
                              icon: const Icon(Icons.delete_outline),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_handle),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _newPage,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Add page'),
              ),
              FilledButton.icon(
                onPressed: _busy || _pages.isEmpty ? null : _save,
                icon: const Icon(Icons.save_alt),
                label: const Text('Save document'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
