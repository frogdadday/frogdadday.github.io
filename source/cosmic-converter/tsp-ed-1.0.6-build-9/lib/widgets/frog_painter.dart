// Spinner-style frog face, using Cosmic Converter's colors and reactions.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class FrogPainter extends CustomPainter {
  const FrogPainter({
    required this.eyesClosed,
    required this.winkLeft,
    required this.lightning,
    this.lightningProgress = 0,
    required this.cosmicMode,
    required this.reactionFlash,
    required this.isFrozen,
    required this.shimmerValue,
    required this.headTilt,
    required this.squishX,
    required this.squishY,
    required this.slowBlink,
  });

  final bool eyesClosed,
      winkLeft,
      lightning,
      cosmicMode,
      reactionFlash,
      isFrozen;
  final double lightningProgress,
      shimmerValue,
      headTilt,
      squishX,
      squishY,
      slowBlink;

  static const frogTeal = Color(0xFF6CCF5A);
  static const frozenBlue = Color(0xFF4AA8FF);
  static const cosmicA = Color(0xFFB060FF);
  static const cosmicB = Color(0xFFE040FF);
  static const cosmicC = Color(0xFF7A70FF);
  static const cosmicD = Color(0xFF60C0FF);
  static const _outline = Color(0xFF16212D);
  static final Paint _bodyFillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _outlinePaint = Paint()
    ..color = _outline
    ..style = PaintingStyle.stroke;
  static final Paint _eyeWhitePaint = Paint()..color = Colors.white;
  static final Paint _pupilPaint = Paint()..color = const Color(0xFF141414);
  static final Paint _smilePaint = Paint()
    ..color = const Color(0xFF243444)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _sparklePaint = Paint()..strokeCap = StrokeCap.round;
  static final Paint _lightningGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 7
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  static final Paint _lightningBoltPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.6
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  static final Paint _lightningCorePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = .9
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final body = _spinnerSilhouette(size);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(headTilt);
    canvas.scale(squishX, squishY);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawPath(body, _bodyPaint(size));
    _outlinePaint.strokeWidth = math.max(1.2, size.width * .026);
    canvas.drawPath(body, _outlinePaint);
    _drawEyes(canvas, size);
    _drawSmile(canvas, size);
    if (cosmicMode && !reactionFlash && !isFrozen) {
      _drawCosmicSparkles(canvas, size);
    }
    if (lightning) _drawLightning(canvas, size);
    canvas.restore();
  }

  Paint _bodyPaint(Size size) {
    final paint = _bodyFillPaint..shader = null;
    if (reactionFlash) {
      paint.color = Colors.yellowAccent.withValues(alpha: .85);
    } else if (isFrozen) {
      paint.color = frozenBlue;
    } else if (cosmicMode) {
      paint.shader = ui.Gradient.linear(
        Offset(-size.width + shimmerValue * size.width * 3, 0),
        Offset(size.width + shimmerValue * size.width * 3, size.height),
        const [cosmicA, cosmicB, cosmicC, cosmicD],
        const [0.0, .33, .66, 1.0],
        TileMode.mirror,
      );
    } else {
      paint.color = frogTeal;
    }
    return paint;
  }

  // The Spinner mascot's rounded head and raised eye bumps.
  Path _spinnerSilhouette(Size size) {
    final w = size.width;
    final h = size.height;
    final headTop = h * .25;
    final headBottom = h * .80;
    final eyeSize = w * .30;
    final eyeY = headTop - eyeSize * .20;
    return Path()
      ..moveTo(w * .10, headBottom)
      ..quadraticBezierTo(w * .50, headBottom + h * .15, w * .90, headBottom)
      ..lineTo(w * .90, headTop + h * .08)
      ..quadraticBezierTo(
        w * .50,
        headTop - h * .03,
        w * .10,
        headTop + h * .08,
      )
      ..close()
      ..addOval(
        Rect.fromCenter(
          center: Offset(w * .34, eyeY + eyeSize / 2),
          width: eyeSize,
          height: eyeSize,
        ),
      )
      ..addOval(
        Rect.fromCenter(
          center: Offset(w * .66, eyeY + eyeSize / 2),
          width: eyeSize,
          height: eyeSize,
        ),
      );
  }

  void _drawEyes(Canvas canvas, Size size) {
    final radius = size.width * .15;
    final y = size.height * .29;
    final baseBlink = math.max(slowBlink, eyesClosed ? 1.0 : 0.0);
    for (final (index, x) in <(int, double)>[
      (0, size.width * .34),
      (1, size.width * .66),
    ]) {
      final blink = index == 0 && winkLeft ? 1.0 : baseBlink;
      final eyeHeight = math.max(
        radius * .12,
        radius * 1.58 * (1 - blink * .92),
      );
      final pupilHeight = math.max(
        radius * .05,
        radius * .76 * (1 - blink * .96),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: radius * 1.58,
          height: eyeHeight,
        ),
        _eyeWhitePaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y + radius * .08),
          width: radius * .76,
          height: pupilHeight,
        ),
        _pupilPaint,
      );
      if (blink < .72) {
        canvas.drawCircle(
          Offset(x - radius * .13, y - radius * .10),
          radius * .10 * (1 - blink),
          _eyeWhitePaint,
        );
      }
    }
  }

  void _drawSmile(Canvas canvas, Size size) {
    final smile = Path()
      ..moveTo(size.width * .35, size.height * .55)
      ..quadraticBezierTo(
        size.width * .50,
        size.height * .67,
        size.width * .65,
        size.height * .55,
      );
    _smilePaint.strokeWidth = math.max(1.1, size.width * .025);
    canvas.drawPath(smile, _smilePaint);
  }

  void _drawCosmicSparkles(Canvas canvas, Size size) {
    final time = shimmerValue * math.pi * 2;
    for (var i = 0; i < 5; i++) {
      final flash = math
          .pow((math.sin(time * 3 + i * 1.9) + 1) / 2, 5)
          .toDouble();
      if (flash < .1) continue;
      final c = Offset(
        size.width * (.20 + (i * .14) % .60),
        size.height * (.24 + (i % 3) * .16),
      );
      final r = .7 + flash * size.width * .055;
      final paint = _sparklePaint
        ..color = Colors.white.withValues(alpha: flash)
        ..strokeWidth = .8 + flash
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), paint);
      canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), paint);
    }
  }

  void _drawLightning(Canvas canvas, Size size) {
    final t = lightningProgress;
    final alpha =
        (math.sin(t * math.pi) * 3).clamp(0.0, 1.0) *
        (.7 + .3 * math.pow(math.sin(t * math.pi * 3), 2));
    for (var side = 0; side < 2; side++) {
      final color = side == 0 ? const Color(0xFF64FFDA) : cosmicA;
      final x = side == 0 ? -size.width * .08 : size.width * 1.08;
      final direction = side == 0 ? -1.0 : 1.0;
      final bolt = Path()..moveTo(x, size.height * .02);
      for (var i = 1; i <= 6; i++) {
        final flutter = math.sin(t * math.pi * 4 + i * 1.7) * 1.5;
        bolt.lineTo(
          x + direction * (i.isOdd ? 6 : -2) + flutter,
          size.height * (.02 + i * .15),
        );
      }
      _lightningGlowPaint.color = color.withValues(alpha: alpha * .35);
      _lightningBoltPaint.color = color.withValues(alpha: alpha);
      _lightningCorePaint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawPath(bolt, _lightningGlowPaint);
      canvas.drawPath(bolt, _lightningBoltPaint);
      canvas.drawPath(bolt, _lightningCorePaint);
    }
  }

  @override
  bool shouldRepaint(covariant FrogPainter old) =>
      old.eyesClosed != eyesClosed ||
      old.winkLeft != winkLeft ||
      old.lightning != lightning ||
      old.lightningProgress != lightningProgress ||
      old.cosmicMode != cosmicMode ||
      old.reactionFlash != reactionFlash ||
      old.isFrozen != isFrozen ||
      old.shimmerValue != shimmerValue ||
      old.headTilt != headTilt ||
      old.squishX != squishX ||
      old.squishY != squishY ||
      old.slowBlink != slowBlink;
}
