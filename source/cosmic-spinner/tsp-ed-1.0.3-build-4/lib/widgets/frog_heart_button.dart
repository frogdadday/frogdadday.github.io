// ////Block One//////////////////////////////////////////////////////////////
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'labeled_icon_button.dart';

class FrogHeartButton extends StatelessWidget {
  const FrogHeartButton({super.key});

  static const MethodChannel _channel = MethodChannel('cosmic_spinner/link');

  Future<void> _open(BuildContext context) async {
    try {
      final opened =
          await _channel
              .invokeMethod<bool>('openSupport')
              .timeout(const Duration(seconds: 2)) ??
          false;
      if (!opened && context.mounted) _showError(context);
    } catch (_) {
      if (context.mounted) _showError(context);
    }
  }

  void _showError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('The frog-heart portal drifted away. Try again soon.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LabeledIconButton(
      key: const Key('frog-heart-button'),
      label: 'Support',
      tooltip: 'Optional support: Buy Me a Coffee',
      onPressed: () => _open(context),
      icon: const SizedBox.square(
        dimension: 26,
        child: CustomPaint(painter: _FrogHeartPainter()),
      ),
    );
  }
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
          colors: <Color>[Color(0xFFFFDC45), Color(0xFFFF5CBF)],
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
    final pupilPaint = Paint()..color = const Color(0xFF11131B);
    for (final x in <double>[w * 0.30, w * 0.70]) {
      final eye = Offset(x, h * 0.25);
      canvas.drawCircle(eye, w * 0.105, eyePaint);
      canvas.drawCircle(eye, w * 0.047, pupilPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FrogHeartPainter oldDelegate) => false;
}
