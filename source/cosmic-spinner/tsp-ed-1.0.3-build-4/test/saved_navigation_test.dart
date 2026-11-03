import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sean_johnston/models/spinner_model.dart';
import 'package:sean_johnston/screens/editor_page.dart';
import 'package:sean_johnston/screens/saved_page.dart';
import 'package:sean_johnston/screens/spinner_page.dart';
import 'package:sean_johnston/services/app_controller.dart';
import 'package:sean_johnston/theme/app_theme.dart';

import 'storage_harness.dart';

void main() {
  setUp(mockStorage);
  for (final edit in [false, true]) {
    testWidgets(
      edit
          ? 'options Edit opens the saved wheel for editing'
          : 'saved wheel opens immediately and repeated taps push once',
      (tester) async {
        final c = AppController();
        await c.ready;
        final spinner = spinnerTemplates.first.copyWith(
          id: 'saved-test',
          isTemplate: false,
        );
        await c.saveSpinner(spinner);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: SavedPage(controller: c),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Uncategorized'));
        await tester.pumpAndSettle();
        if (edit) {
          await tester.tap(find.byTooltip('Spinner options'));
          await tester.pumpAndSettle();
          expect(find.text('Delete'), findsOneWidget);
          await tester.tap(find.text('Edit'));
        } else {
          final tile = tester.widget<ListTile>(
            find.widgetWithText(ListTile, spinner.title),
          );
          tile.onTap!();
          tile.onTap!();
        }
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        if (edit) {
          final page = tester.widget<EditorPage>(find.byType(EditorPage));
          expect(page.initial!.id, spinner.id);
          expect(page.initial!.scheme, spinner.scheme);
          expect(page.initial!.slices, spinner.slices);
          expect(
            tester
                .widget<TextField>(find.byKey(const Key('spinner-title-field')))
                .controller!
                .text,
            spinner.title,
          );
        } else {
          expect(find.byType(SpinnerPage, skipOffstage: false), findsOneWidget);
          expect(find.byKey(const Key('spin-button')), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      },
    );
  }
}
