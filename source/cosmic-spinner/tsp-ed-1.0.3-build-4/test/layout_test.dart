import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sean_johnston/models/spinner_model.dart';
import 'package:sean_johnston/screens/spinner_page.dart';
import 'package:sean_johnston/services/app_controller.dart';
import 'package:sean_johnston/theme/app_theme.dart';
import 'package:sean_johnston/widgets/spinner_wheel.dart';

import 'storage_harness.dart';

void main() {
  setUp(mockStorage);
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_LAYOUT')) {
      final loader = FontLoader('Roboto')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '.toolchain/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
              ).readAsBytesSync(),
            ),
          ),
        );
      await loader.load();
      final painterFont = FontLoader('Ahem')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '.toolchain/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
              ).readAsBytesSync(),
            ),
          ),
        );
      await painterFont.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '.toolchain/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
              ).readAsBytesSync(),
            ),
          ),
        );
      await icons.load();
    }
  });
  for (final size in [
    const Size(412, 915),
    const Size(320, 640),
    const Size(740, 360),
  ]) {
    testWidgets('wheel and controls fit $size with navigation inset', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = AppController();
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('layout-capture'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme().copyWith(
              textTheme: buildAppTheme().textTheme.apply(fontFamily: 'Roboto'),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(padding: const EdgeInsets.only(bottom: 24)),
              child: child!,
            ),
            home: SpinnerPage(
              controller: controller,
              spinner: spinnerTemplates.first,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final sound = tester.getRect(find.byKey(const Key('sound-toggle')));
      final cosmic = tester.getRect(find.byKey(const Key('cosmic-toggle')));
      expect(sound.center.dy, cosmic.center.dy);
      expect(sound.bottom, lessThanOrEqualTo(size.height - 24));
      final wheel = tester.getSize(find.byType(SpinnerWheel));
      if (size.width < size.height) {
        expect(wheel.width, greaterThan(size.width * 0.85));
      }
      if (const bool.fromEnvironment('CAPTURE_LAYOUT') && size.width == 412) {
        await expectLater(
          find.byKey(const Key('layout-capture')),
          matchesGoldenFile('../build/review/spinner-layout.png'),
        );
      }
      await tester.ensureVisible(find.byKey(const Key('spin-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('spin-button')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Receive the verdict'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('persistent-result')), findsOneWidget);
      if (const bool.fromEnvironment('CAPTURE_LAYOUT') && size.width == 412) {
        await expectLater(
          find.byKey(const Key('layout-capture')),
          matchesGoldenFile('../build/review/frog-pointer.png'),
        );
      }
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}
