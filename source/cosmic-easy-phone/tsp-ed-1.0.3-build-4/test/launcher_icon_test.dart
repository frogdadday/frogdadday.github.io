import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _decodePng(File file) async {
  final codec = await ui.instantiateImageCodec(await file.readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

void main() {
  test(
    'adaptive launcher artwork stays centered without transparent padding',
    () async {
      const densitySizes = <String, int>{
        'mdpi': 108,
        'hdpi': 162,
        'xhdpi': 216,
        'xxhdpi': 324,
        'xxxhdpi': 432,
      };

      for (final entry in densitySizes.entries) {
        final file = File(
          'android/app/src/main/res/drawable-${entry.key}/'
          'ic_launcher_foreground.png',
        );
        expect(
          file.existsSync(),
          isTrue,
          reason: '${entry.key} artwork is missing',
        );

        final image = await _decodePng(file);
        expect(image.width, entry.value);
        expect(image.height, entry.value);

        final pixels = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(pixels, isNotNull);

        var minX = image.width;
        var minY = image.height;
        var maxX = -1;
        var maxY = -1;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            final alpha = pixels!.getUint8((y * image.width + x) * 4 + 3);
            if (alpha <= 8) continue;
            minX = x < minX ? x : minX;
            minY = y < minY ? y : minY;
            maxX = x > maxX ? x : maxX;
            maxY = y > maxY ? y : maxY;
          }
        }

        final contentWidth = maxX - minX + 1;
        final contentHeight = maxY - minY + 1;
        expect(contentWidth / image.width, inInclusiveRange(0.72, 0.82));
        expect(contentHeight / image.height, inInclusiveRange(0.25, 0.38));
        expect((minX + maxX) / 2, closeTo((image.width - 1) / 2, 2));
        expect((minY + maxY) / 2, closeTo((image.height - 1) / 2, 2));
        image.dispose();
      }
    },
  );

  test('adaptive icon XML uses the corrected density artwork directly', () {
    for (final name in <String>['ic_launcher.xml', 'ic_launcher_round.xml']) {
      final contents = File(
        'android/app/src/main/res/mipmap-anydpi-v26/$name',
      ).readAsStringSync();
      expect(contents, contains('@drawable/ic_launcher_foreground'));
      expect(contents, isNot(contains('18dp')));
    }

    expect(
      File(
        'android/app/src/main/res/drawable/ic_launcher_foreground.xml',
      ).existsSync(),
      isFalse,
    );
  });
}
