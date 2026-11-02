import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unit_converter/main.dart';
import 'package:unit_converter/widgets/cosmic_rainbow_title.dart';
import 'package:unit_converter/widgets/frog_heart_button.dart';

void main() {
  testWidgets('shows the Cosmic Converter controls', (tester) async {
    await tester.pumpWidget(const CosmicConverterApp());

    expect(find.text('Cosmic Converter'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('How Much Do You Have?'), findsOneWidget);
    expect(find.text('COSMIC MODE'), findsOneWidget);
    expect(find.text('PRIVACY POLICY'), findsOneWidget);
    expect(find.text('SEND ME A COFFEE'), findsOneWidget);

    final heartButtonSize = tester.getSize(find.byType(FrogHeartButton));
    expect(heartButtonSize.width, greaterThanOrEqualTo(48));
    expect(heartButtonSize.height, greaterThanOrEqualTo(48));

    CosmicRainbowTitle title = tester.widget(find.byType(CosmicRainbowTitle));
    expect(title.enabled, isFalse);

    await tester.tap(find.byTooltip('Turn Cosmic Mode on'));
    await tester.pump(const Duration(milliseconds: 400));
    title = tester.widget(find.byType(CosmicRainbowTitle));
    expect(title.enabled, isTrue);

    await tester.tap(find.byTooltip('Turn Cosmic Mode off'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Turn Cosmic Mode on'));
    await tester.pump(const Duration(milliseconds: 400));
    title = tester.widget(find.byType(CosmicRainbowTitle));
    expect(title.enabled, isTrue);

    // Dispose stateful widgets and their idle timers before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
