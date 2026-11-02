// ////Block One//////////////////////////////////////////////////////////////
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'frog_motion.dart';

/// Identical tie-dye Frogdadday mascot in every mode. Its idle expressions
/// use the behavior from Cosmic Converter: randomized every three seconds,
/// with distinct blink, wink, head tilt and brief squish reactions.
class TieDyeFrog extends StatefulWidget {
  const TieDyeFrog({super.key, this.size = 64, this.cosmicMode = false});

  final double size;
  final bool cosmicMode;

  @override
  State<TieDyeFrog> createState() => _TieDyeFrogState();
}

class _TieDyeFrogState extends State<TieDyeFrog>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final math.Random _random = math.Random();
  late final AnimationController _expression;
  Timer? _idleTimer;
  int _choice = -1;
  FrogPose _pose = const FrogPose();
  bool _active = true;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _expression = AnimationController(vsync: this)
      ..addListener(() {
        if (!mounted) return;
        final elapsed = _expression.value *
            FrogIdleMotion.reactionDuration(_choice);
        setState(() {
          _pose = FrogIdleMotion.reactionPose(_choice, elapsed);
        });
      });
    _syncIdle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncIdle();
  }

  void _syncIdle() {
    _idleTimer?.cancel();
    if (!_active || _reduceMotion) {
      _expression.stop();
      _pose = const FrogPose();
      return;
    }
    _idleTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_active || _reduceMotion) return;
      // Directly reuses the Converter idle choice set and timing.
      _choice = _random.nextInt(5);
      final duration = FrogIdleMotion.reactionDuration(_choice);
      _expression.duration = Duration(
        microseconds: (duration * Duration.microsecondsPerSecond).round(),
      );
      _expression.forward(from: 0);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _syncIdle();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _expression.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: widget.cosmicMode
          ? 'Animated tie-dye Frogdadday mascot in Cosmic Mode'
          : 'Animated tie-dye Frogdadday mascot',
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: TieDyeFrogPainter(
            cosmicMode: widget.cosmicMode,
            pose: _pose,
          ),
        ),
      ),
    );
  }
}

// ////Block Two//////////////////////////////////////////////////////////////
class TieDyeFrogPainter extends CustomPainter {
  const TieDyeFrogPainter({
    required this.cosmicMode,
    this.pose = const FrogPose(),
    this.drawEyes = true,
  });

  final bool cosmicMode;
  final FrogPose pose;
  // Cosmic liquid mode caches the colorful body WITHOUT eyes. The separate
  // intact eyeballs are then painted last and can fall into the puddle.
  final bool drawEyes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Converter's squish / head-tilt transform is kept intact.
    canvas.translate(size.width * 0.5, size.height * 0.5);
    canvas.rotate(pose.tilt);
    canvas.scale(pose.squishX, pose.squishY);
    canvas.translate(-size.width * 0.5, -size.height * 0.5);
    final body = _silhouette(size);
    _drawTieDyeBody(canvas, body, size);
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFF17120A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, size.width * 0.026),
    );

    if (drawEyes) _drawEyes(canvas, size);
    _drawSmile(canvas, size);
    canvas.restore();
  }

  // Original Cosmic Spinner geometry. Only the color fill has changed.
  static const _dye = <Color>[
    Color(0xFFFF4938),
    Color(0xFFFFA42A),
    Color(0xFFFFE04A),
    Color(0xFF3FC66F),
    Color(0xFF38CCE5),
    Color(0xFF426AE9),
    Color(0xFF9C56DF),
    Color(0xFFED62C8),
    Color(0xFFFF4938),
  ];

  void _drawTieDyeBody(Canvas canvas, Path silhouette, Size size) {
    final center = Offset(size.width * 0.50, size.height * 0.54);
    canvas.save();
    canvas.clipPath(silhouette);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.sweep(center, _dye, const <double>[
          0,
          0.125,
          0.25,
          0.375,
          0.5,
          0.625,
          0.75,
          0.875,
          1,
        ]),
    );
    for (var band = 0; band < 7; band++) {
      final spiral = Path();
      for (var step = 0; step <= 42; step++) {
        final t = step / 42;
        final angle = band * math.pi * 2 / 7 + t * math.pi * 2 * 1.20;
        final radius = size.shortestSide * (0.02 + 0.68 * t);
        final point = Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        );
        if (step == 0) {
          spiral.moveTo(point.dx, point.dy);
        } else {
          spiral.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        spiral,
        Paint()
          ..color = _dye[(band + 2) % (_dye.length - 1)].withValues(
            alpha: cosmicMode ? 0.56 : 0.40,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, size.width * 0.075)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
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
    for (final (index, x) in <(int, double)>[
      (0, size.width * 0.34),
      (1, size.width * 0.66),
    ]) {
      drawIntactEye(
        canvas,
        Offset(x, size.height * 0.29),
        size.width * 0.15,
        index == 0 && pose.winkLeft ? 1.0 : pose.blink,
      );
    }
  }

  /// The original Converter/Spinner eye geometry, reused for detached eyes.
  /// Purely paints the white eye, black pupil and highlight. An eye can blink
  /// or fall independently but never dissolves into dye.
  static void drawIntactEye(
    Canvas canvas,
    Offset center,
    double radius,
    double blinkValue,
  ) {
    final blink = blinkValue.clamp(0.0, 1.0).toDouble();
    final eyeHeight = math.max(
      radius * 0.12,
      radius * 1.58 * (1.0 - blink * 0.92),
    );
    final pupilHeight = math.max(
      radius * 0.05,
      radius * 0.76 * (1.0 - blink * 0.96),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 1.58,
        height: eyeHeight,
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0.0, radius * 0.08),
        width: radius * 0.76,
        height: pupilHeight,
      ),
      Paint()..color = const Color(0xFF141414),
    );
    if (blink < 0.72) {
      canvas.drawCircle(
        center.translate(-radius * 0.13, -radius * 0.10),
        radius * 0.10 * (1.0 - blink),
        Paint()..color = Colors.white,
      );
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
        ..color = const Color(0xFF211506)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.2, size.width * 0.025),
    );
  }

  @override
  bool shouldRepaint(covariant TieDyeFrogPainter oldDelegate) {
    return oldDelegate.cosmicMode != cosmicMode ||
        oldDelegate.pose != pose ||
        oldDelegate.drawEyes != drawEyes;
  }
}
