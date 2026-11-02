// BLOCK ONE
// App setup and theme.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'cache_automation_controller.dart';
import 'clean_page.dart';
import 'cosmic_mode.dart';
import 'frog_heart_icon.dart';
import 'home_page.dart';
import 'storage.dart';
import 'storage_map_page.dart';
import 'storage_scan_controller.dart';
import 'ui_state_controller.dart';

void main() => runApp(const FrogCleaner());

String countedNoun(int count, String singular, [String? plural]) =>
    '$count ${count == 1 ? singular : plural ?? '${singular}s'}';

class FrogCleaner extends StatelessWidget {
  const FrogCleaner({super.key});
  @override
  Widget build(BuildContext context) {
    const background = Color(0xff190d10);
    const surface = Color(0xff241216);
    const surfaceRaised = Color(0xff30171c);
    const frogRed = Color(0xffff241a);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: frogRed,
          brightness: Brightness.dark,
        ).copyWith(
          primary: frogRed,
          onPrimary: const Color(0xff2c0908),
          surface: surface,
          onSurface: const Color(0xfffff0ed),
          surfaceContainerHighest: surfaceRaised,
          outline: const Color(0xffa88486),
        );
    return MaterialApp(
      title: 'Frog Cleaner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: Color(0xfffff0ed),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          color: surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: surface,
          indicatorColor: Color(0xff693036),
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: surface,
        ),
      ),
      home: const CleanerHome(),
    );
  }
}

/////////////////BLOCK TWO////////////////////////////////
/////////////////Home Widget and Global State///////////

class CleanerHome extends StatefulWidget {
  const CleanerHome({super.key});
  @override
  State<CleanerHome> createState() => _CleanerHomeState();
}

class _CleanerHomeState extends State<CleanerHome> with WidgetsBindingObserver {
  final storageController = StorageScanController();
  final cacheController = CacheAutomationController();
  final ui = UIStateController();
  List<StorageFile> files = [];
  List<List<String>> duplicateGroups = [];
  List<Map<Object?, Object?>> roots = [], ignored = [];
  final selected = <String>{};
  bool allFilesAccess = false;
  Timer? _searchDebounce;
  bool busy = false, scanning = false, scanned = false;
  bool duplicatesChecked = false;
  String status = 'Choose a folder to get started.';
  int? total, free;
  final previewBytes = <String, Future<Uint8List?>>{};
  List<CacheApp> cacheApps = [];
  final cacheSelected = <String>{};
  bool cacheAutomationActive = false;
  String? cacheAutomationStatus;

  int get page => ui.page;
  set page(int value) => ui.page = value;
  bool get cosmicMode => ui.cosmicMode;
  set cosmicMode(bool value) => ui.cosmicMode = value;
  List<String> get mapPath => ui.mapPath;
  set mapPath(List<String> value) => ui.mapPath = value;
  List<String>? get fileFolderFilter => ui.fileFolderFilter;
  set fileFolderFilter(List<String>? value) => ui.fileFolderFilter = value;
  String get filter => ui.filter;
  set filter(String value) => ui.filter = value;
  String get search => ui.search;
  set search(String value) => ui.search = value;
  bool get duplicateView => ui.duplicateView;
  set duplicateView(bool value) => ui.duplicateView = value;
  bool get downloadsView => ui.downloadsView;
  set downloadsView(bool value) => ui.downloadsView = value;
  String get downloadFilter => ui.downloadFilter;
  set downloadFilter(String value) => ui.downloadFilter = value;

  /////////////BLOCK THREE////////////////////////////////////////////
  ////////////Lifecycle and Refresh Logic////////////////////////////

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    try {
      final results = await Future.wait([
        storageController.readState(),
        cacheController.status(),
      ]);
      final data = results[0] as StorageStateData;
      final cacheStatus = results[1] as CacheAutomationStatus;
      if (!mounted) return;
      setState(() {
        roots = data.roots;
        ignored = data.ignored;
        total = data.total;
        free = data.free;
        allFilesAccess = data.allFilesAccess;
        final restoredFiles = data.files;
        if (!scanned &&
            files.isEmpty &&
            (data.hasScan || restoredFiles.isNotEmpty)) {
          files = restoredFiles;
          scanned = true;
          final savedDate = validModifiedDate(data.scanSavedAt);
          final scanKind = !data.scanStatusKnown
              ? 'previous scan — completion status unknown'
              : data.scanCancelled
              ? 'partial scan — stopped early'
              : data.scanLimited
              ? 'partial scan — scan limit reached'
              : data.scanErrors > 0
              ? 'partial scan — some folders could not be read'
              : 'previous scan';
          final dateLabel = savedDate == null
              ? ''
              : ' (${MaterialLocalizations.of(context).formatMediumDate(savedDate)})';
          status =
              'Restored ${files.length} files from the $scanKind$dateLabel. Scan again to check for changes.';
        }
        cacheAutomationActive = cacheStatus.running;
        cacheAutomationStatus = cacheStatus.message;
        appendSaveWarning(data.saveWarning);
      });
    } catch (error, stackTrace) {
      debugPrint('Frog Cleaner refresh failed: $error\n$stackTrace');
      if (mounted) {
        setState(() => status = 'Storage access is available on Android.');
      }
    }
  }

  void appendSaveWarning(String? warning) {
    if (warning != null && !status.contains(warning)) {
      status = '$status $warning';
    }
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('Frog Cleaner operation failed: $error\n$stackTrace');
      if (mounted) {
        setState(
          () => status =
              'Could not finish. Access may have changed; check your folders and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          scanning = false;
        });
      }
    }
  }

  //////////////BLOCK FOUR/////////////////////////////////////////////////////////
  ///////////////////Storage Actions (bridge calls)///////////////////////////////

  Future<void> addFolder() => perform(() async {
    final message = await storageController.addFolder();
    if (mounted && message != null) {
      setState(() => status = message);
    }
    await refresh();
  });

  Future<void> requestFullAnalysis() => perform(() async {
    final message = await storageController.requestFullAnalysis();
    if (mounted && message != null) {
      setState(() => status = message);
    }
  });

  Future<void> openManageApps() => perform(() async {
    final message = await storageController.openManageApps();
    if (mounted && message != null) {
      setState(() => status = message);
    }
  });

  Future<void> clearFrogCleanerCache() => perform(() async {
    final result = await cacheController.clearOwnCache();
    final cleared = result.bytes;
    final failures = result.failures;
    previewBytes.clear();
    if (mounted) {
      setState(() {
        status = failures > 0
            ? 'Cleared ${bytes(cleared)} of Frog Cleaner temporary files. $failures items could not be cleared.'
            : cleared == 0
            ? 'Frog Cleaner has no temporary files to clear.'
            : 'Cleared ${bytes(cleared)} of Frog Cleaner temporary files.';
      });
    }
  });

  Future<void> clearAnotherAppCache() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear another app’s cache'),
        content: const Text(
          'Android will open its Apps list. Then:\n\n1. Tap the app you want to tidy.\n2. Tap Storage & cache.\n3. Tap Clear cache.\n\nThis removes temporary files. It does not delete the app, its account, or its saved data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Apps list'),
          ),
        ],
      ),
    );
    if (proceed == true && mounted) await openManageApps();
  }

  Future<void> chooseAutoCacheApps() async {
    final apps = await cacheController.apps();
    if (!mounted) return;
    setState(() => cacheApps = apps);
    if (apps.isEmpty) {
      setState(
        () => status =
            'Android did not return any user-installed apps to review.',
      );
      return;
    }
    final chosen = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final selection = {...cacheSelected};
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.78,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      'Choose apps for cache cleaning',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Only Clear cache is automated. Frog Cleaner never presses Clear storage or Clear data.',
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: apps.length,
                      itemBuilder: (context, index) {
                        final app = apps[index];
                        final packageName = app.packageName;
                        return CheckboxListTile(
                          value: selection.contains(packageName),
                          onChanged: (checked) => setSheetState(() {
                            if (checked == true) {
                              selection.add(packageName);
                            } else {
                              selection.remove(packageName);
                            }
                          }),
                          title: Text(app.label),
                          subtitle: Text(packageName),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      onPressed: selection.isEmpty
                          ? null
                          : () => Navigator.pop(context, selection),
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: Text(
                        'Clean cache for ${countedNoun(selection.length, 'app')}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    setState(() {
      cacheSelected
        ..clear()
        ..addAll(chosen);
    });
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow automatic cache cleaning?'),
        content: Text(
          'Frog Cleaner uses Android Accessibility to read visible app names and control labels in Android Settings, then press Storage & cache and Clear cache for only the ${countedNoun(chosen.length, 'app')} you selected.\n\nThis screen information is processed on your device and is not stored or shared. Frog Cleaner never presses Clear storage or Clear data. You can stop at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Agree and continue'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;
    final availability = await cacheController.status();
    if (!availability.enabled || !availability.connected) {
      await cacheController.openAccessibilitySettings();
      if (mounted) {
        setState(
          () => status =
              'Enable Frog Cleaner’s Cache Cleaner in Android Accessibility, then return here. Your selected apps will remain ready to start.',
        );
      }
      return;
    }
    final result = await cacheController.start(chosen);
    if (mounted) {
      setState(() {
        cacheAutomationActive = result.started;
        status = cacheAutomationActive
            ? 'Automatic cache cleaning started for ${countedNoun(chosen.length, 'selected app', 'selected apps')}. Android Settings is opening each app.'
            : result.message ??
                  'Android could not start automatic cache cleaning on this device.';
      });
    }
  }

  Future<void> stopAutoCacheApps() => perform(() async {
    await cacheController.stop();
    if (mounted) {
      setState(() {
        cacheAutomationActive = false;
        status = 'Automatic cache cleaning stopped.';
      });
    }
  });

  Future<void> openSupport() => perform(() async {
    final opened = await storageController.openSupport();
    if (mounted && !opened) {
      setState(() => status = 'The support page could not be opened.');
    }
  });

  Future<void> openPrivacyPolicy() => perform(() async {
    final opened = await storageController.openPrivacyPolicy();
    if (mounted && !opened) {
      setState(() => status = 'The Privacy Policy page could not be opened.');
    }
  });

  Future<void> scan() => perform(runScan);

  Future<void> runScan({String? startingStatus}) async {
    setState(() {
      previewBytes.clear();
      selected.clear();
      files = [];
      duplicateGroups = [];
      duplicateView = false;
      duplicatesChecked = false;
      downloadsView = false;
      scanned = false;
      scanning = true;
      status =
          startingStatus ??
          (allFilesAccess
              ? 'Reading shared-storage file details…'
              : 'Reading chosen-folder file details…');
    });
    final data = await storageController.scan();
    if (!mounted) return;
    setState(() {
      files = data.files;
      scanned = true;
      status =
          '${data.cancelled
              ? 'Stopped — partial results'
              : data.limited
              ? 'Scan limit reached — partial results'
              : 'Scan finished'}. '
          '${files.length} files; ${data.skipped} exclusions skipped; ${data.errors} folders could not be read.';
      appendSaveWarning(data.saveWarning);
    });
  }

  Future<void> findDuplicates() => perform(() async {
    setState(() {
      selected.clear();
      scanning = true;
      duplicateView = false;
      status = 'Comparing complete file contents on this device…';
    });
    final data = await storageController.findDuplicates();
    if (!mounted) return;
    final groups = data.groups;
    setState(() {
      duplicateGroups = groups;
      duplicateView = true;
      duplicatesChecked = true;
      status = data.cancelled
          ? 'Duplicate search stopped — partial results shown.'
          : '${groups.length} exact duplicate ${groups.length == 1 ? 'group' : 'groups'} found. '
                '${data.hashed} same-size candidate files compared; ${data.errors} could not be read.';
    });
  });

  List<StorageFile> get visible => ui.visibleFiles(files);

  void invalidate(String message) => setState(() {
    files = [];
    duplicateGroups = [];
    duplicateView = false;
    duplicatesChecked = false;
    downloadsView = false;
    selected.clear();
    mapPath = [];
    fileFolderFilter = null;
    scanned = false;
    status = message;
    previewBytes.clear();
  });

  bool previewable(StorageFile file) =>
      file.category == 'Photos' || file.category == 'Videos';

  String modifiedLabel(BuildContext context, StorageFile file) {
    final date = validModifiedDate(file.modified);
    if (date == null) {
      return 'Last modified: unavailable';
    }
    return 'Last modified: ${MaterialLocalizations.of(context).formatMediumDate(date)}';
  }

  Future<Uint8List?> previewFor(StorageFile file, {int maxDimension = 160}) {
    final key = '${file.id}:${file.size}:${file.modified}:$maxDimension';
    final cached = previewBytes[key];
    if (cached != null) return cached;
    if (previewBytes.length >= 80) previewBytes.remove(previewBytes.keys.first);
    final future = () async {
      return storageController.thumbnail(file.id, maxDimension);
    }();
    previewBytes[key] = future;
    future.then(
      (value) {
        if (value == null && identical(previewBytes[key], future)) {
          previewBytes.remove(key);
        }
      },
      onError: (_) {
        if (identical(previewBytes[key], future)) previewBytes.remove(key);
      },
    );
    return future;
  }

  Widget previewThumbnail(StorageFile file, {double size = 58}) {
    if (!previewable(file)) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(
          file.category == 'Audio'
              ? Icons.audio_file_outlined
              : Icons.insert_drive_file_outlined,
        ),
      );
    }
    return FutureBuilder<Uint8List?>(
      future: previewFor(file),
      builder: (context, snapshot) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size,
          height: size,
          child: snapshot.data == null
              ? const ColoredBox(
                  color: Color(0xff3a2024),
                  child: Center(child: Icon(Icons.image_outlined)),
                )
              : Image.memory(snapshot.data!, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget fileLeading(StorageFile file, {required Widget selection}) => SizedBox(
    width: 118,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [selection, const SizedBox(width: 4), previewThumbnail(file)],
    ),
  );

  Future<void> ignore(String id, String label) => perform(() async {
    await storageController.ignore(id, label);
    if (!mounted) return;
    await refresh();
    if (!mounted) return;
    await runScan(startingStatus: 'Exclusion saved. Updating this scan…');
  });

  Future<void> inspect(StorageFile f) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (previewable(f)) ...[
                Center(
                  child: FutureBuilder<Uint8List?>(
                    future: previewFor(f, maxDimension: 1200),
                    builder: (context, snapshot) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child:
                            snapshot.connectionState == ConnectionState.waiting
                            ? const SizedBox(
                                height: 140,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : snapshot.data == null
                            ? const SizedBox(
                                height: 140,
                                child: Center(
                                  child: Text(
                                    'Preview unavailable for this image.\nYou can still open it with another app.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : Image.memory(snapshot.data!, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  f.category == 'Videos'
                      ? 'Preview frame from this video'
                      : 'Preview shown inside Frog Cleaner',
                ),
                const SizedBox(height: 12),
              ],
              SelectableText(f.location),
              const SizedBox(height: 12),
              Text(
                '${f.size == null ? 'Unknown size' : bytes(f.size!)} • ${f.category}',
              ),
              Text(
                validModifiedDate(f.modified) == null
                    ? 'Modification date unavailable'
                    : 'Last modified: ${validModifiedDate(f.modified)!.toString().split('.').first}',
              ),
              const SizedBox(height: 16),
              Text(f.reason(DateTime.now())),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pop(context, 'open'),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open with another app'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pop(context, 'file'),
                icon: const Icon(Icons.block_outlined),
                label: const Text('Exclude this file from future scans'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pop(context, 'folder'),
                icon: const Icon(Icons.folder_off_outlined),
                label: const Text('Exclude this folder from future scans'),
              ),
              const Text(
                'Eligible photos, videos, and audio can be moved to Android Trash during deletion review when Full device analysis is enabled. Other deletions are permanent and cannot be undone.',
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'file') await ignore(f.id, f.name);
    if (choice == 'folder') {
      await ignore(
        f.parentId,
        f.location.substring(0, f.location.lastIndexOf('/')),
      );
    }
    if (choice == 'open') {
      await perform(() async {
        final message = await storageController.openFile(f.id);
        if (mounted && message != null) {
          setState(() => status = message);
        }
      });
    }
  }

  Future<void> deleteSelected() async {
    final chosen = files.where((f) => selected.contains(f.id)).toList();
    if (chosen.isEmpty) return;
    final trashable = chosen
        .where(
          (file) =>
              allFilesAccess &&
              ['Photos', 'Videos', 'Audio'].contains(file.category),
        )
        .toList();
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Review ${chosen.length} selected files'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trashable.isEmpty
                      ? 'Android Trash is only available for supported photos, videos, and audio after Full device analysis is enabled. These files can be kept or deleted permanently.'
                      : '${trashable.length} selected ${trashable.length == 1 ? 'media file can' : 'media files can'} move to Android Trash. Android normally removes trashed media after about 30 days. Other selected files stay selected for you to review.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Android Trash is reversible for a limited time. Permanent deletion has no undo.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: chosen.length,
                    itemBuilder: (context, index) {
                      final f = chosen[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${f.location}\n${f.size == null ? 'Unknown size' : bytes(f.size!)} • ${trashable.contains(f) ? 'Android Trash available' : 'Permanent delete only'}',
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep files'),
          ),
          if (trashable.isNotEmpty)
            OutlinedButton(
              onPressed: () => Navigator.pop(context, 'trash'),
              child: Text('Move ${trashable.length} to Android Trash'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'permanent'),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (choice == 'trash') {
      await trashSelected();
      return;
    }
    if (choice != 'permanent' || !mounted) return;
    await perform(() async {
      final data = await storageController.delete(
        chosen.map((f) => f.id),
        duplicateRetainedGroupsFor(chosen.map((f) => f.id).toSet()),
      );
      if (!mounted) return;
      final deleted = data.removed;
      final deletionStatus =
          '${countedNoun(deleted.length, 'file')} permanently deleted (${bytes(data.bytes)} in file sizes). '
          '${data.failed.length} skipped or failed. Available space may update later.';
      setState(() {
        files.removeWhere((f) => deleted.contains(f.id));
        selected.clear();
        status = deletionStatus;
        appendSaveWarning(data.saveWarning);
      });
      setState(() => busy = false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Deletion results'),
          content: SingleChildScrollView(
            child: Text(
              '$status${data.failed.isEmpty ? '' : '\n\n${data.failed.join('\n')}'}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) await refresh();
    });
  }

  Future<void> trashSelected() async {
    final chosen = files
        .where(
          (file) =>
              selected.contains(file.id) &&
              ['Photos', 'Videos', 'Audio'].contains(file.category),
        )
        .toList();
    if (chosen.isEmpty) return;
    await perform(() async {
      final data = await storageController.trash(
        chosen.map((file) => file.id),
        duplicateRetainedGroupsFor(chosen.map((file) => file.id).toSet()),
      );
      if (!mounted) return;
      final trashed = data.removed;
      final failed = data.failed;
      setState(() {
        files.removeWhere((file) => trashed.contains(file.id));
        selected.removeAll(trashed);
        status =
            data.message ??
            '${trashed.length} media files moved to Android Trash '
                '(${bytes(data.bytes)} in file sizes). '
                '${failed.length} skipped or not moved.';
        appendSaveWarning(data.saveWarning);
      });
    });
  }

  /////////////////BLOCK FIVE//////////////////////////////////////////////////
  ////////////////////UI Helpers (Preview, Thumbnails, Panels)///////////////

  Widget panel(Widget child) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
  Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
  Widget sectionDivider() => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 4),
    child: Divider(
      height: 2,
      thickness: 2,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.72),
    ),
  );

  Future<void> showFilterHelp() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('File filters'),
      content: const Text(
        'Large means at least 100 MiB. Old means the last-modified date is over one year ago. Neither means a file is unnecessary. The remaining filters group files by type.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );

  ///////////////BLOCK SIX////////////////////////////////////////////
  /////////////Home Page UI///////////////////////////////////////////////

  Widget home() => CleanerHomePage(
    cosmicMode: cosmicMode,
    total: total,
    free: free,
    scanned: scanned,
    files: files,
    allFilesAccess: allFilesAccess,
    onOpenClean: () => setState(() => page = 1),
    onReviewFiles: () => setState(() => page = 2),
  );

  Widget clean() => CleanerCleanPage(
    allFilesAccess: allFilesAccess,
    roots: roots,
    busy: busy,
    cacheAutomationActive: cacheAutomationActive,
    onAddFolder: addFolder,
    onRequestFullAnalysis: requestFullAnalysis,
    onScan: scan,
    onOpenManageApps: openManageApps,
    onClearOwnCache: clearFrogCleanerCache,
    onClearAnotherAppCache: clearAnotherAppCache,
    onChooseAutoCacheApps: chooseAutoCacheApps,
    onStopAutoCacheApps: stopAutoCacheApps,
  );

  /////////////////////BLOCK SEVEN////////////////////////////////////////////////
  ////////////////////File Review Pages///////////////////////////////////////////

  Widget filePage() {
    if (duplicateView) return duplicatePage();
    if (downloadsView) return downloadsPage();
    final shown = visible;
    final chosen = files.where((f) => selected.contains(f.id)).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy || !scanned ? null : findDuplicates,
                    icon: const Icon(Icons.content_copy_outlined),
                    label: const Text('Find exact duplicates'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy || !scanned
                        ? null
                        : () => setState(() {
                            selected.clear();
                            downloadsView = true;
                            downloadFilter = 'All';
                          }),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Review Downloads'),
                  ),
                ],
              ),
              if (duplicatesChecked) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    duplicateGroups.isEmpty
                        ? 'No exact duplicates were found in the latest comparison.'
                        : '${duplicateGroups.length} duplicate groups available to review.',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 250),
                    () {
                      if (mounted) setState(() => search = v);
                    },
                  );
                },
                decoration: const InputDecoration(
                  labelText: 'Find a file or folder',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children:
                            [
                                  'All',
                                  'Large',
                                  'Old',
                                  'Installers',
                                  'Videos',
                                  'Photos',
                                  'Audio',
                                  'Archives',
                                  'Other files',
                                ]
                                .map(
                                  (v) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(v),
                                      selected: filter == v,
                                      selectedColor: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                      side: filter == v
                                          ? BorderSide(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              width: 2,
                                            )
                                          : null,
                                      onSelected: (_) =>
                                          setState(() => filter = v),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Explain file filters',
                    onPressed: showFilterHelp,
                    icon: const Icon(Icons.help_outline),
                  ),
                ],
              ),
              if (allFilesAccess)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: ui.showOnlyDeletableMedia,
                  onChanged: (value) =>
                      setState(() => ui.showOnlyDeletableMedia = value),
                  title: const Text('Show only deletable media'),
                  subtitle: const Text(
                    'Photos, videos, and audio currently eligible for selection.',
                  ),
                ),
              Text(
                '${shown.length} files • largest first • tap ⓘ beside a file to review or exclude it',
              ),
              if (fileFolderFilter != null)
                TextButton.icon(
                  onPressed: () => setState(() => fileFolderFilter = null),
                  icon: const Icon(Icons.close),
                  label: const Text('Show all scanned files'),
                ),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      scanned
                          ? 'No files match this view. Keeping everything is fine.'
                          : 'Choose a folder and scan from Clean.',
                    ),
                  ),
                )
              : ListView.builder(
                  key: const ValueKey('files-list'),
                  padding: const EdgeInsets.only(bottom: 152),
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final f = shown[i];
                    return ListTile(
                      key: ValueKey('file-row-${f.id}'),
                      leading: fileLeading(
                        f,
                        selection: Checkbox(
                          key: ValueKey('file-checkbox-${f.id}'),
                          value: selected.contains(f.id),
                          semanticLabel: 'Select ${f.name}',
                          onChanged: busy || !f.canDelete
                              ? null
                              : (value) => setState(() {
                                  if (value == true) {
                                    selected.add(f.id);
                                  } else {
                                    selected.remove(f.id);
                                  }
                                }),
                        ),
                      ),
                      title: Text(f.name),
                      subtitle: Text(
                        '${f.size == null ? 'Unknown size' : bytes(f.size!)} • ${f.category}\n${modifiedLabel(context, f)}\n${f.location}${f.canDelete ? '' : '\nRead only or insufficient metadata to delete safely'}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Review or exclude ${f.name}',
                        onPressed: busy ? null : () => inspect(f),
                        icon: const Icon(Icons.info_outline),
                      ),
                      onTap: busy ? null : () => inspect(f),
                    );
                  },
                ),
        ),
        if (selected.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${chosen.length} selected across all filters • ${bytes(chosen.fold(0, (s, f) => s + (f.size ?? 0)))}',
                  ),
                  Wrap(
                    spacing: 12,
                    children: [
                      TextButton(
                        onPressed: busy ? null : () => setState(selected.clear),
                        child: const Text('Clear selection'),
                      ),
                      FilledButton.icon(
                        onPressed: busy ? null : deleteSelected,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Review deletion options'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<List<StorageFile>> get liveDuplicateGroups {
    final filesById = {for (final file in files) file.id: file};
    return duplicateGroups
        .map(
          (group) => group
              .map((id) => filesById[id])
              .whereType<StorageFile>()
              .toList(),
        )
        .where((group) => group.length > 1)
        .toList();
  }

  List<List<String>> duplicateRetainedGroupsFor(Set<String> removalIds) =>
      liveDuplicateGroups
          .where((group) => group.any((file) => removalIds.contains(file.id)))
          .map(
            (group) => group
                .where((file) => !removalIds.contains(file.id))
                .map((file) => file.id)
                .toList(),
          )
          .toList();

  void selectDuplicate(StorageFile file, List<StorageFile> group, bool value) {
    setState(() {
      if (!value) {
        selected.remove(file.id);
        return;
      }
      if (!canSelectDuplicateCopy(
        group.map((member) => member.id),
        selected,
        file.id,
      )) {
        status = 'Keep at least one copy from each duplicate group.';
        return;
      }
      selected.add(file.id);
    });
  }

  void keepDuplicateAndSelectOthers(StorageFile keep, List<StorageFile> group) {
    setState(() {
      for (final file in group) {
        if (file.id == keep.id || !file.canDelete) {
          selected.remove(file.id);
        } else {
          selected.add(file.id);
        }
      }
      status =
          'Keeping ${keep.name}. Review the selected copies before deleting.';
    });
  }

  Widget duplicatePage() {
    final groups = liveDuplicateGroups;
    final chosen = files.where((file) => selected.contains(file.id)).toList();
    final reclaimable = groups.fold<int>(
      0,
      (sum, group) => sum + ((group.first.size ?? 0) * (group.length - 1)),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back to all files',
                    onPressed: () => setState(() => duplicateView = false),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      'Exact duplicates',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Compare again',
                    onPressed: busy ? null : findDuplicates,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              Text(
                '${groups.length} ${groups.length == 1 ? 'group' : 'groups'} • up to ${bytes(reclaimable)} removable while keeping one copy of each file',
              ),
              const SizedBox(height: 8),
              const Text(
                'Files are grouped only after their complete contents match. Nothing is selected automatically.',
              ),
            ],
          ),
        ),
        Expanded(
          child: groups.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No exact duplicate groups remain.'),
                  ),
                )
              : ListView.builder(
                  key: const ValueKey('duplicate-list'),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final fileSize = group.first.size ?? 0;
                    return Card(
                      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      child: ExpansionTile(
                        initiallyExpanded: index == 0,
                        leading: const Icon(Icons.copy_all_outlined),
                        title: Text(
                          '${group.length} identical files • ${bytes(fileSize)} each',
                        ),
                        subtitle: Text(
                          'Select up to ${group.length - 1}; one copy must stay.',
                        ),
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        children: group
                            .map(
                              (file) => CheckboxListTile(
                                key: ValueKey('duplicate-${file.id}'),
                                value: selected.contains(file.id),
                                onChanged: busy || !file.canDelete
                                    ? null
                                    : (value) => selectDuplicate(
                                        file,
                                        group,
                                        value == true,
                                      ),
                                title: Text(file.name),
                                subtitle: Text(
                                  '${modifiedLabel(context, file)}\n${file.location}',
                                ),
                                secondary: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    previewThumbnail(file, size: 42),
                                    IconButton(
                                      tooltip: 'Inspect ${file.name}',
                                      onPressed: busy
                                          ? null
                                          : () => inspect(file),
                                      icon: const Icon(Icons.info_outline),
                                    ),
                                    IconButton(
                                      tooltip:
                                          'Keep ${file.name} and select the other copies',
                                      onPressed: busy
                                          ? null
                                          : () => keepDuplicateAndSelectOthers(
                                              file,
                                              group,
                                            ),
                                      icon: const Icon(Icons.bookmark_outline),
                                    ),
                                  ],
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            )
                            .toList(),
                      ),
                    );
                  },
                ),
        ),
        if (selected.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => setState(selected.clear),
                    child: const Text('Clear selection'),
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : deleteSelected,
                    icon: const Icon(Icons.delete_outline),
                    label: Text('Review ${chosen.length} deletion options'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget downloadsPage() {
    final downloads = files.where(isDownloadFile).where((file) {
      if (downloadFilter == 'All') return true;
      if (downloadFilter == 'Large') {
        return (file.size ?? 0) >= 100 * 1024 * 1024;
      }
      if (downloadFilter == 'Old') return file.oldAt(DateTime.now());
      return file.category == downloadFilter;
    }).toList()..sort((a, b) => (b.size ?? -1).compareTo(a.size ?? -1));
    final allDownloads = files.where(isDownloadFile).toList();
    final chosen = files.where((file) => selected.contains(file.id)).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back to all files',
                    onPressed: () => setState(() => downloadsView = false),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      'Downloads Review',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              Text(
                '${allDownloads.length} downloaded ${allDownloads.length == 1 ? 'file' : 'files'} • ${bytes(allDownloads.fold(0, (sum, file) => sum + (file.size ?? 0)))} scanned',
              ),
              const SizedBox(height: 8),
              const Text(
                'Review installers, archives, large files, and older downloads. Nothing is selected automatically.',
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: ['All', 'Installers', 'Archives', 'Large', 'Old']
                      .map(
                        (value) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(value),
                            selected: downloadFilter == value,
                            onSelected: (_) =>
                                setState(() => downloadFilter = value),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: downloads.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      allDownloads.isEmpty
                          ? 'No downloaded files were found in this scan.'
                          : 'No downloads match this filter.',
                    ),
                  ),
                )
              : ListView.builder(
                  key: const ValueKey('downloads-list'),
                  itemCount: downloads.length,
                  itemBuilder: (context, index) {
                    final file = downloads[index];
                    return ListTile(
                      key: ValueKey('download-row-${file.id}'),
                      leading: fileLeading(
                        file,
                        selection: Checkbox(
                          key: ValueKey('download-checkbox-${file.id}'),
                          value: selected.contains(file.id),
                          semanticLabel: 'Select ${file.name}',
                          onChanged: busy || !file.canDelete
                              ? null
                              : (value) => setState(() {
                                  if (value == true) {
                                    selected.add(file.id);
                                  } else {
                                    selected.remove(file.id);
                                  }
                                }),
                        ),
                      ),
                      title: Text(file.name),
                      subtitle: Text(
                        '${file.size == null ? 'Unknown size' : bytes(file.size!)} • ${downloadReason(file, DateTime.now())}\n${modifiedLabel(context, file)}\n${file.location}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Review or exclude ${file.name}',
                        onPressed: busy ? null : () => inspect(file),
                        icon: const Icon(Icons.info_outline),
                      ),
                      onTap: busy ? null : () => inspect(file),
                    );
                  },
                ),
        ),
        if (selected.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => setState(selected.clear),
                    child: const Text('Clear selection'),
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : deleteSelected,
                    icon: const Icon(Icons.delete_outline),
                    label: Text('Review ${chosen.length} deletion options'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget storageMap() {
    return StorageMapPage(
      scanned: scanned,
      files: files,
      path: mapPath,
      onUp: () => setState(() {
        mapPath = mapPath.sublist(0, mapPath.length - 1);
      }),
      onOpenFiles: (path) => setState(() {
        fileFolderFilter = path;
        page = 2;
      }),
      onOpenFolder: (path) => setState(() => mapPath = path),
    );
  }

  Widget settings() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              'About',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          Semantics(
            label: 'Friendly frog mascot',
            image: true,
            child: SizedBox(
              width: 82,
              height: 86,
              child: CosmicFrog(cosmicMode: cosmicMode),
            ),
          ),
        ],
      ),
      heading('Your privacy'),
      const Text(
        'All analysis happens on this device. Frog Cleaner has no analytics, account, or background scanning. Normal scans read file names, sizes, and dates. Previews and duplicate checking read file contents locally. Opening a file hands it to an app you choose.',
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: busy ? null : openPrivacyPolicy,
        icon: const Icon(Icons.privacy_tip_outlined),
        label: const Text('Privacy Policy'),
      ),
      const SizedBox(height: 4),
      const Text('Read how Frog Cleaner handles storage access and file data.'),
      const SizedBox(height: 12),
      const Text(
        'Cosmic Mode adds animated stars, title effects, and frog movement. Android reduced-motion settings automatically calm these effects.',
      ),
      sectionDivider(),
      heading('Folder access'),
      const Text(
        'Folders added from Clean are listed here. Remove access only when you no longer want Frog Cleaner to scan that folder.',
      ),
      if (roots.isEmpty) const ListTile(title: Text('No chosen folders yet')),
      ...roots.map(
        (r) => ListTile(
          title: Text(r['label'] as String),
          trailing: TextButton(
            onPressed: busy
                ? null
                : () => perform(() async {
                    await storageController.forgetFolder(r['uri'] as String);
                    if (!mounted) return;
                    invalidate(
                      'Folder access removed. Scan remaining folders to refresh.',
                    );
                    await refresh();
                  }),
            child: const Text('Remove'),
          ),
        ),
      ),
      sectionDivider(),
      heading('Exclusions and deletion'),
      const Text(
        'Tap ⓘ beside any file to exclude that file or its containing folder. Frog Cleaner immediately refreshes the current scan. Restore an excluded item here, then scan again.',
      ),
      if (ignored.isEmpty) const ListTile(title: Text('No exclusions yet')),
      ...ignored.map(
        (e) => ListTile(
          title: Text(e['label'] as String),
          trailing: TextButton(
            onPressed: busy
                ? null
                : () => perform(() async {
                    await storageController.restoreExclusion(e['id'] as String);
                    if (!mounted) return;
                    invalidate(
                      'Exclusion removed. Scan again to update your file list and folder map.',
                    );
                    await refresh();
                  }),
            child: const Text('Restore'),
          ),
        ),
      ),
      sectionDivider(),
      heading('Deletion'),
      const Text(
        'Eligible photos, videos, and audio can be moved to Android Trash after Full device analysis is enabled. Other file types are permanent deletion only. Nothing is selected automatically.',
      ),
      sectionDivider(),
      heading('Support Frog Cleaner'),
      const Text(
        'If Frog Cleaner has been helpful, you can optionally send the developer a coffee. Every feature remains free either way.',
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: busy ? null : openSupport,
        icon: const FrogHeartIcon(),
        label: const Text('Send Me a Coffee'),
      ),
      sectionDivider(),
      heading('Frog Cleaner'),
      const Text('Version 1.0.1\nFree. Simple. Respectful.'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final reviewingFiles = page == 2 && (duplicateView || downloadsView);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactHeader =
        MediaQuery.sizeOf(context).width < 400 || textScale >= 1.5;
    return PopScope(
      canPop: !reviewingFiles,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && reviewingFiles) {
          setState(() {
            duplicateView = false;
            downloadsView = false;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: cosmicMode ? Colors.transparent : null,
          flexibleSpace: cosmicMode
              ? const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xff3b0c14), Color(0xff1b070c)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                )
              : null,
          title: cosmicMode
              ? const CosmicFadingTitle(text: 'Frog Cleaner')
              : const Text('Frog Cleaner'),
          actions: [
            if (compactHeader)
              IconButton(
                tooltip: cosmicMode
                    ? 'Turn Cosmic Mode off'
                    : 'Turn Cosmic Mode on',
                icon: Icon(
                  cosmicMode ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                  color: cosmicMode ? const Color(0xffffa333) : null,
                ),
                onPressed: () => setState(() => cosmicMode = !cosmicMode),
              )
            else
              Tooltip(
                message: cosmicMode
                    ? 'Turn Cosmic Mode off'
                    : 'Turn Cosmic Mode on',
                child: TextButton.icon(
                  icon: Icon(
                    cosmicMode
                        ? Icons.auto_awesome
                        : Icons.auto_awesome_outlined,
                    color: cosmicMode ? const Color(0xffffa333) : null,
                  ),
                  label: const Text('Cosmic Mode'),
                  onPressed: () => setState(() => cosmicMode = !cosmicMode),
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            if (cosmicMode) const Positioned.fill(child: RedCosmicBackdrop()),
            SafeArea(
              child: Column(
                children: [
                  if (busy) const LinearProgressIndicator(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(status),
                  ),
                  if (cacheAutomationStatus != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(cacheAutomationStatus!),
                      ),
                    ),
                  if (scanning)
                    TextButton(
                      onPressed: () async {
                        await storageController.cancel();
                      },
                      child: const Text('Stop current work'),
                    ),
                  Expanded(
                    child: IndexedStack(
                      index: page,
                      children: [
                        home(),
                        clean(),
                        filePage(),
                        storageMap(),
                        settings(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          height: textScale >= 1.5 ? 96 : 80,
          backgroundColor: cosmicMode ? const Color(0xff210a0e) : null,
          indicatorColor: cosmicMode ? const Color(0xff713039) : null,
          selectedIndex: page,
          onDestinationSelected: (v) => setState(() => page = v),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.cleaning_services_outlined),
              label: 'Clean',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              label: 'Files',
            ),
            NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
            NavigationDestination(
              icon: Icon(Icons.info_outline),
              label: 'About',
            ),
          ],
        ),
      ),
    );
  }
}
