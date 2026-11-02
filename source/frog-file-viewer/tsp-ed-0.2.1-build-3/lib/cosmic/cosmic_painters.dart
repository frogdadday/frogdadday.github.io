import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'cosmic_motion.dart';

/// Full canvas living liquid. This is painted BEHIND real app controls.
/// No hit testing, input interception, transparent circles or modal overlay.
class CosmicScenePainter extends CustomPainter {
  CosmicScenePainter({
    required this.motion,
    required this.shader,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final CosmicMotion motion;
  final ui.FragmentShader? shader;

  static const colors = <Color>[
    Color(0xFFFF495E),
    Color(0xFFFFB22C),
    Color(0xFFFFE64D),
    Color(0xFF63E49A),
    Color(0xFF29CAE4),
    Color(0xFF7074F6),
    Color(0xFFBC58F3),
    Color(0xFFFC70C6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final liquid = shader;
    if (liquid != null) {
      liquid.setFloat(0, size.width);
      liquid.setFloat(1, size.height);
      liquid.setFloat(2, motion.seconds);
      liquid.setFloat(3, motion.heart);
      liquid.setFloat(4, 0.71);
      canvas.drawRect(rect, Paint()..shader = liquid);
    } else {
      // Calm fallback, not oversized overlapping circles.
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(size.width, size.height),
            const [
              Color(0xFF161126),
              Color(0xFF3E164B),
              Color(0xFF152F3F),
              Color(0xFF1C132E),
            ],
            const [0.0, 0.33, 0.66, 1.0],
          ),
      );
    }
  }



  @override
  bool shouldRepaint(covariant CosmicScenePainter oldDelegate) =>
      oldDelegate.shader != shader ||
      oldDelegate.motion != motion;
}

/// Deforms the app's EXISTING title, rather than substituting COSMIC MODE.
class CosmicTitlePainter extends CustomPainter {
  CosmicTitlePainter({
    required this.motion,
    required this.title,
    required Listenable repaint,
  }) : _glyphs = _buildGlyphs(title),
       super(repaint: repaint);

  final CosmicMotion motion;
  final String title;
  final List<TextPainter> _glyphs;

  /// A slow but clearly perceptible per-letter wave, twist, skew and breath.
  /// Kept as pure geometry so its amplitude can be regression-tested.
  static ({
    double dx,
    double dy,
    double rotation,
    double scaleX,
    double scaleY,
    double skewX,
  }) glyphPose(double seconds, int index) {
    final wave = math.sin(seconds * 0.43 + index * 0.58);
    final breathe = math.sin(seconds * 0.31 + index * 0.73 + 1.4);
    final twist = math.sin(seconds * 0.22 + index * 0.91);
    return (
      dx: 2.0 * twist,
      dy: 5.3 * wave,
      rotation: 0.095 * math.sin(seconds * 0.28 + index * 0.64),
      scaleX: 1.0 + 0.115 * breathe,
      scaleY: 1.0 - 0.13 * wave,
      skewX: 0.043 * math.sin(seconds * 0.24 + index * 0.79),
    );
  }

  static List<TextPainter> _buildGlyphs(String title) {
    return List<TextPainter>.generate(title.length, (i) {
      final color = CosmicScenePainter.colors[(i + 3) % 8];
      return TextPainter(
        text: TextSpan(
          text: title[i],
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 28,
            shadows: const [
              Shadow(
                color: Color(0x88100A20),
                offset: Offset(0, 1.2),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }, growable: false);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final width = _glyphs.fold<double>(
      0.0,
      (sum, glyph) => sum + glyph.width + 0.3,
    );
    final fit = math.min(1.0, (size.width - 4) / width);
    canvas.save();
    canvas.translate(
      (size.width - width * fit) / 2,
      (size.height - 32 * fit) / 2,
    );
    canvas.scale(fit);
    var x = 0.0;
    for (var i = 0; i < _glyphs.length; i++) {
      final glyph = _glyphs[i];
      final pose = glyphPose(motion.seconds, i);
      canvas.save();
      canvas.translate(
        x + glyph.width / 2 + pose.dx,
        pose.dy,
      );
      canvas.rotate(pose.rotation);
      canvas.skew(pose.skewX, 0);
      canvas.scale(pose.scaleX, pose.scaleY);
      glyph.paint(canvas, Offset(-glyph.width / 2, 0));
      canvas.restore();
      x += glyph.width + 0.3;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CosmicTitlePainter oldDelegate) =>
      oldDelegate.title != title || oldDelegate.motion != motion;
}
