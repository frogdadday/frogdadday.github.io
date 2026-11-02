import 'dart:async';
import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:dart_pdf_editor_assets/dart_pdf_editor_assets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute, kDebugMode;
import 'package:flutter/services.dart' show rootBundle;

import 'services/bounded_file_reader.dart';
import 'cosmic/cosmic_inline_stage.dart';
import 'cosmic/cosmic_painters.dart';
import 'cosmic/cosmic_foreground_frog_painter.dart';
import 'services/file_tools.dart';
import 'viewers/file_preview_page.dart';
import 'viewers/document_scanner_page.dart';
import 'services/document_converter.dart';
import 'services/third_party_licenses.dart';
import 'services/draft_recovery_store.dart';
import 'services/editor_save_guard.dart';
import 'services/pdf_image_insert.dart';
import 'widgets/frog_heart_button.dart';
import 'widgets/privacy_policy_button.dart';
import 'widgets/pdf_markup_shortcut.dart';
import 'widgets/tie_dye_frog.dart';

Future<Uint8List> _imagesToPdfInBackground(List<Uint8List> images) =>
    FileTools.imagesToPdf(images);

Uint8List _convertImageInBackground(
  ({Uint8List bytes, String extension}) request,
) => FileTools.convertImage(request.bytes, request.extension);

Uint8List _preparePdfInsertImageInBackground(Uint8List bytes) =>
    PdfImageInsert.normalize(bytes);

Uint8List _makePdfSavedCopyCompatibleInBackground(Uint8List bytes) =>
    PdfImageInsert.makeSavedCopyCompatible(bytes);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledEditorAssets();
  registerBundledThirdPartyLicenses();
  runApp(const FrogFileToolkit());
}

class FrogFileToolkit extends StatelessWidget {
  const FrogFileToolkit({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frog File Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF366C42)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F8F3),
      ),
      home: const ToolboxHome(),
    );
  }
}

class ToolboxHome extends StatefulWidget {
  const ToolboxHome({super.key});

  @override
  State<ToolboxHome> createState() => _ToolboxHomeState();
}

class _ToolboxHomeState extends State<ToolboxHome> {
  Uint8List? _openedBytes;
  Uint8List? _latestBytes;
  String _documentName = 'document.pdf';
  int _documentSerial = 0;
  bool _dirty = false;
  bool _busy = false;
  bool _cosmicEnabled = false;
  bool _cosmicReducedMotion = false;
  // The existing little mascot is the sole Cosmic Mode frog.
  // Stable keys let the foreground painter follow its scroll position.
  final GlobalKey _cosmicFrogAnchorKey = GlobalKey(
    debugLabel: 'cosmic-frog-home',
  );
  final GlobalKey _cosmicFrogOverlayKey = GlobalKey(
    debugLabel: 'cosmic-frog-foreground',
  );
  String _busyLabel = 'Working securely…';
  bool _openedMayBeEncrypted = false;
  final DraftRecoveryStore _recoveryStore = DraftRecoveryStore();
  final EditorSaveGuard _saveGuard = EditorSaveGuard();
  Timer? _recoveryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerRecovery());
  }

  @override
  void dispose() {
    _recoveryTimer?.cancel();
    super.dispose();
  }

  Future<void> _offerRecovery() async {
    RecoveryDraft? draft;
    try {
      draft = await _recoveryStore.load();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Could not inspect local recovery draft: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return;
    }
    if (draft == null || !mounted || _openedBytes != null) return;
    final restore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recover unsaved edits?'),
        content: Text(
          'A local recovery copy of “${draft!.documentName}” was saved after an interruption. '
          'Recovery copies stay only on this device, expire after 24 hours, and are deleted after save or discard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Discard recovery copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore edits'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (restore == true) {
      _loadEditor(draft.bytes, draft.documentName);
      setState(() => _dirty = true);
    } else {
      await _recoveryStore.delete();
    }
  }

  void _scheduleRecovery(Uint8List bytes) {
    _recoveryTimer?.cancel();
    final documentName = _documentName;
    _recoveryTimer = Timer(const Duration(seconds: 2), () async {
      try {
        await _recoveryStore.save(bytes, documentName);
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('Could not checkpoint local recovery draft: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    });
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _toggleCosmicMode() {
    setState(() {
      _cosmicEnabled = !_cosmicEnabled;
    });
  }

  Future<T?> _run<T>(
    Future<T> Function() action, {
    String label = 'Working securely…',
  }) async {
    if (_busy) return null;
    setState(() {
      _busy = true;
      _busyLabel = label;
    });
    try {
      return await action();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Frog PDF operation failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      _notice(
        error is FormatException
            ? error.message
            : 'This file could not be processed safely.',
      );
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Uint8List> _readBoundedFile(
    PlatformFile file,
    int maxBytes,
    String limitMessage,
  ) {
    return BoundedFileReader.read(
      file,
      maxBytes: maxBytes,
      limitMessage: limitMessage,
    );
  }

  Future<PlatformFile?> _pickSingleFile({
    required List<String> allowedExtensions,
  }) {
    // Keep all document imports on the single-file platform contract. On
    // Android this avoids leaving the picker in a multi-select workflow where
    // tapping an ODT only highlights it and waits for a second confirmation.
    return FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
  }

  Future<Uint8List?> _pickPdfBytes() async {
    try {
      final file = await _pickSingleFile(allowedExtensions: const ['pdf']);
      if (file == null) return null;
      final bytes = await _readBoundedFile(
        file,
        50 * 1024 * 1024,
        'For now, PDFs are limited to 50 MB.',
      );
      if (!FileTools.looksLikePdf(bytes)) {
        throw const FormatException(
          'The selected file does not look like a PDF.',
        );
      }
      return bytes;
    } on Exception catch (e) {
      _notice(e is FormatException ? e.message : 'Could not load PDF: $e');
      return null;
    }
  }

  Future<Uint8List?> _pickPdfInsertImage(BuildContext _) async {
    try {
      final file = await _pickSingleFile(
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (file == null) return null;
      if (!PdfImageInsert.isSupportedName(file.name)) {
        throw const FormatException('Choose a JPG, JPEG, PNG or WebP image.');
      }
      final bytes = await _readBoundedFile(
        file,
        PdfImageInsert.maxInputBytes,
        'Choose an image no larger than 15 MB.',
      );
      return await compute(_preparePdfInsertImageInBackground, bytes);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Could not prepare PDF image insertion: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (mounted) {
        _notice(
          error is FormatException
              ? error.message
              : 'This image could not be inserted safely.',
        );
      }
      return null;
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Discard unsaved edits?'),
            content: const Text(
              'Changes are not saved until you choose a destination. '
              'Discarding them will leave the original file untouched.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Discard changes'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _closePdf() async {
    if (!await _confirmDiscard()) return;
    _recoveryTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _openedBytes = null;
      _latestBytes = null;
      _dirty = false;
      _openedMayBeEncrypted = false;
    });
    await _recoveryStore.delete();
  }

  void _loadEditor(Uint8List bytes, String name) {
    _saveGuard.openedDocument();
    setState(() {
      _openedBytes = bytes;
      _latestBytes = bytes;
      _documentName = name;
      _documentSerial++;
      _dirty = false;
      _openedMayBeEncrypted = FileTools.mayBeEncryptedPdf(bytes);
    });
  }

  Future<void> _openAnyFile() async {
    // Universal read-only viewer runs in its own route. No PDF editor state
    // changes and no application-wide storage or internet permission needed.
    await _run(() async {
      final picked = await FilePicker.pickFile(type: FileType.any);
      if (picked == null || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => FilePreviewPage(file: picked),
        ),
      );
    }, label: 'Opening file viewer…');
  }

  Future<void> _openPdf() async {
    if (!await _confirmDiscard()) return;
    await _run(() async {
      final picked = await _pickSingleFile(allowedExtensions: const ['pdf']);
      if (picked == null) return;
      final bytes = await _readBoundedFile(
        picked,
        50 * 1024 * 1024,
        'PDF exceeds the 50 MB safety limit.',
      );
      if (!FileTools.looksLikePdf(bytes)) {
        throw const FormatException(
          'The selected file is not a valid PDF header.',
        );
      }
      var openedBytes = bytes;
      var openedName = picked.name;
      if (FileTools.needsScannedPdfCompatibilityCopy(bytes) && mounted) {
        final makeCopy = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Make this scan compatible?'),
            content: const Text(
              'This scanned PDF uses an image encoding that can appear blank '
              'in the editor. Frog File Viewer can rebuild the scan locally. '
              'The compatible copy keeps the visible pages, but flattens '
              'forms, links, annotations and searchable text.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Open original'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Make compatible copy'),
              ),
            ],
          ),
        );
        if (makeCopy == true) {
          openedBytes = await compute(
            FileTools.makeScannedPdfCompatibilityCopy,
            bytes,
          );
          openedName =
              '${FileTools.withoutExtension(picked.name)}_compatible.pdf';
        }
      }
      // Do not displace the current editor or its recovery checkpoint merely
      // because a selected file starts with the letters "%PDF".
      if (!await compute(FileTools.canOpenEditablePdf, openedBytes)) {
        throw const FormatException(
          'This PDF is damaged or cannot be opened safely for editing. '
          'The previous document is unchanged.',
        );
      }
      if (mounted) {
        _recoveryTimer?.cancel();
        _loadEditor(openedBytes, openedName);
        await _recoveryStore.delete();
      }
    }, label: 'Opening PDF…');
  }

  Future<void> _newPdf() async {
    if (!await _confirmDiscard()) return;
    await _run(() async {
      final bytes = await FileTools.blankPdf();
      if (mounted) {
        _recoveryTimer?.cancel();
        _loadEditor(bytes, 'untitled.pdf');
        await _recoveryStore.delete();
      }
    });
  }

  Future<bool> _saveBytes(
    Uint8List bytes,
    String suggestedName, {
    String mime = 'application/pdf',
    bool notifyOnSuccess = true,
  }) async {
    final extension = suggestedName.split('.').last.toLowerCase();
    final result = await FilePicker.saveFile(
      fileName: suggestedName,
      bytes: bytes,
      mimeType: mime,
      type: FileType.custom,
      allowedExtensions: [extension],
    );
    if (result == null) {
      _notice('Save cancelled; nothing was overwritten.');
      return false;
    }
    if (notifyOnSuccess) _notice('Saved a copy to the selected location.');
    return true;
  }

  Future<void> _saveDocument(Uint8List bytes) async {
    // Capture the document and edit revision BEFORE the Android save picker
    // starts. An edit that arrives while that picker is open is not included
    // in these bytes and must retain its dirty state and recovery checkpoint.
    final snapshot = _saveGuard.capture();
    await _run(() async {
      final stem = FileTools.withoutExtension(_documentName);
      // Keep image stamps editable in the live document and recovery draft,
      // but bake them into the outbound copy so basic PDF readers show them.
      final compatibleBytes = await compute(
        _makePdfSavedCopyCompatibleInBackground,
        bytes,
      );
      final saved = await _saveBytes(
        compatibleBytes,
        '${stem}_edited.pdf',
        notifyOnSuccess: false,
      );
      if (!saved || !mounted) return;
      if (!_saveGuard.isStillCurrent(snapshot)) {
        _notice(
          'Saved a copy of the earlier version. Newer edits are still unsaved; '
          'save again to include them.',
        );
        return;
      }
      _recoveryTimer?.cancel();
      setState(() {
        _dirty = false;
        _latestBytes = bytes;
      });
      await _recoveryStore.delete();
      _notice('Saved a copy to the selected location.');
    }, label: 'Preparing compatible PDF copy…');
  }

  Future<void> _exportPages(Uint8List bytes) async {
    await _run(
      () => _saveBytes(
        bytes,
        '${FileTools.withoutExtension(_documentName)}_pages.pdf',
      ),
    );
  }

  Future<void> _splitPages(List<Uint8List> pages) async {
    await _run(() async {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Split copies may lose document features'),
          content: Text(
            '${_openedMayBeEncrypted ? 'This PDF appears to be protected. The split copies will not retain that protection. ' : ''}'
            'Split copies may also omit bookmarks, named destinations, and some interactive-form structure. Review every output before sharing it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue splitting'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      var savedCount = 0;
      for (var i = 0; i < pages.length; i++) {
        final saved = await _saveBytes(
          pages[i],
          '${FileTools.withoutExtension(_documentName)}_part_${i + 1}.pdf',
        );
        if (!saved) {
          if (savedCount > 0) {
            _notice(
              '$savedCount split file(s) were saved before cancellation.',
            );
          }
          break;
        }
        savedCount++;
      }
    }, label: 'Preparing split copies…');
  }

  Future<void> _imagesToPdf() async {
    await _run(() async {
      // Android's general SAF picker returns durable readable handles. The
      // image-only picker can return Photo Picker URIs that cannot be reopened.
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return;
      if (files.length > 30) {
        throw const FormatException('Choose up to 30 images per document.');
      }
      if (files.any((file) => !FileTools.isSupportedImageName(file.name))) {
        throw const FormatException(
          'Choose only JPG, PNG or WebP image files.',
        );
      }
      final bytes = <Uint8List>[];
      var aggregateBytes = 0;
      for (final file in files) {
        // lengthSync() is safely reported picker metadata, not file I/O.
        // Preflight the reported size, but never trust it as the final count.
        final reportedLength = file.lengthSync();
        if (reportedLength != null &&
            reportedLength >
                FileTools.maxAggregateInputBytes - aggregateBytes) {
          throw const FormatException(
            'Selected images exceed the combined 60 MB safety limit.',
          );
        }
        final remaining = FileTools.maxAggregateInputBytes - aggregateBytes;
        final imageBytes = await _readBoundedFile(
          file,
          remaining < FileTools.maxInputBytes
              ? remaining
              : FileTools.maxInputBytes,
          'Selected images exceed the remaining per-file or 60 MB total limit.',
        );
        aggregateBytes += imageBytes.length;
        bytes.add(imageBytes);
      }
      final result = await compute(_imagesToPdfInBackground, bytes);
      await _saveBytes(result, 'frog_images.pdf');
    }, label: 'Optimizing images and building PDF…');
  }

  Future<void> _convertDocument() async {
    await _run(() async {
      final file = await _pickSingleFile(
        allowedExtensions: const ['pdf', 'docx', 'odt', 'txt', 'xlsx', 'pptx'],
      );
      if (file == null) return;
      final inputBytes = await _readBoundedFile(
        file,
        DocumentConverter.maxInputBytes,
        'Choose a document no larger than 16 MB.',
      );

      final choices = DocumentConverter.formatsFor(file.name);
      if (!mounted) return;
      if (choices.isEmpty) {
        throw const FormatException(
          'Unsupported format. Try PDF, DOCX, ODT, TXT, XLSX or PPTX.',
        );
      }

      final target = choices.length == 1
          ? choices.first
          : await showModalBottomSheet<String>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (sheetContext) => SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ListTile(
                        title: Text('Convert PDF into...'),
                        subtitle: Text(
                          'Text extraction only; not layout-preserving',
                        ),
                      ),
                      for (final ext in choices)
                        ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: Text(ext.toUpperCase()),
                          subtitle: Text(
                            ext == 'txt' ? 'Plain searchable text' : 'Basic editable document: text, not original page layout',
                          ),
                          onTap: () => Navigator.pop(sheetContext, ext),
                        ),
                    ],
                  ),
                ),
              ),
            );
      if (target == null || !mounted) return;

      final warning = DocumentConverter.warningFor(file.name, target);
      if (warning != null) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Conversion may change or omit content'),
            content: Text(warning),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Convert a copy'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }

      Uint8List? fontBytes;
      if (target == 'pdf') {
        final fontData = await rootBundle.load(
          DocumentConverter.bundledFontAsset,
        );
        fontBytes = fontData.buffer.asUint8List(
          fontData.offsetInBytes,
          fontData.lengthInBytes,
        );
      }

      // CPU-heavy conversion runs outside the main UI isolate.
      final result = await compute(
        DocumentConverter.convert,
        ConversionRequest(
          bytes: inputBytes,
          fileName: file.name,
          outputExtension: target,
          fontBytes: fontBytes,
        ),
      );
      if (!mounted) return;

      final suggestedName =
          '${FileTools.withoutExtension(file.name)}_converted.${result.extension}';
      await _saveBytes(result.bytes, suggestedName, mime: result.mimeType);
    }, label: 'Converting document offline…');
  }

  Future<void> _scanDocument() async {
    if (_busy) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const DocumentScannerPage(),
      ),
    );
  }

  Future<void> _convertImage() async {
    final target = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Convert image to...'),
                subtitle: Text('One image at a time · offline'),
              ),
              for (final ext in ['png', 'jpg', 'webp'])
                ListTile(
                  title: Text(ext.toUpperCase()),
                  onTap: () => Navigator.pop(sheetContext, ext),
                ),
            ],
          ),
        ),
      ),
    );
    if (target == null) return;
    await _run(() async {
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null) return;
      if (!FileTools.isSupportedImageName(file.name)) {
        throw const FormatException('Choose a JPG, PNG or WebP image file.');
      }
      final original = await _readBoundedFile(
        file,
        FileTools.maxInputBytes,
        'Choose an image no larger than 15 MB.',
      );
      final converted = await compute(_convertImageInBackground, (
        bytes: original,
        extension: target,
      ));
      final mime = switch (target) {
        'png' => 'image/png',
        'jpg' => 'image/jpeg',
        _ => 'image/webp',
      };
      await _saveBytes(
        converted,
        '${FileTools.withoutExtension(file.name)}_converted.$target',
        mime: mime,
      );
    }, label: 'Converting image…');
  }

  @override
  Widget build(BuildContext context) {
    final editing = _openedBytes != null;
    Widget buildScaffold(CosmicFrame? cosmic) {
      return PopScope(
        canPop: !editing,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && editing) unawaited(_closePdf());
        },
        child: Scaffold(
          backgroundColor: cosmic == null ? null : const Color(0xFF100F22),
          appBar: AppBar(
            backgroundColor: cosmic == null ? null : const Color(0xEA171127),
            foregroundColor: cosmic == null ? null : Colors.white,
            automaticallyImplyLeading: false,
            // Only the larger frog beside the home tagline remains. Retain the
            // back arrow while editing a PDF, but no redundant AppBar mascot.
            leading: editing
                ? IconButton(
                    tooltip: 'Back to tools',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _busy ? null : _closePdf,
                  )
                : null,
            title: cosmic != null && !editing
                ? Semantics(
                    header: true,
                    label: 'Frog File Viewer',
                    child: ExcludeSemantics(
                      child: SizedBox(
                        height: 50,
                        // The real Text supplies nonzero layout constraints.
                        // A prior childless CustomPaint collapsed to zero width,
                        // making the original app title disappear entirely.
                        child: CustomPaint(
                          painter: CosmicTitlePainter(
                            motion: cosmic.motion,
                            title: 'Frog File Viewer',
                            repaint: cosmic.repaint,
                          ),
                          child: const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Frog File Viewer',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : Text(
                    editing ? _documentName : 'Frog File Viewer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            actions: editing
                ? [
                    IconButton(
                      tooltip: 'Save a copy',
                      icon: const Icon(Icons.save_outlined),
                      onPressed: _busy
                          ? null
                          : () => _saveDocument(_latestBytes ?? _openedBytes!),
                    ),
                  ]
                : [],
          ),
          body: Stack(
            children: [
              if (cosmic != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: CosmicScenePainter(
                          motion: cosmic.motion,
                          shader: cosmic.shader,
                          repaint: cosmic.repaint,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: editing
                    ? Stack(
                        children: [
                          PdfEditorView(
                            key: ValueKey(_documentSerial),
                            bytes: _openedBytes!,
                            toolbarBuilder: (context, editing, viewer) =>
                                PdfMarkupToolbar(
                                  controller: editing,
                                  viewerController: viewer,
                                  imagePicker: _pickPdfInsertImage,
                                ),
                            onDocumentChanged: (bytes) {
                              _saveGuard.recordedEdit();
                              _latestBytes = bytes;
                              _dirty = true;
                              _scheduleRecovery(bytes);
                            },
                            onSave: (bytes) => unawaited(_saveDocument(bytes)),
                            onSaveAs: (bytes) =>
                                unawaited(_saveDocument(bytes)),
                            onExportPages: (bytes) =>
                                unawaited(_exportPages(bytes)),
                            onSplitPages: (documents) =>
                                unawaited(_splitPages(documents)),
                            onPickPdfToInsert: _pickPdfBytes,
                            imagePicker: _pickPdfInsertImage,
                          ),
                          if (_busy)
                            Positioned.fill(
                              child: ColoredBox(
                                color: const Color(0x99FFFFFF),
                                child: Center(
                                  child: Semantics(
                                    liveRegion: true,
                                    label: _busyLabel,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CircularProgressIndicator(),
                                        const SizedBox(height: 12),
                                        Text(_busyLabel),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : Theme(
                        data: cosmic == null
                            ? Theme.of(context)
                            : Theme.of(context).copyWith(
                                cardTheme: const CardThemeData(
                                  color: Color(0xCC1D1736),
                                ),
                                colorScheme: Theme.of(context).colorScheme
                                    .copyWith(
                                      surface: const Color(0xCC1D1736),
                                      onSurface: Colors.white,
                                      primary: const Color(0xFFC4F87D),
                                    ),
                              ),
                        child: DefaultTextStyle.merge(
                          style: TextStyle(
                            color: cosmic == null ? null : Colors.white,
                          ),
                          child: SafeArea(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1080,
                                ),
                                child: ListView(
                                  key: const PageStorageKey<String>(
                                    'frog-pdf-tools',
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  children: [
                                    if (_busy) ...[
                                      Semantics(
                                        liveRegion: true,
                                        child: Card.filled(
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Row(
                                              children: [
                                                const SizedBox.square(
                                                  dimension: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(_busyLabel),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Your files. Your phone. Your business.',
                                            style: TextStyle(
                                              fontSize: 23,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        if (cosmic != null)
                                          SizedBox(
                                            key: _cosmicFrogAnchorKey,
                                            width: 88,
                                            height: 88,
                                          )
                                        else
                                          const TieDyeFrog(size: 88),
                                      ],
                                    ),
                                    // Cosmic Mode controls belong at the top of the tools,
                                    // never buried below a long scrollable calculator list.
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 7,
                                      ),
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton.icon(
                                            key: const Key(
                                              'cosmic-mode-button',
                                            ),
                                            onPressed: _busy
                                                ? null
                                                : _toggleCosmicMode,
                                            icon: const Icon(
                                              Icons.auto_awesome_outlined,
                                            ),
                                            label: Text(
                                              _cosmicEnabled
                                                  ? 'Cosmic Mode: On'
                                                  : 'Cosmic Mode',
                                            ),
                                          ),
                                          if (_cosmicEnabled)
                                            OutlinedButton.icon(
                                              key: const Key(
                                                'cosmic-reduced-motion',
                                              ),
                                              onPressed: () => setState(() {
                                                _cosmicReducedMotion =
                                                    !_cosmicReducedMotion;
                                              }),
                                              icon: Icon(
                                                _cosmicReducedMotion
                                                    ? Icons.play_arrow
                                                    : Icons.pause,
                                              ),
                                              label: Text(
                                                _cosmicReducedMotion
                                                    ? 'Resume effects'
                                                    : 'Reduce motion',
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'No accounts, ads, subscriptions, analytics, or cloud processing.',
                                    ),
                                    const SizedBox(height: 22),
                                    _adaptiveActions(),
                                    const SizedBox(height: 22),
                                    Card.filled(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Starter build · v0.2',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            const Text(
                                              'PDF page tools are inside the editor thumbnail panel. '
                                              'Saving opens your device\'s file picker and creates a copy. '
                                              'Original files are never modified in place.',
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Frogdadday · Always Free',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Card.outlined(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                const PrivacyPolicyButton(),
                                                OutlinedButton.icon(
                                                  key: const Key(
                                                    'open-source-licenses',
                                                  ),
                                                  onPressed: () =>
                                                      showLicensePage(
                                                        context: context,
                                                        applicationName:
                                                            'Frog File Viewer',
                                                      ),
                                                  icon: const Icon(Icons.code),
                                                  label: const Text(
                                                    'Open-source licenses',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            const FrogHeartButton(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              // The mascot itself lives in the FOREGROUND. Only the
              // psychedelic colors are behind the original app interface.
              if (cosmic != null && !editing)
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: _cosmicFrogOverlayKey,
                        painter: CosmicForegroundFrogPainter(
                          motion: cosmic.motion,
                          frogBody: cosmic.frogBody,
                          anchorKey: _cosmicFrogAnchorKey,
                          canvasKey: _cosmicFrogOverlayKey,
                          repaint: cosmic.repaint,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (_cosmicEnabled) {
      return CosmicInlineStage(
        reduceMotion: _cosmicReducedMotion,
        builder: (context, frame) => buildScaffold(frame),
      );
    }
    return buildScaffold(null);
  }

  /// On tablets and in desktop-window mode, use the available window width,
  /// not the physical device category. Compact split-screen windows remain a
  /// one-column list and everything stays scrollable at larger text scales.
  Widget _adaptiveActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final twoColumns = width >= 780;
        final tileWidth = twoColumns ? (width - 12) / 2 : width;
        final actions = <Widget>[
          _action(
            Icons.folder_open_outlined,
            'View a file',
            'Offline previews for documents, pictures, music and video',
            _openAnyFile,
          ),
          _action(
            Icons.picture_as_pdf_outlined,
            'Open & edit PDF',
            'Annotate, add text, sign, rearrange and export pages',
            _openPdf,
          ),
          _action(
            Icons.note_add_outlined,
            'Start a blank PDF',
            'Make a document and add your own content',
            _newPdf,
          ),
          _action(
            Icons.photo_library_outlined,
            'Images to PDF',
            'Combine up to 30 images into one document',
            _imagesToPdf,
          ),
          _action(
            Icons.transform_outlined,
            'Convert an image',
            'JPG, PNG and WebP · one file at a time',
            _convertImage,
          ),
          _action(
            Icons.description_outlined,
            'Convert documents',
            'DOCX, ODT, TXT, XLSX, PPTX → PDF · PDF → TXT, DOCX, ODT',
            _convertDocument,
          ),
          _action(
            Icons.document_scanner_outlined,
            'Scan document',
            'Camera, crop and combine pages · saves only on your device',
            _scanDocument,
          ),
        ];
        return Wrap(
          spacing: 12,
          runSpacing: 0,
          children: [
            for (final action in actions)
              SizedBox(width: tileWidth, child: action),
          ],
        );
      },
    );
  }

  Widget _action(
    IconData icon,
    String title,
    String detail,
    Future<void> Function() action,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          leading: Icon(
            icon,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(
            title,
            style: _cosmicEnabled
                ? const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  )
                : const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            detail,
            style: _cosmicEnabled ? const TextStyle(color: Colors.white) : null,
          ),
          trailing: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: _busy ? null : action,
        ),
      ),
    );
  }
}
