import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sean_johnston/models/spinner_model.dart';
import 'package:sean_johnston/screens/spinner_page.dart';
import 'package:sean_johnston/services/app_controller.dart';
import 'package:sean_johnston/theme/app_theme.dart';
import 'package:sean_johnston/widgets/spinner_wheel.dart';
import 'package:sean_johnston/widgets/yellow_frog.dart';

import 'storage_harness.dart';

void main() {
  setUp(mockStorage);
  testWidgets('stage frog follows the Cosmic toggle immediately', (
    tester,
  ) async {
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
    await tester.pumpAndSettle();
    expect(
      tester.widget<YellowFrog>(find.byType(YellowFrog)).cosmicMode,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('cosmic-toggle')));
    await tester.pump();
    expect(
      tester.widget<YellowFrog>(find.byType(YellowFrog)).cosmicMode,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('cosmic-toggle')));
    await tester.pump();
    expect(
      tester.widget<YellowFrog>(find.byType(YellowFrog)).cosmicMode,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('frog toe lands before the wheel starts turning', (tester) async {
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
    await tester.pumpAndSettle();
    await controller.toggleSound();
    await tester.tap(find.byKey(const Key('spin-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<SpinnerWheel>(find.byType(SpinnerWheel)).rotation, 0);
    expect(
      tester.widget<YellowFrog>(find.byType(YellowFrog)).kick,
      greaterThan(0),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.widget<SpinnerWheel>(find.byType(SpinnerWheel)).rotation, 0);
    await tester.pump(const Duration(milliseconds: 20));
    expect(
      tester.widget<SpinnerWheel>(find.byType(SpinnerWheel)).rotation,
      isNot(0),
    );
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  for (final count in [2, 6, 20]) {
    testWidgets(
      'extended foot identifies the winner for $count slices and respins',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = AppController();
        final spinner = SpinnerModel(
          id: 'test',
          title: 'Pointer test',
          slices: List.generate(count, (i) => 'Choice $i'),
          colorValue: 0xFF37A7FF,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: SpinnerPage(controller: controller, spinner: spinner),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<YellowFrog>(find.byType(YellowFrog)).kick, 0);
        for (var spin = 0; spin < 2; spin++) {
          await tester.tap(
            find.byKey(Key(spin == 0 ? 'spin-button' : 'spin-again-button')),
          );
          await tester.pump();
          expect(
            tester.widget<YellowFrog>(find.byType(YellowFrog)).kick,
            0,
            reason: 'Every spin starts with the kicking foot retracted.',
          );
          expect(find.byKey(const Key('persistent-result')), findsNothing);
          expect(
            tester.widget<SpinnerWheel>(find.byType(SpinnerWheel)).winningIndex,
            isNull,
          );
          await tester.pump(const Duration(milliseconds: 130));
          final midKick = tester
              .widget<YellowFrog>(find.byType(YellowFrog))
              .kick;
          expect(midKick, greaterThan(0));
          expect(midKick, lessThan(1));
          await tester.pump(const Duration(milliseconds: 870));
          expect(tester.widget<YellowFrog>(find.byType(YellowFrog)).kick, 1);
          await tester.pump(const Duration(seconds: 4));
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
          final wheel = tester.widget<SpinnerWheel>(find.byType(SpinnerWheel));
          final frog = tester.widget<YellowFrog>(find.byType(YellowFrog));
          expect(frog.kick, 1);
          expect(wheel.winningIndex, isNotNull);
          final rect = tester.getRect(find.byType(SpinnerWheel));
          final toe =
              tester.getTopLeft(find.byType(YellowFrog)) +
              YellowFrogPainter.extendedToe * frog.size;
          final delta = toe - rect.center;
          expect(delta.dx, greaterThan(0));
          expect(delta.dy, lessThan(0));
          expect(
            delta.distance,
            closeTo(rect.width * SpinnerWheelPainter.radiusFraction, 0.01),
          );
          final angle = math.atan2(delta.dy, delta.dx);
          final selected =
              ((angle - wheel.rotation + math.pi / 2) % (2 * math.pi)) /
              (2 * math.pi / count);
          expect(selected - selected.floor(), closeTo(0.5, 0.00001));
          expect(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text('Choice ${selected.floor()}'),
            ),
            findsOneWidget,
          );
          expect(wheel.winningIndex, selected.floor());
          await tester.tap(find.text('Receive the verdict'));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('persistent-result')), findsOneWidget);
          expect(
            tester
                .widget<Text>(find.byKey(const Key('persistent-result-text')))
                .data,
            'Choice ${selected.floor()}',
          );
          expect(tester.widget<YellowFrog>(find.byType(YellowFrog)).kick, 1);
        }
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
}
