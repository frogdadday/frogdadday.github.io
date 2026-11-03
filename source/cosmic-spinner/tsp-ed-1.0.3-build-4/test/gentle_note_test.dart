import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sean_johnston/models/spinner_model.dart';
import 'package:sean_johnston/screens/editor_page.dart';
import 'package:sean_johnston/screens/preview_page.dart';
import 'package:sean_johnston/screens/saved_page.dart';
import 'package:sean_johnston/services/app_controller.dart';
import 'package:sean_johnston/theme/app_theme.dart';
import 'package:sean_johnston/widgets/gentle_note_dialog.dart';

import 'storage_harness.dart';

void main() {
  setUp(mockStorage);
  Future<AppController> mount(
    WidgetTester tester,
    Widget Function(AppController) page,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = AppController();
    await tester.pumpWidget(
      MaterialApp(key: UniqueKey(), theme: buildAppTheme(), home: page(c)),
    );
    await tester.pumpAndSettle();
    addTearDown(c.dispose);
    return c;
  }

  SpinnerModel movie() => SpinnerModel(
    id: 'movies',
    title: 'Die Hard night',
    slices: ['Die Hard', 'Comedy'],
    colorValue: 0xFF37A7FF,
  );

  testWidgets(
    'keyword never blocks editing or draft; note follows successful save only',
    (tester) async {
      final c = await mount(tester, (c) => EditorPage(controller: c));
      await tester.enterText(
        find.byKey(const Key('spinner-title-field')),
        'Movie night',
      );
      await tester.enterText(
        find.byKey(const Key('slice-field-0')),
        'Die Hard',
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('slice-field-1')),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byKey(const Key('slice-field-1')), 'Comedy');
      await tester.pump(const Duration(seconds: 1));
      expect(c.draft?.slices.first, 'Die Hard');
      expect(find.byType(GentleNoteDialog), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.scrollUntilVisible(
        find.byKey(const Key('commit-spinner')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('commit-spinner')));
      await tester.pumpAndSettle();
      expect(find.byType(PreviewPage), findsOneWidget);
      expect(find.byType(GentleNoteDialog), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('save-whole-spinner')));
      await tester.tap(find.byKey(const Key('save-whole-spinner')));
      await tester.pumpAndSettle();
      expect(c.saved.single.slices.first, 'Die Hard');
      expect(find.byType(GentleNoteDialog), findsOneWidget);
      expect(find.textContaining('call or text 988'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dismiss-gentle-note')));
      await tester.pumpAndSettle();
      expect(find.byType(GentleNoteDialog), findsNothing);
      expect(find.byKey(const Key('home-page')), findsOneWidget);

      // Reopening, spinning, and spinning again never show the note.
      await tester.tap(find.text('Saved Spinners'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uncategorized'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Movie night'));
      await tester.pumpAndSettle();
      expect(find.byType(GentleNoteDialog), findsNothing);
      for (var i = 0; i < 2; i++) {
        await tester.tap(
          find.byKey(Key(i == 0 ? 'spin-button' : 'spin-again-button')),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.byType(GentleNoteDialog), findsNothing);
        await tester.tap(find.text('Receive the verdict'));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('edited save triggers again; ordinary save has no note', (
    tester,
  ) async {
    final c = await mount(
      tester,
      (c) => PreviewPage(controller: c, spinner: movie()),
    );
    for (var i = 0; i < 2; i++) {
      if (i > 0) {
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            theme: buildAppTheme(),
            home: PreviewPage(
              controller: c,
              spinner: movie().copyWith(title: 'Die Hard revised'),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byKey(const Key('save-whole-spinner')));
      await tester.tap(find.byKey(const Key('save-whole-spinner')));
      await tester.pumpAndSettle();
      expect(find.byType(GentleNoteDialog), findsOneWidget);
      await tester.tap(find.byKey(const Key('dismiss-gentle-note')));
      await tester.pumpAndSettle();
    }
    expect(c.saved, hasLength(1));
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: buildAppTheme(),
        home: PreviewPage(controller: c, spinner: spinnerTemplates.first),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-whole-spinner')));
    await tester.tap(find.byKey(const Key('save-whole-spinner')));
    await tester.pumpAndSettle();
    expect(find.byType(GentleNoteDialog), findsNothing);
    expect(find.text('Your wheel is among the stars!'), findsOneWidget);
  });

  testWidgets('failed save has no note and undo does not trigger one', (
    tester,
  ) async {
    final c = await mount(
      tester,
      (c) => PreviewPage(controller: c, spinner: movie()),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('cosmic_spinner/storage'),
          (call) async => throw PlatformException(code: 'WRITE'),
        );
    await tester.ensureVisible(find.byKey(const Key('save-whole-spinner')));
    await tester.tap(find.byKey(const Key('save-whole-spinner')));
    await tester.pumpAndSettle();
    expect(c.saveError, isNotNull);
    expect(find.byType(GentleNoteDialog), findsNothing);
    mockStorage();
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: buildAppTheme(),
        home: SavedPage(controller: c),
      ),
    );
    await tester.pumpAndSettle();
    final restore = c.restoreSpinner(movie());
    await tester.pumpAndSettle();
    expect(await restore, isTrue);
    expect(find.byType(GentleNoteDialog), findsNothing);
  });

  testWidgets('note scrolls with large text and Dismiss stays reachable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        home: Builder(
          builder: (context) => TextButton(
            child: const Text('Show'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: const GentleNoteDialog(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('dismiss-gentle-note')));
    await tester.pumpAndSettle();
    expect(find.byType(GentleNoteDialog), findsNothing);
  });
}
