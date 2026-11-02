import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unit_converter/conversion_engine.dart';
import 'package:unit_converter/main.dart';
import 'package:unit_converter/widgets/easter_eggs.dart';
import 'package:unit_converter/widgets/frog_widget.dart';
import 'package:unit_converter/widgets/dialog_queue.dart';

void main() {
  testWidgets('dialog queue deduplicates and preserves FIFO order', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const Scaffold();
          },
        ),
      ),
    );
    final dismissed = <String>[];
    for (final name in ['first', 'first', 'second']) {
      DialogQueue.instance.enqueue(
        context: context,
        dedupeKey: name,
        builder: (_) => CosmicDialog(title: name, message: 'Queue test'),
        onDismissed: () => dismissed.add(name),
      );
    }
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsNothing);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('second'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(dismissed, ['first', 'second']);
  });
  final cases = <(String, String, double, String)>[
    ('m', 'km', 42, '42'),
    ('g', 'ml', 13, '13'),
    ('planck_length', 'm', 1, 'PLANCK SCALE'),
    ('mps', 'kmh', 299792458, 'SPEED OF LIGHT'),
    ('kelvin', 'celsius', 0, 'ABSOLUTE ZERO'),
    ('celsius', 'kelvin', -273.15, 'ABSOLUTE ZERO'),
    ('g', 'ml', 1, 'WATER DENSITY'),
    ('B', 'b', 1024, 'DIGITAL STORAGE'),
    ('km', 'm', 3.085677581e13, 'PARSEC UNLOCK'),
    ('kelvin', 'celsius', 1e-13, 'HEAT DEATH'),
    ('kelvin', 'fahrenheit', 1e-13, 'HEAT DEATH'),
  ];
  for (final entry in cases) {
    testWidgets('conversion triggers ${entry.$4}: ${entry.$1}', (tester) async {
      final key = GlobalKey<FrogWidgetState>();
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                context = ctx;
                return FrogWidget(key: key, cosmicMode: false);
              },
            ),
          ),
        ),
      );
      final result = convertValue(
        entry.$3,
        canonicalizeUnit(entry.$1),
        canonicalizeUnit(entry.$2),
      );
      expect(result, isNotNull);
      expect(
        checkEasterEggs(
          context: context,
          frog: key.currentState,
          fromUnit: entry.$1,
          toUnit: entry.$2,
          inputValue: entry.$3,
          resultValue: result!,
        ),
        isTrue,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(entry.$4), findsOneWidget);
      if (entry.$4 == 'HEAT DEATH') {
        await tester.pump(const Duration(seconds: 5));
        expect(key.currentState!.heatDeathProgress, greaterThan(0.4));
        await tester.pump(const Duration(seconds: 6));
        expect(key.currentState!.heatDeathProgress, 1);
      }
      if (entry.$4 == 'SPEED OF LIGHT') {
        expect(key.currentState!.lightning, isTrue);
        expect(key.currentState!.lightningController.value, greaterThan(0));
      }
      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(key.currentState!.heatDeathProgress, 0);
      expect(key.currentState!.lightning, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  for (final size in [const Size(412, 915), const Size(915, 412)]) {
    testWidgets('safe layout and dialogs at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(
        top: 28,
        bottom: 24,
        left: 24,
      );
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const CosmicConverterApp());
      expect(
        tester.getRect(find.byType(FrogWidget)).top,
        greaterThanOrEqualTo(28),
      );
      final category = find.byType(DropdownButtonFormField<String>).first;
      await tester.tap(category);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(displayCategory('temperature')).last);
      await tester.pump(const Duration(milliseconds: 400));
      final frogRect = tester.getRect(find.byType(FrogWidget));
      final titleRect = tester.getRect(find.text('Cosmic Converter'));
      expect((frogRect.center.dy - titleRect.center.dy).abs(), lessThan(2));
      expect(
        frogRect.bottom,
        lessThan(tester.getRect(find.text('Category')).top),
      );
      expect(
        tester.getRect(find.text('COSMIC MODE')).bottom,
        lessThanOrEqualTo(size.height - 24),
      );
      await tester.tap(find.byTooltip('Turn Cosmic Mode on'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 16));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
