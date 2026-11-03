// /////Block One/////////////////////////////////////////////////////////////
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'orange_frog.dart';

class FrogSpaceship extends StatelessWidget {
  const FrogSpaceship({super.key, this.width = 76});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Friendly orange frog flying a spaceship',
      child: SizedBox(
        width: width,
        height: width * 0.66,
        child: CustomPaint(painter: const _FrogSpaceshipPainter()),
      ),
    );
  }
}

// /////Block Two/////////////////////////////////////////////////////////////
class _FrogSpaceshipPainter extends CustomPainter {
  const _FrogSpaceshipPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = const Color(0xFF101A2D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * 0.018);

    final flame = Path()
      ..moveTo(w * 0.16, h * 0.69)
      ..quadraticBezierTo(w * 0.02, h * 0.80, w * 0.15, h * 0.89)
      ..quadraticBezierTo(w * 0.09, h * 0.96, w * 0.28, h * 0.78)
      ..close();
    canvas.drawPath(
      flame,
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[Color(0xFFFFF176), Color(0xFFFF6D00)],
        ).createShader(Offset.zero & size),
    );

    final saucer = Path()
      ..moveTo(w * 0.08, h * 0.62)
      ..quadraticBezierTo(w * 0.50, h * 0.42, w * 0.92, h * 0.62)
      ..quadraticBezierTo(w * 0.80, h * 0.90, w * 0.50, h * 0.92)
      ..quadraticBezierTo(w * 0.20, h * 0.90, w * 0.08, h * 0.62)
      ..close();
    canvas.drawPath(
      saucer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFD7E2ED), Color(0xFF6E7F93)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(saucer, stroke);

    final cockpit = Rect.fromCenter(
      center: Offset(w * 0.52, h * 0.48),
      width: w * 0.48,
      height: h * 0.63,
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(cockpit));
    canvas.translate(w * 0.33, h * 0.20);
    canvas.scale((w * 0.38) / 100, (h * 0.55) / 100);
    const OrangeFrogPainter().paint(canvas, const Size(100, 100));
    canvas.restore();

    canvas.drawOval(
      cockpit,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFFB7E8FF).withValues(alpha: 0.42),
            const Color(0xFF4FA9D8).withValues(alpha: 0.12),
          ],
        ).createShader(cockpit),
    );
    canvas.drawOval(
      cockpit,
      Paint()
        ..color = const Color(0xFFBDEBFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.1, w * 0.017),
    );

    for (final x in <double>[0.28, 0.50, 0.72]) {
      canvas.drawCircle(
        Offset(w * x, h * 0.78),
        w * 0.035,
        Paint()..color = const Color(0xFFFFD54F),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
