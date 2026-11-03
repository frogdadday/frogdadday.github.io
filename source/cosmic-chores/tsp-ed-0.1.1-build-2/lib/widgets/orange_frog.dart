// /////Block One/////////////////////////////////////////////////////////////
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class OrangeFrog extends StatefulWidget {
  const OrangeFrog({super.key, this.size = 78});

  final double size;

  @override
  State<OrangeFrog> createState() => _OrangeFrogState();
}

class _OrangeFrogState extends State<OrangeFrog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 850),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _controller.value = 0;
            _scheduleBlink();
          }
        });
    _scheduleBlink();
  }

  void _scheduleBlink() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted && !MediaQuery.disableAnimationsOf(context)) {
        _controller.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Friendly orange frog mascot',
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final blink = math
                .sin(_controller.value * math.pi)
                .clamp(0, 1)
                .toDouble();
            return CustomPaint(painter: OrangeFrogPainter(blink: blink));
          },
        ),
      ),
    );
  }
}

// /////Block Two/////////////////////////////////////////////////////////////
/// Uses the same current Frogdadday silhouette as the other apps, recolored.
class OrangeFrogPainter extends CustomPainter {
  const OrangeFrogPainter({this.blink = 0});

  final double blink;

  @override
  void paint(Canvas canvas, Size size) {
    final body = _silhouette(size);
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.orangeSoft, AppColors.orange],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, size.width * 0.026),
    );
    _drawEyes(canvas, size);
    _drawSmile(canvas, size);
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
    final radius = size.width * 0.15;
    final y = size.height * 0.29;
    final eyeHeight = radius * 1.58 * (1 - blink * 0.92);
    final pupilHeight = radius * 0.76 * (1 - blink * 0.96);
    for (final x in <double>[size.width * 0.34, size.width * 0.66]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: radius * 1.58,
          height: eyeHeight,
        ),
        Paint()..color = Colors.white,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y + radius * 0.08),
          width: radius * 0.76,
          height: pupilHeight,
        ),
        Paint()..color = const Color(0xFF141414),
      );
    }
  }

  void _drawSmile(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.35, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.67,
        size.width * 0.65,
        size.height * 0.55,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.2, size.width * 0.025),
    );
  }

  @override
  bool shouldRepaint(covariant OrangeFrogPainter oldDelegate) =>
      oldDelegate.blink != blink;
}
