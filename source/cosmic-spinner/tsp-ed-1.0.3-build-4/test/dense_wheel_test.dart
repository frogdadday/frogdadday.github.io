import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sean_johnston/models/spinner_model.dart';
import 'package:sean_johnston/screens/spinner_page.dart';
import 'package:sean_johnston/services/app_controller.dart';
import 'package:sean_johnston/theme/app_theme.dart';

import 'storage_harness.dart';

void main() {
  setUp(mockStorage);
  setUpAll(() async {
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
  });
  for (final count in [12, 20]) {
    for (final largeText in [false, true]) {
      testWidgets(
        '$count crowded choices remain accessible with large text $largeText',
        (tester) async {
          await tester.binding.setSurfaceSize(
            largeText ? const Size(320, 640) : const Size(412, 915),
          );
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final controller = AppController();
          final labels = List.generate(
            count,
            (i) =>
                'Weekend activity ${i + 1}: take a walk through the neighborhood and stop for lunch with friends',
          );
          final spinner = spinnerTemplates.first.copyWith(
            title: 'Weekend activities',
            slices: labels,
          );
          await tester.pumpWidget(
            RepaintBoundary(
              key: const Key('capture'),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildAppTheme().copyWith(
                  textTheme: buildAppTheme().textTheme.apply(
                    fontFamily: 'Roboto',
                  ),
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(largeText ? 1.8 : 1),
                  ),
                  child: child!,
                ),
                home: SpinnerPage(controller: controller, spinner: spinner),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('CAPTURE_LAYOUT') && !largeText) {
            await expectLater(
              find.byKey(const Key('capture')),
              matchesGoldenFile('../build/review/dense-wheel-$count.png'),
            );
          }
          await tester.tap(find.byKey(const Key('view-choices')));
          await tester.pumpAndSettle();
          expect(find.text('All $count choices'), findsOneWidget);
          expect(find.text(labels.first), findsOneWidget);
          if (const bool.fromEnvironment('CAPTURE_LAYOUT') &&
              !largeText &&
              count == 20) {
            await expectLater(
              find.byKey(const Key('capture')),
              matchesGoldenFile('../build/review/dense-choices.png'),
            );
          }
          await tester.scrollUntilVisible(
            find.byKey(Key('choice-full-${count - 1}')),
            250,
            maxScrolls: 150,
            scrollable: find.descendant(
              of: find.byKey(const Key('choices-list')),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(labels.last), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('Close choices'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(const Key('spin-button')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('spin-button')));
          await tester.pump();
          expect(
            tester
                .widget<TextButton>(find.byKey(const Key('view-choices')))
                .onPressed,
            isNull,
          );
          await tester.pump(const Duration(seconds: 5));
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
          expect(find.text('The cosmos has spoken'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Receive the verdict'));
          await tester.tap(find.text('Receive the verdict'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
        },
      );
    }
  }
}
