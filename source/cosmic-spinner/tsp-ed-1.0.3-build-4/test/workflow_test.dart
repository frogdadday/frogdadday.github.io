import 'storage_harness.dart';

// ////Block One////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sean_johnston/main.dart';
import 'package:sean_johnston/models/spinner_model.dart';
import 'package:sean_johnston/screens/spinner_page.dart';
import 'package:sean_johnston/services/app_controller.dart';
import 'package:sean_johnston/theme/app_theme.dart';

void main() {
  setUp(mockStorage);
  testWidgets('a user can create, preview, save, and recall a spinner', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const SeanJohnstonApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Your Own'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('spinner-title-field')),
      'Dinner Test',
    );
    await tester.enterText(
      find.byKey(const Key('spinner-category-field')),
      'Food',
    );
    await tester.enterText(find.byKey(const Key('slice-field-0')), 'Pizza');
    await tester.scrollUntilVisible(
      find.byKey(const Key('slice-field-1')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byKey(const Key('slice-field-1')), 'Tacos');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('commit-spinner')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('commit-spinner')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('One last look before it becomes official.'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .join(' | '),
    );
    await tester.ensureVisible(find.byKey(const Key('save-whole-spinner')));
    await tester.tap(find.byKey(const Key('save-whole-spinner')));
    await tester.pumpAndSettle();
    expect(find.text('Your wheel is among the stars!'), findsOneWidget);
    await tester.tap(find.text('Back home'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved Spinners'));
    await tester.pumpAndSettle();
    expect(find.text('Food'), findsOneWidget);
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(find.text('Dinner Test'), findsOneWidget);
  });

  testWidgets('a four-second decision reveals the two session choices', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SpinnerPage(
          controller: controller,
          spinner: spinnerTemplates.first,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('spin-button')));
    await tester.pump();
    expect(find.text('The universe is deciding…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4, milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(
      find.text('The cosmos has spoken'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .join(' | '),
    );
    await tester.tap(find.text('Receive the verdict'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('spin-again-button')), findsOneWidget);
    expect(find.byKey(const Key('finish-button')), findsOneWidget);
    controller.dispose();
  });
}
