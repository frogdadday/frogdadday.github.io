import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sean_johnston/models/spinner_model.dart';
import 'package:sean_johnston/screens/preview_page.dart';
import 'package:sean_johnston/services/app_controller.dart';
import 'package:sean_johnston/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cosmic_spinner/storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  String? raw;
  bool fail = false;
  setUp(() {
    raw = null;
    fail = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'read') return raw;
      if (fail) throw PlatformException(code: 'WRITE');
      raw = call.arguments as String;
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'unapproved draft never leaks through preference writes; old data survives',
    () async {
      final old = spinnerTemplates.first.copyWith(id: 'old');
      raw = jsonEncode({
        'saved': [old.toJson()],
        'draft': old.toJson(),
      });
      final c = AppController();
      await c.ready;
      await c.saveDraft(old.copyWith(title: 'Private new edit'));
      expect(
        await c.saveSpinner(old.copyWith(title: 'Unapproved save')),
        isFalse,
      );
      await c.toggleSound();
      expect(raw, isNot(contains('Private new edit')));
      expect(raw, isNot(contains('Unapproved save')));
      final restored = AppController();
      await restored.ready;
      expect(restored.localSavingAllowed, isFalse);
      expect(restored.draft!.title, old.title);
      expect(restored.saved.single.title, old.title);
      c.dispose();
      restored.dispose();
    },
  );

  testWidgets(
    'Not Now asks again; Allow saves and survives restart without another prompt',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var c = AppController();
      await c.ready;
      Future<void> mount() async {
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: PreviewPage(controller: c, spinner: spinnerTemplates.first),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> save() async {
        final button = find.byKey(const Key('save-whole-spinner'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await mount();
      for (var i = 0; i < 2; i++) {
        await save();
        expect(find.text('Save Your Spinners?'), findsOneWidget);
        await tester.tap(find.text('Not Now'));
        await tester.pumpAndSettle();
        expect(c.saved, isEmpty);
        expect(raw, isNull);
      }
      await save();
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();
      expect(c.saved, hasLength(1));
      expect(jsonDecode(raw!)['localSavingAllowed'], isTrue);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      c = AppController();
      await c.ready;
      await mount();
      await save();
      expect(find.text('Save Your Spinners?'), findsNothing);
      expect(find.text('Your wheel is among the stars!'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  test(
    'failed consent write is reported and not remembered after restart',
    () async {
      final c = AppController();
      await c.ready;
      fail = true;
      expect(await c.allowLocalSaving(), isFalse);
      expect(c.saveError, isNotNull);
      final restored = AppController();
      await restored.ready;
      expect(restored.localSavingAllowed, isFalse);
      fail = false;
      expect(await c.retrySave(), isTrue);
      expect(jsonDecode(raw!)['localSavingAllowed'], isTrue);
      c.dispose();
      restored.dispose();
    },
  );
}
