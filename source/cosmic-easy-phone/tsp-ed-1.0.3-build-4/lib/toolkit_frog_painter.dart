import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Cosmic Spinner's newer frog shape, recolored for Frog Cleaner.
class ToolkitFrogPainter extends CustomPainter {
  ToolkitFrogPainter({
    required this.eyesClosed,
    required this.winkLeft,
    required this.lightning,
    required this.cosmicMode,
    required this.reactionFlash,
    required this.isFrozen,
    required this.shimmerValue,
    required this.headTilt,
    required this.squishX,
    required this.squishY,
    required this.slowBlink,
  });

  final bool eyesClosed;
  final bool winkLeft;
  final bool lightning;
  final bool cosmicMode;
  final bool reactionFlash;
  final bool isFrozen;
  final double shimmerValue;
  final double headTilt;
  final double squishX;
  final double squishY;
  final double slowBlink;

  static const frogRed = Color(0xff4b3020);
  static const frogReactionRed = Color(0xff674632);
  static const frozenBlue = Color(0xff4aa8ff);
  static const cosmicPink = Color(0xffff1687);
  static const outline = Color(0xff16212d);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width * 0.5, size.height * 0.5);
    canvas.rotate(headTilt);
    canvas.scale(squishX, squishY);
    canvas.translate(-size.width * 0.5, -size.height * 0.5);

    if (cosmicMode) _drawCosmicBeams(canvas, size);

    final body = _silhouette(size);
    final fill = Paint()..style = PaintingStyle.fill;
    if (reactionFlash) {
      fill.color = frogReactionRed;
    } else if (isFrozen) {
      fill.color = frozenBlue;
    } else if (cosmicMode) {
      fill.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Color(0xffff8fc8), cosmicPink, Color(0xff9d0c62)],
        stops: [0, 0.48 + 0.08 * math.sin(shimmerValue * math.pi * 2), 1],
      ).createShader(Offset.zero & size);
    } else {
      fill.shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff674632), frogRed, Color(0xff302016)],
      ).createShader(Offset.zero & size);
    }

    canvas.drawPath(body, fill);
    canvas.drawPath(
      body,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, size.width * 0.026),
    );
    _drawEyes(canvas, size);
    _drawSmile(canvas, size);
    if (cosmicMode) _drawSparkles(canvas, size);
    if (lightning) _drawLightning(canvas, size);
    canvas.restore();
  }

  Path _silhouette(Size size) {
    final w = size.width;
    final h = size.height;
    final headTop = h * 0.25;
    final headBottom = h * 0.80;
    final eyeSize = w * 0.30;
    final eyeY = headTop - eyeSize * 0.20;
    return Path()
      ..moveTo(w * 0.10, headBottom)
      ..quadraticBezierTo(w * 0.50, headBottom + h * 0.15, w * 0.90, headBottom)
      ..lineTo(w * 0.90, headTop + h * 0.08)
      ..quadraticBezierTo(
        w * 0.50,
        headTop - h * 0.03,
        w * 0.10,
        headTop + h * 0.08,
      )
      ..close()
      ..addOval(
        Rect.fromCenter(
          center: Offset(w * 0.34, eyeY + eyeSize / 2),
          width: eyeSize,
          height: eyeSize,
        ),
      )
      ..addOval(
        Rect.fromCenter(
          center: Offset(w * 0.66, eyeY + eyeSize / 2),
          width: eyeSize,
          height: eyeSize,
        ),
      );
  }

  void _drawEyes(Canvas canvas, Size size) {
    final w = size.width;
    final eyeRadius = w * 0.15;
    final y = size.height * 0.29;
    final blink = (eyesClosed ? 1.0 : slowBlink).clamp(0.0, 1.0);
    final white = Paint()..color = Colors.white;
    final dark = Paint()
      ..color = const Color(0xff141414)
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 2; index++) {
      final x = index == 0 ? w * 0.34 : w * 0.66;
      if (cosmicMode) {
        canvas.save();
        canvas.translate(x, y);
        canvas.scale(1, 1 - blink * 0.92);
        _drawHeart(canvas, Offset.zero, eyeRadius * 0.98);
        canvas.restore();
        continue;
      }
      final closed = blink > 0.78 || winkLeft && index == 0;
      if (closed) {
        canvas.drawLine(
          Offset(x - eyeRadius * 0.48, y),
          Offset(x + eyeRadius * 0.48, y),
          dark..strokeWidth = math.max(1.3, w * 0.025),
        );
        continue;
      }
      final eyeHeight = eyeRadius * 1.58 * (1 - blink * 0.72);
      final eye = Rect.fromCenter(
        center: Offset(x, y),
        width: eyeRadius * 1.58,
        height: eyeHeight,
      );
      canvas.drawOval(eye, white);
      canvas.drawCircle(
        Offset(x, y + eyeRadius * 0.08),
        eyeRadius * 0.38,
        dark,
      );
      canvas.drawCircle(
        Offset(x - eyeRadius * 0.13, y - eyeRadius * 0.10),
        eyeRadius * 0.10,
        white,
      );
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double radius) {
    final heart = Path()
      ..moveTo(center.dx, center.dy + radius * 0.82)
      ..cubicTo(
        center.dx - radius * 1.35,
        center.dy + radius * 0.05,
        center.dx - radius * 0.9,
        center.dy - radius * 1.05,
        center.dx,
        center.dy - radius * 0.38,
      )
      ..cubicTo(
        center.dx + radius * 0.9,
        center.dy - radius * 1.05,
        center.dx + radius * 1.35,
        center.dy + radius * 0.05,
        center.dx,
        center.dy + radius * 0.82,
      )
      ..close();
    canvas.drawPath(heart, Paint()..color = const Color(0xffffb4dd));
    canvas.drawPath(
      heart,
      Paint()
        ..color = const Color(0xff76003f)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.1, radius * 0.17),
    );
  }

  void _drawSmile(Canvas canvas, Size size) {
    final smile = Path()
      ..moveTo(size.width * 0.35, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.67,
        size.width * 0.65,
        size.height * 0.55,
      );
    canvas.drawPath(
      smile,
      Paint()
        ..color = const Color(0xff243444)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.2, size.width * 0.025),
    );
  }

  void _drawCosmicBeams(Canvas canvas, Size size) {
    final pulse = 0.72 + 0.28 * math.sin(shimmerValue * math.pi * 2);
    final origins = [
      Offset(size.width * 0.18, size.height * 0.49),
      Offset(size.width * 0.50, size.height * 0.37),
      Offset(size.width * 0.82, size.height * 0.49),
    ];
    final directions = const [
      Offset(-1, -0.42),
      Offset(0, -1),
      Offset(1, -0.42),
    ];
    final glow = Paint()
      ..color = cosmicPink.withValues(alpha: 0.24 * pulse)
      ..strokeWidth = math.max(2.5, size.width * 0.04)
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final beam = Paint()
      ..color = const Color(0xffffb2dc).withValues(alpha: 0.96)
      ..strokeWidth = math.max(0.9, size.width * 0.012)
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < origins.length; index++) {
      final length = size.width * (0.14 + 0.035 * pulse);
      final end = origins[index] + directions[index] * length;
      canvas.drawLine(origins[index], end, glow);
      canvas.drawLine(origins[index], end, beam);
    }
  }

  void _drawSparkles(Canvas canvas, Size size) {
    final time = shimmerValue * math.pi * 2;
    for (var index = 0; index < 6; index++) {
      final flash = math
          .pow((math.sin(time * 3 + index * 1.9) + 1) / 2, 5)
          .toDouble();
      if (flash < 0.08) continue;
      final center = Offset(
        size.width * (0.18 + (index * 0.14) % 0.62),
        size.height * (0.18 + (index % 3) * 0.22),
      );
      final radius = 1 + flash * size.width * 0.06;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: flash)
        ..strokeWidth = 1 + flash
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center.translate(-radius, 0),
        center.translate(radius, 0),
        paint,
      );
      canvas.drawLine(
        center.translate(0, -radius),
        center.translate(0, radius),
        paint,
      );
    }
  }

  void _drawLightning(Canvas canvas, Size size) {
    final bolt = Path()
      ..moveTo(size.width * 0.25, 0)
      ..lineTo(size.width * 0.42, size.height * 0.22)
      ..lineTo(size.width * 0.33, size.height * 0.22)
      ..lineTo(size.width * 0.55, size.height * 0.55)
      ..lineTo(size.width * 0.48, size.height * 0.32)
      ..lineTo(size.width * 0.72, size.height * 0.32)
      ..lineTo(size.width * 0.60, size.height * 0.60)
      ..lineTo(size.width * 0.80, size.height * 0.60);
    canvas.drawPath(
      bolt,
      Paint()
        ..color = cosmicMode ? cosmicPink : const Color(0xffb060ff)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant ToolkitFrogPainter oldDelegate) =>
      oldDelegate.eyesClosed != eyesClosed ||
      oldDelegate.winkLeft != winkLeft ||
      oldDelegate.lightning != lightning ||
      oldDelegate.cosmicMode != cosmicMode ||
      oldDelegate.reactionFlash != reactionFlash ||
      oldDelegate.isFrozen != isFrozen ||
      oldDelegate.shimmerValue != shimmerValue ||
      oldDelegate.headTilt != headTilt ||
      oldDelegate.squishX != squishX ||
      oldDelegate.squishY != squishY ||
      oldDelegate.slowBlink != slowBlink;
}
