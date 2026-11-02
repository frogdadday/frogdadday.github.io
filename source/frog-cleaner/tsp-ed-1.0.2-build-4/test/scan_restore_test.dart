import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frog_cleaner/main.dart';
import 'package:frog_cleaner/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var hasScan = true;
  var removedExclusion = false;
  var cancelled = true;
  var limited = false;
  var warning = '';
  var files = <Map<String, Object?>>[];
  setUp(() {
    hasScan = true;
    removedExclusion = false;
    cancelled = true;
    limited = false;
    warning = '';
    files = [
      {
        'id': 'primary:Download/retained.txt',
        'name': 'retained.txt',
        'location': 'primary:Download/retained.txt',
        'parentId': 'primary:Download',
        'size': 10,
        'modified': 123456789,
        'canDelete': true,
      },
    ];
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(StorageBridge.channel, (call) async {
          if (call.method == 'unignore') {
            removedExclusion = true;
            hasScan = false;
            files = [];
            return <String, Object?>{};
          }
          if (call.method == 'state') {
            return {
              'hasScan': hasScan,
              'files': files,
              'scanSavedAt': 1704067200000,
              'scanStatusKnown': true,
              'scanCancelled': cancelled,
              'scanLimited': limited,
              'scanErrors': 0,
              'saveWarning': warning,
              'roots': [],
              'ignored': removedExclusion
                  ? []
                  : [
                      {'id': 'primary:Keep', 'label': 'Keep'},
                    ],
            };
          }
          return <String, Object?>{};
        });
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(StorageBridge.channel, null);
  });

  testWidgets('Restoring an exclusion clears visible scan results', (
    tester,
  ) async {
    await tester.pumpWidget(const FrogCleaner());
    await tester.pumpAndSettle();
    expect(find.textContaining('partial scan — stopped early'), findsOneWidget);
    await tester.tap(find.text('About').last);
    await tester.pumpAndSettle();
    final restore = find.widgetWithText(TextButton, 'Restore').hitTestable();
    await tester.scrollUntilVisible(
      restore,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();
    expect(removedExclusion, isTrue);
    expect(
      find.textContaining('Exclusion removed. Scan again'),
      findsOneWidget,
    );
    await tester.tap(find.text('Files').last);
    await tester.pumpAndSettle();
    expect(find.text('retained.txt'), findsNothing);
    expect(find.text('Choose a folder and scan from Clean.'), findsOneWidget);
  });

  testWidgets('An empty completed scan restores and reports save failures', (
    tester,
  ) async {
    files = [];
    cancelled = false;
    warning =
        'Could not save the latest results. They may not be available after restarting.';
    await tester.pumpWidget(const FrogCleaner());
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Restored 0 files from the previous scan'),
      findsOneWidget,
    );
    expect(find.textContaining(warning), findsOneWidget);
  });

  testWidgets('A limited scan remains marked partial after reopening', (
    tester,
  ) async {
    cancelled = false;
    limited = true;
    await tester.pumpWidget(const FrogCleaner());
    await tester.pumpAndSettle();
    expect(
      find.textContaining('partial scan — scan limit reached'),
      findsOneWidget,
    );
  });
}
