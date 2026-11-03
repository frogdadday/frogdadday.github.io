import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sean_johnston/screens/editor_page.dart';
import 'package:sean_johnston/screens/preview_page.dart';
import 'package:sean_johnston/screens/spinner_page.dart';
import 'package:sean_johnston/services/app_controller.dart';
import 'package:sean_johnston/models/spinner_model.dart';
import 'package:sean_johnston/theme/app_theme.dart';

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
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: page(c)));
    await tester.pumpAndSettle();
    addTearDown(c.dispose);
    return c;
  }

  testWidgets('backgrounding immediately flushes recent draft edits', (
    tester,
  ) async {
    final c = await mount(tester, (c) => EditorPage(controller: c));
    await tester.enterText(
      find.byKey(const Key('spinner-title-field')),
      'Latest draft',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(c.draft?.title, 'Latest draft');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'rapid preview taps open only one preview and discard stays discarded',
    (tester) async {
      final c = await mount(
        tester,
        (c) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => EditorPage(controller: c),
                ),
              ),
              child: const Text('Editor'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Editor'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('spinner-title-field')),
        'Title',
      );
      await tester.enterText(find.byKey(const Key('slice-field-0')), 'A');
      await tester.scrollUntilVisible(
        find.byKey(const Key('slice-field-1')),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byKey(const Key('slice-field-1')), 'B');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.scrollUntilVisible(
        find.byKey(const Key('commit-spinner')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final commit = tester
          .widget<FilledButton>(find.byKey(const Key('commit-spinner')))
          .onPressed!;
      commit();
      commit();
      await tester.pumpAndSettle();
      expect(find.byType(PreviewPage), findsOneWidget);
      await tester.tap(find.text('One Last Edit'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(c.draft, isNull);
    },
  );

  testWidgets('rapid saves write once and failure shows no success dialog', (
    tester,
  ) async {
    final c = await mount(
      tester,
      (c) => PreviewPage(controller: c, spinner: spinnerTemplates.first),
    );
    final gate = Completer<void>();
    int writes = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('cosmic_spinner/storage'),
          (call) async {
            writes++;
            await gate.future;
            throw PlatformException(code: 'WRITE');
          },
        );
    final save = find.byKey(const Key('save-whole-spinner'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.tap(save);
    await tester.pump();
    expect(writes, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(c.saveError, isNotNull);
    expect(find.text('Your wheel is among the stars!'), findsNothing);
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
  });

  testWidgets('disposing during a spin handles animation cancellation', (
    tester,
  ) async {
    await mount(
      tester,
      (c) => SpinnerPage(controller: c, spinner: spinnerTemplates.first),
    );
    await tester.tap(find.byKey(const Key('spin-button')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
