import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frog_cleaner/cosmic_mode.dart';
import 'package:frog_cleaner/main.dart';
import 'package:frog_cleaner/storage.dart';
import 'package:frog_cleaner/ui_state_controller.dart';

Map<String, Object?> item(
  String id, {
  String? name,
  String? location,
  int? modified = 1,
  int? size = 200000000,
  bool canDelete = true,
}) => {
  'id': id,
  'name': name ?? '$id.apk',
  'location': location ?? 'primary:Test/$id.apk',
  'parentId': 'primary:Test',
  'size': size,
  'modified': modified,
  'canDelete': canDelete,
};

void main() {
  test('Overlapping scan sources count each document once', () {
    final files = uniqueFiles([StorageFile(item('a')), StorageFile(item('a'))]);
    expect(files.length, 1);
    expect(files.fold<int>(0, (s, f) => s + (f.size ?? 0)), 200000000);
  });
  test('Unknown and future dates never imply old or unused', () {
    final now = DateTime(2026, 9, 10);
    expect(StorageFile(item('a', modified: null)).oldAt(now), false);
    expect(StorageFile(item('a', modified: 0)).oldAt(now), false);
    expect(
      StorageFile(
        item('a', modified: DateTime(2027).millisecondsSinceEpoch),
      ).oldAt(now),
      false,
    );
    expect(StorageFile(item('a')).reason(now), contains('Keep it'));
  });
  test('Unknown size remains unknown; binary units are labeled accurately', () {
    expect(StorageFile(item('a', size: null)).size, null);
    expect(bytes(1024 * 1024), '1.0 MiB');
  });
  test('Visible counts use correct singular and plural wording', () {
    expect(countedNoun(1, 'app'), '1 app');
    expect(countedNoun(2, 'app'), '2 apps');
    expect(countedNoun(1, 'selected app', 'selected apps'), '1 selected app');
  });
  test('Only photos, videos, and audio are candidates for Android Trash', () {
    expect(StorageFile(item('photo', name: 'photo.jpg')).category, 'Photos');
    expect(StorageFile(item('clip', name: 'clip.mp4')).category, 'Videos');
    expect(StorageFile(item('song', name: 'song.mp3')).category, 'Audio');
    expect(
      StorageFile(item('archive', name: 'archive.zip')).category,
      'Archives',
    );
  });
  test('Storage map totals nested folders and supports drill-down', () {
    final files = [
      StorageFile(
        item('one', size: 100, location: 'primary:Downloads/Movies/one.mp4'),
      ),
      StorageFile(
        item('two', size: 300, location: 'primary:Downloads/Movies/two.mp4'),
      ),
      StorageFile(
        item('three', size: 50, location: 'primary:Pictures/three.jpg'),
      ),
    ];
    final root = folderSummaries(files, []);
    expect(root.first.name, 'Downloads');
    expect(root.first.bytes, 400);
    final downloads = folderSummaries(files, ['Downloads']);
    expect(downloads.single.name, 'Movies');
    final movies = folderSummaries(files, ['Downloads', 'Movies']);
    expect(movies.single.directFiles, true);
    expect(movies.single.fileCount, 2);
  });
  test('Duplicate selection always keeps one copy', () {
    const group = ['a', 'b', 'c'];
    expect(canSelectDuplicateCopy(group, <String>{}, 'a'), true);
    expect(canSelectDuplicateCopy(group, {'a'}, 'b'), true);
    expect(canSelectDuplicateCopy(group, {'a', 'b'}, 'c'), false);
  });
  test('Deletable media filter excludes read-only and non-media files', () {
    final controller = UIStateController()..showOnlyDeletableMedia = true;
    final visible = controller.visibleFiles([
      StorageFile(item('photo', name: 'photo.jpg')),
      StorageFile(item('readonly', name: 'readonly.jpg', canDelete: false)),
      StorageFile(item('archive', name: 'archive.zip')),
    ]);
    expect(visible.map((file) => file.id), ['photo']);
  });
  test(
    'Downloads are recognized without treating every file as a download',
    () {
      final downloaded = StorageFile(
        item('setup', location: 'primary:Download/setup.apk'),
      );
      final document = StorageFile(
        item('notes', location: 'primary:Documents/notes.txt'),
      );
      expect(isDownloadFile(downloaded), true);
      expect(downloadReason(downloaded, DateTime.now()), 'Installer file');
      expect(isDownloadFile(document), false);
    },
  );

  TestWidgetsFlutterBinding.ensureInitialized();
  var deletionCalls = 0;
  var fullAnalysisCalls = 0;
  var manageAppsCalls = 0;
  var supportCalls = 0;
  setUp(() {
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    deletionCalls = 0;
    fullAnalysisCalls = 0;
    manageAppsCalls = 0;
    supportCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(StorageBridge.channel, (call) async {
          switch (call.method) {
            case 'state':
              return {
                'total': 1000000000,
                'free': 500000000,
                'allFilesAccess': false,
                'roots': [
                  {'uri': 'test', 'label': 'Test', 'readable': true},
                ],
                'ignored': [],
              };
            case 'scan':
              return {
                'files': [
                  item('a', location: 'primary:Download/a.apk'),
                  item('b'),
                ],
                'errors': 0,
                'skipped': 0,
              };
            case 'duplicates':
              return {
                'groups': [
                  [item('a'), item('b')],
                ],
                'hashed': 2,
                'errors': 0,
                'cancelled': false,
              };
            case 'delete':
              deletionCalls++;
              return {
                'deleted': ['a'],
                'failed': ['b: changed'],
                'bytes': 200000000,
              };
            case 'requestAllFilesAccess':
              fullAnalysisCalls++;
              return {
                'message':
                    "Use Android's next screen to allow full device analysis, then return here.",
              };
            case 'openManageApps':
              manageAppsCalls++;
              return {
                'message':
                    "Android's app controls are open. Frog Cleaner will not make changes there.",
              };
            case 'openSupport':
              supportCalls++;
              return {'opened': true};
            default:
              return <String, Object?>{};
          }
        });
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(StorageBridge.channel, null);
  });

  testWidgets(
    'Personal files start unselected and cancellation never deletes',
    (tester) async {
      await tester.pumpWidget(const FrogCleaner());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Clean').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Scan folders'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Scan folders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Files').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .every((c) => c.value == false),
        true,
      );
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review deletion options'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Android Trash is only available'),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep files'));
      await tester.pumpAndSettle();
      expect(deletionCalls, 0);
    },
  );

  testWidgets('Deletion removes only IDs confirmed by Android', (tester) async {
    await tester.pumpWidget(const FrogCleaner());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clean').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Scan folders'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Scan folders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Files').last);
    await tester.pumpAndSettle();
    final firstFile = find.byKey(const ValueKey('file-checkbox-a'));
    await tester.tap(firstFile);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(firstFile).value, true);
    await tester.tap(find.text('Review deletion options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();
    expect(deletionCalls, 1);
    expect(find.textContaining('b: changed'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('a.apk'), findsNothing);
    expect(find.text('b.apk'), findsOneWidget);
  });

  testWidgets(
    'Duplicate review keeps one copy and selects nothing by default',
    (tester) async {
      await tester.pumpWidget(const FrogCleaner());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clean').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Scan folders'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Scan folders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Files').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find exact duplicates'));
      await tester.pumpAndSettle();

      expect(find.text('Exact duplicates'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const ValueKey('duplicate-a')))
            .value,
        false,
      );
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const ValueKey('duplicate-b')))
            .value,
        false,
      );
    },
  );

  testWidgets('Downloads Review starts with nothing selected', (tester) async {
    await tester.pumpWidget(const FrogCleaner());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clean').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Scan folders'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Scan folders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Files').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review Downloads'));
    await tester.pumpAndSettle();

    expect(find.text('Downloads Review'), findsOneWidget);
    expect(find.textContaining('Installer file'), findsOneWidget);
    expect(
      tester
          .widget<Checkbox>(find.byKey(const ValueKey('download-checkbox-a')))
          .value,
      false,
    );
  });

  testWidgets('Home supports a narrow screen and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(const FrogCleaner());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Turn Cosmic Mode on'), findsOneWidget);
    expect(find.text('Cosmic Mode'), findsNothing);
    for (final label in ['Home', 'Clean', 'Files', 'Map', 'About']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('Full device analysis stays optional until requested', (
    tester,
  ) async {
    await tester.pumpWidget(const FrogCleaner());
    await tester.pumpAndSettle();
    expect(fullAnalysisCalls, 0);

    await tester.tap(find.text('Clean').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Enable full analysis'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enable full analysis'));
    await tester.pumpAndSettle();

    expect(fullAnalysisCalls, 1);
    expect(find.textContaining("Use Android's next screen"), findsOneWidget);
  });

  testWidgets('Manage apps opens Android controls without changing apps', (
    tester,
  ) async {
    await tester.pumpWidget(const FrogCleaner());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clean').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Open Android app controls'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Open Android app controls'));
    await tester.pumpAndSettle();

    expect(manageAppsCalls, 1);
    expect(
      find.textContaining("Frog Cleaner will not make changes"),
      findsOneWidget,
    );
  });

  testWidgets('Coffee support remains optional', (tester) async {
    await tester.pumpWidget(const FrogCleaner());
    await tester.pumpAndSettle();
    await tester.tap(find.text('About').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Send Me a Coffee'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Send Me a Coffee'));
    await tester.pumpAndSettle();

    expect(supportCalls, 1);
  });

  testWidgets(
    'Cosmic Mode changes the background, title, and frog only when enabled',
    (tester) async {
      await tester.pumpWidget(const FrogCleaner());
      await tester.pumpAndSettle();
      expect(find.byType(RedCosmicBackdrop), findsNothing);
      expect(find.byType(CosmicFadingTitle), findsNothing);

      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.tap(find.byTooltip('Turn Cosmic Mode on'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(RedCosmicBackdrop), findsOneWidget);
      expect(find.byType(CosmicFadingTitle), findsOneWidget);
      expect(find.byType(CosmicFrog), findsOneWidget);

      final opacityAtStart = tester
          .widget<Opacity>(find.byKey(const ValueKey('cosmic-title-opacity')))
          .opacity;
      await tester.pump(const Duration(milliseconds: 2500));
      final opacityAtHalfCycle = tester
          .widget<Opacity>(find.byKey(const ValueKey('cosmic-title-opacity')))
          .opacity;
      expect(opacityAtStart, greaterThan(opacityAtHalfCycle));

      await tester.tap(find.byTooltip('Turn Cosmic Mode off'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(RedCosmicBackdrop), findsNothing);
      expect(find.byType(CosmicFadingTitle), findsNothing);
    },
  );
}
