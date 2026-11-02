// There is ONLY One Block Here /////////////////////////////////////////////
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A deliberately overdramatic ten-second heat-death dissolution.
class FrogHeatDeath extends StatelessWidget {
  final double progress;
  final Widget child;

  const FrogHeatDeath({super.key, required this.progress, required this.child});

  double _clamp01(double value) => value.clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final p = _clamp01(progress);

    // The first fifth flickers; the frog then fades away by 80%.
    final weakening = _clamp01(p / 0.2);
    final dissolve = _clamp01((p - 0.2) / 0.6);
    final flicker = p < 0.2
        ? 1.0 - (0.18 * weakening * (0.5 + 0.5 * math.sin(p * 32 * math.pi)))
        : 1.0;
    final frogOpacity = _clamp01((1.0 - dissolve) * flicker);
    final scale = 1.0 - (0.22 * dissolve);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: frogOpacity,
          child: Transform.scale(scale: scale, child: child),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _HeatDeathDustPainter(progress: p)),
          ),
        ),
      ],
    );
  }
}

class _HeatDeathDustPainter extends CustomPainter {
  final double progress;
  static final List<_HeatDeathParticle> _particles = List.generate(
    32,
    _HeatDeathParticle.fromIndex,
    growable: false,
  );
  static final Paint _dustPaint = Paint();

  const _HeatDeathDustPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.12 || progress >= 1.0) return;

    final dustProgress = ((progress - 0.12) / 0.88).clamp(0.0, 1.0).toDouble();
    final dustOpacity = math.sin(dustProgress * math.pi);

    for (final particle in _particles) {
      final origin = Offset(
        size.width * (0.12 + particle.seedX * 0.76),
        size.height * (0.15 + particle.seedY * 0.70),
      );
      final drift = Offset(
        particle.direction * (5.0 + particle.seedY * 22.0) * dustProgress,
        -(4.0 + particle.seedX * 30.0) * dustProgress,
      );
      _dustPaint.color = particle.color.withValues(alpha: dustOpacity * 0.9);

      canvas.drawCircle(origin + drift, particle.radius, _dustPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeatDeathDustPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _HeatDeathParticle {
  final double seedX;
  final double seedY;
  final double direction;
  final double radius;
  final Color color;

  const _HeatDeathParticle({
    required this.seedX,
    required this.seedY,
    required this.direction,
    required this.radius,
    required this.color,
  });

  factory _HeatDeathParticle.fromIndex(int index) {
    double fraction(double value) => value - value.floorToDouble();
    final seedX = fraction(math.sin(index * 12.9898) * 43758.5453);
    final seedY = fraction(math.sin((index + 17) * 78.233) * 24634.6345);
    return _HeatDeathParticle(
      seedX: seedX,
      seedY: seedY,
      direction: seedX < 0.5 ? -1.0 : 1.0,
      radius: 0.6 + seedY * 1.4,
      color: Color.lerp(
        const Color(0xFF6CCF5A),
        const Color(0xFFB060FF),
        seedX,
      )!,
    );
  }
}
