import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sean_johnston/models/spinner_model.dart';
import 'package:sean_johnston/screens/editor_page.dart';
import 'package:sean_johnston/screens/saved_page.dart';
import 'package:sean_johnston/services/app_controller.dart';
import 'package:sean_johnston/theme/app_theme.dart';
import 'package:sean_johnston/widgets/spinner_wheel.dart';

import 'storage_harness.dart';

void main() {
  setUp(mockStorage);
  test('older saves keep Classic; unknown palettes safely fall back', () {
    final json = spinnerTemplates.first.toJson()..remove('scheme');
    final old = SpinnerModel.fromJson(json);
    expect(old.scheme, WheelScheme.classic);
    expect(old.colorValue, spinnerTemplates.first.colorValue);
    expect(
      SpinnerModel.fromJson({...json, 'scheme': 'future'}).scheme,
      WheelScheme.classic,
    );
    for (final scheme in WheelScheme.values) {
      final model = old.copyWith(scheme: scheme);
      expect(SpinnerModel.fromJson(model.toJson()).scheme, scheme);
      for (var count = 2; count <= 20; count++) {
        final wheel = model.copyWith(slices: List.filled(count, 'Choice'));
        for (var i = 0; i < count; i++) {
          final a = wheel.sliceColor(i).computeLuminance();
          final b = wheel.sliceTextColor(i).computeLuminance();
          final ratio = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
          expect(ratio, greaterThanOrEqualTo(4.5));
          if (scheme != WheelScheme.classic) {
            expect(
              wheel.sliceColor(i),
              isNot(wheel.sliceColor((i + 1) % count)),
            );
          }
        }
      }
    }
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'palette selection previews and survives draft and save at text scale $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 740));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = AppController();
        await controller.ready;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: EditorPage(
              controller: controller,
              initial: spinnerTemplates.first.copyWith(isTemplate: false),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('scheme-ocean')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('scheme-ocean')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('scheme-preview')));
        expect(
          tester
              .widget<SpinnerWheel>(find.byKey(const Key('scheme-preview')))
              .spinner
              .scheme,
          WheelScheme.ocean,
        );
        expect(controller.draft!.scheme, WheelScheme.ocean);
        await tester.ensureVisible(find.byKey(const Key('scheme-classic')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('scheme-classic')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('classic-color-5')),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('classic-color-5')));
        await tester.pumpAndSettle();
        expect(controller.draft!.colorValue, spinnerPalette[5].toARGB32());
        await tester.ensureVisible(find.byKey(const Key('scheme-ocean')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('scheme-ocean')));
        await tester.pumpAndSettle();
        await controller.saveSpinner(controller.draft!);
        final restored = AppController();
        await restored.ready;
        expect(restored.saved.single.scheme, WheelScheme.ocean);
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            theme: buildAppTheme(),
            home: SavedPage(controller: restored),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Uncategorized'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<SpinnerWheel>(find.byType(SpinnerWheel)).spinner.scheme,
          WheelScheme.ocean,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        restored.dispose();
      },
    );
  }

  testWidgets('palette editor and saved list visual review', (tester) async {
    if (!const bool.fromEnvironment('CAPTURE_LAYOUT')) return;
    for (final font in ['Roboto', 'MaterialIcons']) {
      final file = font == 'Roboto'
          ? 'roboto-regular.ttf'
          : 'materialicons-regular.otf';
      await (FontLoader(font)..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  '.toolchain/flutter/bin/cache/artifacts/material_fonts/$file',
                ).readAsBytesSync(),
              ),
            ),
          ))
          .load();
    }
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController();
    await controller.ready;
    final theme = buildAppTheme().copyWith(
      textTheme: buildAppTheme().textTheme.apply(fontFamily: 'Roboto'),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('capture'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: EditorPage(
            controller: controller,
            initial: spinnerTemplates.first,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('scheme-preview')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('../build/review/palette-editor.png'),
    );
    for (final template in spinnerTemplates) {
      await controller.saveSpinner(template);
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('capture'),
        child: MaterialApp(
          key: UniqueKey(),
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: SavedPage(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('../build/review/palette-saved.png'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
