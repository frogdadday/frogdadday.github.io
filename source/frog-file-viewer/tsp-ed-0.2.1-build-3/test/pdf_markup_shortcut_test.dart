import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/widgets/pdf_markup_shortcut.dart';

void main() {
  testWidgets('Markup is labeled and arms existing PDF annotation tools', (
    tester,
  ) async {
    PdfEditTool? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PdfMarkupShortcut(
            fingerDrawsInk: false,
            onChooseTool: (tool) => selected = tool,
            onFingerDrawChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Markup'), findsOneWidget);
    for (final entry in <(String, PdfEditTool)>[
      ('Pen / Draw', PdfEditTool.ink),
      ('Highlighter', PdfEditTool.highlight),
      ('Eraser', PdfEditTool.eraser),
      ('Text box', PdfEditTool.freeText),
      ('Select / Move', PdfEditTool.select),
    ]) {
      await tester.tap(find.byKey(const Key('pdf-markup-shortcut')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.$1));
      await tester.pumpAndSettle();
      expect(selected, entry.$2);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('finger drawing is a locally toggled accessible choice', (
    tester,
  ) async {
    bool? value;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PdfMarkupShortcut(
            fingerDrawsInk: false,
            onChooseTool: (_) {},
            onFingerDrawChanged: (changed) => value = changed,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Markup'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pdf-finger-drawing-choice')));
    await tester.pumpAndSettle();
    expect(value, isTrue);

    await tester.tap(find.text('Markup'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pdf-finger-drawing-choice')));
    await tester.pumpAndSettle();
    expect(value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact editor toolbar keeps Markup visible', (tester) async {
    final controller = PdfEditingController(Uint8List.fromList(_minimalPdf));
    final viewerController = PdfViewerController();
    addTearDown(controller.dispose);
    addTearDown(viewerController.dispose);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: PdfMarkupToolbar(
              controller: controller,
              viewerController: viewerController,
              imagePicker: (_) async => null,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('pdf-markup-shortcut-row')), findsOneWidget);
    expect(find.text('Markup'), findsOneWidget);
    expect(find.text('Insert Image'), findsOneWidget);
    expect(find.text('Tools'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Insert Image visibly arms the editor image tool', (
    tester,
  ) async {
    final controller = PdfEditingController(Uint8List.fromList(_minimalPdf));
    final viewerController = PdfViewerController();
    addTearDown(controller.dispose);
    addTearDown(viewerController.dispose);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: PdfMarkupToolbar(
              controller: controller,
              viewerController: viewerController,
              imagePicker: (_) async => null,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('pdf-insert-image')));
    await tester.pump();
    expect(controller.tool, PdfEditTool.image);
    expect(find.text('Insert Image'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Insert Image remains visible on landscape and wide layouts', (
    tester,
  ) async {
    final controller = PdfEditingController(Uint8List.fromList(_minimalPdf));
    final viewerController = PdfViewerController();
    addTearDown(controller.dispose);
    addTearDown(viewerController.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [Size(844, 390), Size(1200, 800)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(size: size),
              child: PdfMarkupToolbar(
                controller: controller,
                viewerController: viewerController,
                imagePicker: (_) async => null,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('pdf-markup-shortcut-row')),
        findsNothing,
        reason: '$size should use the wide toolbar',
      );
      expect(find.text('Insert Image'), findsOneWidget, reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });
}

const _minimalPdf = <int>[
  37,
  80,
  68,
  70,
  45,
  49,
  46,
  52,
  10,
  37,
  226,
  227,
  207,
  211,
  10,
  49,
  32,
  48,
  32,
  111,
  98,
  106,
  10,
  60,
  60,
  47,
  84,
  121,
  112,
  101,
  47,
  67,
  97,
  116,
  97,
  108,
  111,
  103,
  47,
  80,
  97,
  103,
  101,
  115,
  32,
  50,
  32,
  48,
  32,
  82,
  62,
  62,
  10,
  101,
  110,
  100,
  111,
  98,
  106,
  10,
  50,
  32,
  48,
  32,
  111,
  98,
  106,
  10,
  60,
  60,
  47,
  84,
  121,
  112,
  101,
  47,
  80,
  97,
  103,
  101,
  115,
  47,
  75,
  105,
  100,
  115,
  91,
  51,
  32,
  48,
  32,
  82,
  93,
  47,
  67,
  111,
  117,
  110,
  116,
  32,
  49,
  62,
  62,
  10,
  101,
  110,
  100,
  111,
  98,
  106,
  10,
  51,
  32,
  48,
  32,
  111,
  98,
  106,
  10,
  60,
  60,
  47,
  84,
  121,
  112,
  101,
  47,
  80,
  97,
  103,
  101,
  47,
  80,
  97,
  114,
  101,
  110,
  116,
  32,
  50,
  32,
  48,
  32,
  82,
  47,
  77,
  101,
  100,
  105,
  97,
  66,
  111,
  120,
  91,
  48,
  32,
  48,
  32,
  49,
  32,
  49,
  93,
  62,
  62,
  10,
  101,
  110,
  100,
  111,
  98,
  106,
  10,
  120,
  114,
  101,
  102,
  10,
  48,
  32,
  52,
  10,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  32,
  54,
  53,
  53,
  51,
  53,
  32,
  102,
  10,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  49,
  53,
  32,
  48,
  48,
  48,
  48,
  48,
  32,
  110,
  10,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  54,
  52,
  32,
  48,
  48,
  48,
  48,
  48,
  32,
  110,
  10,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  49,
  50,
  49,
  32,
  48,
  48,
  48,
  48,
  48,
  32,
  110,
  10,
  116,
  114,
  97,
  105,
  108,
  101,
  114,
  10,
  60,
  60,
  47,
  82,
  111,
  111,
  116,
  32,
  49,
  32,
  48,
  32,
  82,
  47,
  83,
  105,
  122,
  101,
  32,
  52,
  62,
  62,
  10,
  115,
  116,
  97,
  114,
  116,
  120,
  114,
  101,
  102,
  10,
  49,
  56,
  48,
  10,
  37,
  37,
  69,
  79,
  70,
  10,
];
