// There is ONLY One Block Here /////////////////////////////////////////////

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A lightweight field of drifting, independently twinkling stars.
class CosmicStarField extends StatefulWidget {
  const CosmicStarField({super.key});

  @override
  State<CosmicStarField> createState() => _CosmicStarFieldState();
}

class _CosmicStarFieldState extends State<CosmicStarField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_CosmicStar> _stars;
  bool _animationsDisabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _stars = List.generate(110, _CosmicStar.fromIndex, growable: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    if (animationsDisabled == _animationsDisabled) return;

    _animationsDisabled = animationsDisabled;
    if (_animationsDisabled) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _CosmicStarPainter(animation: _controller, stars: _stars),
        ),
      ),
    );
  }
}

class _CosmicStarPainter extends CustomPainter {
  final Animation<double> animation;
  final List<_CosmicStar> stars;
  final Paint _starPaint = Paint()..style = PaintingStyle.fill;
  final Paint _flarePaint = Paint()..strokeWidth = 0.75;

  _CosmicStarPainter({required this.animation, required this.stars})
    : super(repaint: animation);

  double _fraction(double value) => value - value.floorToDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final time = animation.value;
    final starCount = (size.width * size.height / 4200).round().clamp(55, 110);

    for (var i = 0; i < starCount; i++) {
      final star = stars[i];

      final x = _fraction(
        star.startX + (star.direction * time * 0.018 * star.speed),
      );
      final y = _fraction(star.startY - (time * 0.028 * star.speed));
      final twinkle =
          0.28 +
          (0.72 *
              (0.5 +
                  (0.5 *
                      math.sin(
                        (time * star.speed * 7 * math.pi) +
                            (star.phase * 2 * math.pi),
                      ))));
      final center = Offset(x * size.width, y * size.height);
      _starPaint.color = star.color.withValues(alpha: twinkle * 0.88);

      canvas.drawCircle(center, star.radius, _starPaint);

      if (star.radius > 1.65 && twinkle > 0.68) {
        _flarePaint.color = star.color.withValues(alpha: twinkle * 0.42);
        final flare = star.radius * 2.3;
        canvas.drawLine(
          center.translate(-flare, 0),
          center.translate(flare, 0),
          _flarePaint,
        );
        canvas.drawLine(
          center.translate(0, -flare),
          center.translate(0, flare),
          _flarePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CosmicStarPainter oldDelegate) => false;
}

class _CosmicStar {
  final double startX;
  final double startY;
  final double phase;
  final double speed;
  final double direction;
  final double radius;
  final Color color;

  const _CosmicStar({
    required this.startX,
    required this.startY,
    required this.phase,
    required this.speed,
    required this.direction,
    required this.radius,
    required this.color,
  });

  factory _CosmicStar.fromIndex(int index) {
    double fraction(double value) => value - value.floorToDouble();
    double seed(double salt) {
      return fraction(math.sin((index + 1) * salt) * 43758.5453);
    }

    final colorMix = seed(66.521);
    return _CosmicStar(
      startX: seed(12.9898),
      startY: seed(78.233),
      phase: seed(39.425),
      speed: 0.55 + (seed(93.117) * 1.35),
      direction: seed(17.731) < 0.5 ? -1.0 : 1.0,
      radius: 0.65 + (seed(51.977) * 1.55),
      color: Color.lerp(
        const Color(0xFFFFFFFF),
        colorMix < 0.5 ? const Color(0xFF64FFDA) : const Color(0xFFB060FF),
        0.38,
      )!,
    );
  }
}
