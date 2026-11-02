import 'package:flutter/material.dart';

/// The shared frog-heart support icon used across Frog Dad Day apps.
class FrogHeartIcon extends StatelessWidget {
  const FrogHeartIcon({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: _FrogHeartPainter()),
  );
}

class _FrogHeartPainter extends CustomPainter {
  const _FrogHeartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final heart = Path()
      ..moveTo(w * 0.50, h * 0.96)
      ..cubicTo(w * 0.40, h * 0.82, w * 0.06, h * 0.62, w * 0.06, h * 0.30)
      ..cubicTo(w * 0.06, h * 0.08, w * 0.34, h * 0.01, w * 0.50, h * 0.24)
      ..cubicTo(w * 0.66, h * 0.01, w * 0.94, h * 0.08, w * 0.94, h * 0.30)
      ..cubicTo(w * 0.94, h * 0.62, w * 0.60, h * 0.82, w * 0.50, h * 0.96)
      ..close();
    canvas.drawPath(
      heart,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xffffdc45), Color(0xffff5cbf)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      heart,
      Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = const Color(0xff11131b);
    for (final x in [w * 0.30, w * 0.70]) {
      final eye = Offset(x, h * 0.25);
      canvas.drawCircle(eye, w * 0.105, eyePaint);
      canvas.drawCircle(eye, w * 0.047, pupilPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FrogHeartPainter oldDelegate) => false;
}
