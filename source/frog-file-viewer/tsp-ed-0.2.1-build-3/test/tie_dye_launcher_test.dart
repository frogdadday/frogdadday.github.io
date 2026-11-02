import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:frog_file_viewer/branding/tie_dye_launcher.dart';

void main() {
  test('tie-dye launcher preserves transparent, dark, and grey pixels', () {
    final input = img.Image(width: 8, height: 8, numChannels: 4);
    img.fill(input, color: img.ColorRgba8(0, 0, 0, 0));
    input.setPixelRgba(0, 0, 0, 0, 0, 255);
    input.setPixelRgba(1, 1, 128, 128, 128, 255);
    input.setPixelRgba(3, 4, 138, 207, 39, 255);
    input.setPixelRgba(4, 4, 138, 207, 39, 255);
    final source = Uint8List.fromList(img.encodePng(input));
    final changed = img.decodePng(TieDyeLauncher.recolorPng(source))!;
    expect(changed.width, input.width);
    expect(changed.height, input.height);
    for (final pair in [(0, 0), (1, 1), (2, 2)]) {
      final old = input.getPixel(pair.$1, pair.$2);
      final now = changed.getPixel(pair.$1, pair.$2);
      expect(now.r, old.r);
      expect(now.g, old.g);
      expect(now.b, old.b);
      expect(now.a, old.a);
    }
    final oldGreen = input.getPixel(3, 4);
    final newGreen = changed.getPixel(3, 4);
    expect(
      (oldGreen.r != newGreen.r ||
          oldGreen.g != newGreen.g ||
          oldGreen.b != newGreen.b),
      isTrue,
    );
  });

  test('recolors original Converter image without changing its silhouette', () {
    final file = File(
      'assets/branding/source/converter_play_store_icon_512.png',
    );
    expect(file.existsSync(), isTrue);
    final original = img.decodePng(file.readAsBytesSync())!;
    final changed = img.decodePng(
      TieDyeLauncher.recolorPng(file.readAsBytesSync()),
    )!;
    expect(changed.width, original.width);
    expect(changed.height, original.height);

    var recoloredPixels = 0;
    for (var y = 0; y < original.height; y += 2) {
      for (var x = 0; x < original.width; x += 2) {
        final a = original.getPixel(x, y);
        final b = changed.getPixel(x, y);
        expect(a.a, b.a);
        if (a.r != b.r || a.g != b.g || a.b != b.b) {
          recoloredPixels++;
          expect(a.g > a.r * 1.13, isTrue);
          expect(a.g > a.b * 1.18, isTrue);
        }
      }
    }
    expect(recoloredPixels, greaterThan(2000));
  });
}
