// ////Block One//////////////////////////////////////////////////////////////
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class YellowFrog extends StatefulWidget {
  const YellowFrog({
    super.key,
    this.size = 64,
    this.cosmicMode = false,
    this.hasLegs = false,
    this.kick = 0,
  });

  final double size;
  final bool cosmicMode;
  final bool hasLegs;
  final double kick;

  @override
  State<YellowFrog> createState() => _YellowFrogState();
}

class _YellowFrogState extends State<YellowFrog> with TickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final AnimationController _idleController;
  Timer? _idleTimer;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener(_idleAnimationChanged);
    if (widget.cosmicMode) _shimmerController.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion &&
        (_idleTimer != null || _idleController.isAnimating)) {
      return;
    }
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      _idleTimer?.cancel();
      _idleTimer = null;
      _idleController
        ..stop()
        ..value = 0;
      _shimmerController
        ..stop()
        ..value = 0;
    } else {
      _scheduleIdleAnimation(const Duration(milliseconds: 1600));
      if (widget.cosmicMode) _shimmerController.repeat();
    }
  }

  void _idleAnimationChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || _reduceMotion) return;
    _idleController.value = 0;
    _scheduleIdleAnimation(const Duration(milliseconds: 4300));
  }

  void _scheduleIdleAnimation(Duration delay) {
    _idleTimer?.cancel();
    _idleTimer = Timer(delay, () {
      _idleTimer = null;
      if (!mounted || _reduceMotion) return;
      _idleController.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(covariant YellowFrog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cosmicMode == widget.cosmicMode) return;
    if (widget.cosmicMode && !_reduceMotion) {
      _shimmerController.repeat();
    } else {
      _shimmerController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _idleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  static double _blinkPulse(double value, double center, double width) {
    return (1 - (value - center).abs() / width).clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: widget.hasLegs
          ? (widget.kick >= 1
                ? 'Frog foot marks the selected slice'
                : '${widget.cosmicMode ? 'Silver' : 'Yellow'} frog ready beside the spinner')
          : '${widget.cosmicMode ? 'Silver' : 'Yellow'} frog companion',
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[
            _shimmerController,
            _idleController,
          ]),
          builder: (context, _) {
            final idle = Curves.easeInOut.transform(_idleController.value);
            final blink = math.max(
              _blinkPulse(idle, 0.20, 0.09),
              _blinkPulse(idle, 0.39, 0.08) * 0.82,
            );
            final movement = widget.hasLegs ? 0.0 : math.sin(idle * math.pi);
            final tilt = widget.hasLegs
                ? 0.0
                : math.sin(idle * math.pi * 2) * 0.035;
            final frog = CustomPaint(
              painter: YellowFrogPainter(
                cosmicMode: widget.cosmicMode,
                hasLegs: widget.hasLegs,
                kick: widget.kick,
                shimmer: _shimmerController.value,
                blink: blink,
              ),
            );
            return Transform.rotate(
              angle: tilt,
              alignment: Alignment.bottomCenter,
              child: Transform.scale(
                scaleX: 1 + movement * 0.025,
                scaleY: 1 - movement * 0.035,
                alignment: Alignment.bottomCenter,
                child: frog,
              ),
            );
          },
        ),
      ),
    );
  }
}

// ////Block Two//////////////////////////////////////////////////////////////
class YellowFrogPainter extends CustomPainter {
  static const extendedToe = Offset(-0.32, 0.72);
  const YellowFrogPainter({
    required this.cosmicMode,
    required this.hasLegs,
    required this.kick,
    this.shimmer = 0,
    this.blink = 0,
  });

  final bool cosmicMode;
  final bool hasLegs;
  final double kick;
  final double shimmer;
  final double blink;

  @override
  void paint(Canvas canvas, Size size) {
    final body = _silhouette(size);
    final fill = Paint()..style = PaintingStyle.fill;
    if (cosmicMode) {
      fill.shader = ui.Gradient.linear(
        Offset(-size.width + shimmer * size.width * 3, 0),
        Offset(size.width + shimmer * size.width * 3, size.height),
        const <Color>[
          Color(0xFF718192),
          Color(0xFFF8FCFF),
          Color(0xFF9CAAB8),
          Color(0xFFFFFFFF),
          Color(0xFF738496),
        ],
        const <double>[0, 0.30, 0.52, 0.69, 1],
      );
    } else {
      fill.color = AppColors.frogYellow;
    }
    canvas.drawPath(body, fill);
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFF16212D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, size.width * 0.026),
    );

    _drawEyes(canvas, size);
    _drawSmile(canvas, size);
    if (hasLegs) _drawLegs(canvas, size);
    if (cosmicMode) _drawSparkles(canvas, size);
  }

  Path _silhouette(Size size) {
    final w = size.width;
    final h = size.height;
    final headTop = h * 0.25;
    final headBottom = h * (hasLegs ? 0.66 : 0.80);
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
    final white = Paint()..color = Colors.white;
    final dark = Paint()..color = const Color(0xFF141414);
    final eyeHeight = eyeRadius * 1.58 * (1 - blink * 0.92);
    final pupilHeight = eyeRadius * 0.76 * (1 - blink * 0.96);
    for (final x in <double>[w * 0.34, w * 0.66]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: eyeRadius * 1.58,
          height: eyeHeight,
        ),
        white,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y + eyeRadius * 0.08),
          width: eyeRadius * 0.76,
          height: pupilHeight,
        ),
        dark,
      );
      if (blink < 0.72) {
        canvas.drawCircle(
          Offset(x - eyeRadius * 0.13, y - eyeRadius * 0.10),
          eyeRadius * 0.10 * (1 - blink),
          white,
        );
      }
    }
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
        ..color = const Color(0xFF243444)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.2, size.width * 0.025),
    );
  }

  void _drawLegs(Canvas canvas, Size size) {
    final legPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.width * 0.11;
    if (cosmicMode) {
      legPaint.shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, size.height),
        const <Color>[Color(0xFF738496), Color(0xFFFFFFFF), Color(0xFF9CAAB8)],
        const <double>[0, 0.48, 1],
      );
    } else {
      legPaint.color = AppColors.frogYellow;
    }
    final outline = Paint()
      ..color = const Color(0xFF16212D)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.width * 0.16;

    final leftStart = Offset(size.width * 0.34, size.height * 0.68);
    final rightStart = Offset(size.width * 0.68, size.height * 0.68);
    // Once the kick lands, the leg stays extended as the wheel's clicker.
    final kickWave = kick.clamp(0, 1);
    final leftEnd = Offset(
      size.width * (0.18 - kickWave * 0.38),
      size.height * (0.90 - kickWave * 0.18),
    );
    final rightEnd = Offset(size.width * 0.85, size.height * 0.92);
    for (final paint in <Paint>[outline, legPaint]) {
      canvas.drawLine(leftStart, leftEnd, paint);
      canvas.drawLine(rightStart, rightEnd, paint);
    }
    final toePaint = Paint()
      ..color = const Color(0xFF16212D)
      ..strokeWidth = size.width * 0.025
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      leftEnd,
      leftEnd.translate(-size.width * 0.12, 0),
      toePaint,
    );
    canvas.drawLine(
      rightEnd,
      rightEnd.translate(size.width * 0.10, 0),
      toePaint,
    );
  }

  void _drawSparkles(Canvas canvas, Size size) {
    final time = shimmer * math.pi * 2;
    for (var i = 0; i < 6; i++) {
      final flash =
          math.pow((math.sin(time * 3 + i * 1.9) + 1) / 2, 5) as double;
      if (flash < 0.08) continue;
      final center = Offset(
        size.width * (0.18 + (i * 0.14) % 0.62),
        size.height * (0.18 + (i % 3) * 0.22),
      );
      final radius = 1 + flash * size.width * 0.08;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: flash)
        ..strokeWidth = 1 + flash
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy),
        paint,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant YellowFrogPainter oldDelegate) {
    return oldDelegate.cosmicMode != cosmicMode ||
        oldDelegate.hasLegs != hasLegs ||
        oldDelegate.kick != kick ||
        oldDelegate.shimmer != shimmer ||
        oldDelegate.blink != blink;
  }
}
