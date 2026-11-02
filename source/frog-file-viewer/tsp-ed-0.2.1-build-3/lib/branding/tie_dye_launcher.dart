import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Pixel-level recolor of the *exact* Cosmic Converter launcher image.
///
/// Only pixels identified as the original green frog pigment change RGB.
/// The silhouette, eyes, background, black outlines, dimensions, alpha and
/// existing antialiasing are preserved. No AI images or new geometry.
class TieDyeLauncher {
  const TieDyeLauncher._();

  static const List<(int, int, int)> _palette = [
    (245, 52, 75), // rose
    (255, 148, 38), // orange
    (250, 214, 58), // yellow
    (63, 201, 100), // green
    (43, 198, 224), // turquoise
    (73, 102, 224), // blue
    (158, 79, 213), // violet
    (234, 75, 161), // magenta
    (245, 52, 75),
  ];

  static Uint8List recolorPng(Uint8List originalPng) {
    final image = img.decodePng(originalPng);
    if (image == null) {
      throw const FormatException('The launcher source must be a PNG image.');
    }
    final width = image.width;
    final height = image.height;
    final centerX = width * 0.5;
    final centerY = height * 0.49;
    final scale = math.min(width, height).toDouble();

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final red = pixel.r.toDouble();
        final green = pixel.g.toDouble();
        final blue = pixel.b.toDouble();

        // Don't recolor the outlines, eyes, transparency or grey backdrop.
        if (pixel.a <= 0 ||
            green < 74 ||
            green <= red * 1.13 ||
            green <= blue * 1.18 ||
            green - red < 20) {
          continue;
        }

        // Angle twisted by distance gives a classical spiral tie-dye field.
        final dx = (x - centerX) / scale;
        final dy = (y - centerY) / scale;
        final radius = math.sqrt(dx * dx + dy * dy);
        final angle = math.atan2(dy, dx);
        var cycle = (angle + 12.0 * radius) / (2 * math.pi);
        cycle = cycle - cycle.floorToDouble();

        final position = cycle * (_palette.length - 1);
        final fromIndex = position.floor().clamp(0, _palette.length - 2);
        final fraction = position - fromIndex;
        final eased = fraction * fraction * (3 - 2 * fraction);
        final start = _palette[fromIndex];
        final end = _palette[fromIndex + 1];

        // Respect the source pixels' existing shading and edge texture.
        final shade = (0.78 + green / 255.0 * 0.22).clamp(0.0, 1.0);
        int blend(int first, int next) =>
            ((first + (next - first) * eased) * shade).round().clamp(0, 255);

        image.setPixelRgba(
          x,
          y,
          blend(start.$1, end.$1),
          blend(start.$2, end.$2),
          blend(start.$3, end.$3),
          pixel.a,
        );
      }
    }

    return Uint8List.fromList(img.encodePng(image));
  }
}
