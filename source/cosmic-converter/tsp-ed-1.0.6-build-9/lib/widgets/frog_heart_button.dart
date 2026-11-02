// There is ONLY One Block Here /////////////////////////////////////////////
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class FrogHeartButton extends StatelessWidget {
  const FrogHeartButton({super.key});

  static final Uri _supportUri = Uri.parse(
    'https://buymeacoffee.com/frogdadday',
  );

  void _showLaunchError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "The support portal drifted out of reach. Please try again.",
        ),
      ),
    );
  }

  Future<void> _openSupportPage(BuildContext context) async {
    try {
      final opened = await launchUrl(
        _supportUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && context.mounted) {
        _showLaunchError(context);
      }
    } catch (_) {
      if (context.mounted) {
        _showLaunchError(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: "Support Cosmic Converter",
      child: Tooltip(
        message: "Support Cosmic Converter",
        child: IconButton(
          onPressed: () => _openSupportPage(context),
          padding: const EdgeInsets.all(9),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const SizedBox(
            width: 30,
            height: 30,
            child: CustomPaint(painter: _FrogHeartPainter()),
          ),
        ),
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

    final heartPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF64FFDA), Color(0xFFB060FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    canvas.drawPath(heart, heartPaint);
    canvas.drawPath(
      heart,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final eyeRadius = w * 0.115;
    final leftEye = Offset(w * 0.29, h * 0.22);
    final rightEye = Offset(w * 0.71, h * 0.22);
    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = const Color(0xFF101020);

    canvas.drawCircle(leftEye, eyeRadius, eyePaint);
    canvas.drawCircle(rightEye, eyeRadius, eyePaint);
    canvas.drawCircle(leftEye, eyeRadius * 0.48, pupilPaint);
    canvas.drawCircle(rightEye, eyeRadius * 0.48, pupilPaint);

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.90);
    canvas.drawCircle(
      leftEye.translate(-eyeRadius * 0.22, -eyeRadius * 0.22),
      eyeRadius * 0.16,
      highlightPaint,
    );
    canvas.drawCircle(
      rightEye.translate(-eyeRadius * 0.22, -eyeRadius * 0.22),
      eyeRadius * 0.16,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FrogHeartPainter oldDelegate) => false;
}
