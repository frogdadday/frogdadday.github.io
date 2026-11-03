import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sean_johnston/models/spinner_model.dart';
import 'package:sean_johnston/screens/editor_page.dart';
import 'package:sean_johnston/services/app_controller.dart';
import 'package:sean_johnston/theme/app_theme.dart';

import 'storage_harness.dart';

void main() {
  setUp(mockStorage);

  test('SpinnerModel owns both original and replacement slice lists', () {
    final source = <String>['One', 'Two'];
    final original = SpinnerModel(
      id: 'original',
      title: 'Original',
      slices: source,
      colorValue: spinnerPalette.first.toARGB32(),
    );
    source[0] = 'Changed outside';
    expect(original.slices, <String>['One', 'Two']);

    final replacement = <String>['Red', 'Blue'];
    final copied = original.copyWith(slices: replacement);
    replacement[0] = 'Changed outside again';
    expect(copied.slices, <String>['Red', 'Blue']);
    expect(() => copied.slices[0] = 'Mutation', throwsUnsupportedError);
  });

  testWidgets(
    'slice controllers survive repeated add, edit, and remove cycles',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = AppController();
      addTearDown(controller.dispose);
      await controller.ready;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: EditorPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      for (var cycle = 0; cycle < 3; cycle++) {
        await tester.scrollUntilVisible(
          find.text('Add'),
          -160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Add'));
        await tester.pump();
        await tester.scrollUntilVisible(
          find.byKey(const Key('slice-field-2')),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byKey(const Key('slice-field-2')), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('slice-field-2')),
          'Temporary $cycle',
        );
        await tester.scrollUntilVisible(
          find.text('Remove'),
          -160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove slices'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('slice-field-2')), findsNothing);
        expect(tester.takeException(), isNull);
      }

      await tester.enterText(
        find.byKey(const Key('slice-field-1')),
        'Still live',
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.draft?.slices[1], 'Still live');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editor back navigation cancels or pops exactly once', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await controller.ready;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => EditorPage(controller: controller),
                ),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('spinner-title-field')),
      'Unsaved',
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Leave this spinner?'), findsOneWidget);
    await tester.tap(find.text('Continue editing'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorPage), findsNothing);
    expect(find.text('Open editor'), findsOneWidget);

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(EditorPage), findsNothing);

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('spinner-title-field')),
      'Keep this draft',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save draft & leave'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorPage), findsNothing);
    expect(controller.draft?.title, 'Keep this draft');
    expect(tester.takeException(), isNull);
  });

  testWidgets('classic colors expose human-readable semantics labels', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await controller.ready;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: EditorPage(
          controller: controller,
          initial: spinnerTemplates.first.copyWith(
            isTemplate: false,
            scheme: WheelScheme.classic,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('classic-color-0')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Red'), findsOneWidget);
    expect(find.bySemanticsLabel('Blue'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^\d+$')), findsNothing);
    handle.dispose();
  });
}
