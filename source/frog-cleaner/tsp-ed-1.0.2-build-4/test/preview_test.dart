import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frog_cleaner/main.dart';
import 'package:frog_cleaner/storage.dart';

void main() {
  testWidgets(
    'Render phone preview with explicitly mocked storage',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final fontPath = const String.fromEnvironment('PREVIEW_FONT');
      if (fontPath.isNotEmpty) {
        final font = FontLoader('Roboto')
          ..addFont(
            Future.value(
              ByteData.sublistView(File(fontPath).readAsBytesSync()),
            ),
          );
        await font.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  '${File(fontPath).parent.path}/materialicons-regular.otf',
                ).readAsBytesSync(),
              ),
            ),
          );
        await icons.load();
      }
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            StorageBridge.channel,
            (call) async => {
              'total': 128000000000,
              'free': 42000000000,
              'roots': [],
              'ignored': [],
            },
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(StorageBridge.channel, null),
      );
      const key = Key('preview');
      await tester.pumpWidget(
        const RepaintBoundary(key: key, child: FrogCleaner()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File('build/previews/home.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(find.byTooltip('Turn Cosmic Mode on'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File('build/previews/cosmic_home.png');
        await output.writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
    },
    skip: !const bool.fromEnvironment('CAPTURE_PREVIEW'),
  );
}
