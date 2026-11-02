import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/cosmic/cosmic_inline_stage.dart';
import 'package:frog_file_viewer/cosmic/cosmic_painters.dart';
import 'package:frog_file_viewer/cosmic/cosmic_foreground_frog_painter.dart';
import 'package:frog_file_viewer/main.dart';
import 'package:frog_file_viewer/widgets/tie_dye_frog.dart';

void main() {
  testWidgets('home offers real starter actions', (tester) async {
    await tester.pumpWidget(const FrogFileToolkit());
    expect(find.text('Open & edit PDF'), findsOneWidget);
    expect(find.text('View a file'), findsOneWidget);
    expect(find.text('Images to PDF'), findsOneWidget);
    expect(find.byType(TieDyeFrog), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Convert an image'),
      find.byType(ListView),
      const Offset(0, -220),
    );
    expect(find.text('Convert an image'), findsOneWidget);
  });

  testWidgets('one home mascot remains; the app-bar frog is removed', (
    tester,
  ) async {
    await tester.pumpWidget(const FrogFileToolkit());
    expect(tester.takeException(), isNull);
    expect(find.byType(TieDyeFrog), findsOneWidget);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.leading, isNull);
    expect(appBar.automaticallyImplyLeading, isFalse);
    expect(find.text('Frog File Viewer'), findsOneWidget);
  });

  testWidgets('cosmic mode is inline: tools remain and original title stays', (
    tester,
  ) async {
    await tester.pumpWidget(const FrogFileToolkit());
    await tester.dragUntilVisible(
      find.byKey(const Key('cosmic-mode-button')),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.ensureVisible(find.byKey(const Key('cosmic-mode-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cosmic-mode-button')));
    await tester.pump();
    expect(find.byType(CosmicInlineStage), findsOneWidget);
    // The only mascot is painted once in the foreground during Cosmic Mode;
    // the old redundant top-bar TieDyeFrog widget is gone entirely.
    expect(find.byType(TieDyeFrog), findsNothing);
    expect(tester.widget<AppBar>(find.byType(AppBar)).leading, isNull);
    expect(find.text('Cosmic Mode: On'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byWidgetPredicate(
      (widget) => widget is CustomPaint &&
          widget.painter is CosmicScenePainter,
    ), findsOneWidget);
    // The liquid background draws NO giant centered frog. The only animated
    // frog is the foreground layer anchored to the small original mascot.
    final foreground = find.byWidgetPredicate(
      (widget) => widget is CustomPaint &&
          widget.painter is CosmicForegroundFrogPainter,
    );
    expect(foreground, findsOneWidget);

    // Regression: the original title used to disappear because a childless
    // CustomPaint got zero width from the AppBar's loose constraints.
    expect(find.text('Frog File Viewer'), findsOneWidget);
    final morphingTitle = find.byWidgetPredicate(
      (widget) => widget is CustomPaint &&
          widget.painter is CosmicTitlePainter,
    );
    expect(morphingTitle, findsOneWidget);
    expect(tester.getSize(morphingTitle).width, greaterThan(120));
    expect(tester.getSize(morphingTitle).height, greaterThan(20));
    expect(find.text('Let it flow. The heart will find its own way.'), findsNothing);
    expect(find.text('COSMIC MODE'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('cosmic-reduced-motion')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cosmic-reduced-motion')));
    await tester.pump();
    expect(find.text('Resume effects'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('cosmic-mode-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cosmic-mode-button')));
    await tester.pump();
    expect(find.byType(CosmicInlineStage), findsNothing);
    expect(find.text('Frog File Viewer'), findsOneWidget);
    expect(find.text('Cosmic Mode'), findsOneWidget);
    expect(find.text('View a file'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home exposes the published privacy policy action', (
    tester,
  ) async {
    await tester.pumpWidget(const FrogFileToolkit());
    await tester.dragUntilVisible(
      find.byKey(const Key('privacy-policy-button')),
      find.byType(ListView),
      const Offset(0, -300),
    );

    expect(find.byKey(const Key('privacy-policy-button')), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
  });
}
