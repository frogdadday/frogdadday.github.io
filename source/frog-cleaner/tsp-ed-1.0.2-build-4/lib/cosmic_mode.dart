import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'frog_painter.dart';

/// A low-key red nebula and drifting ember field used only in Cosmic Mode.
class RedCosmicBackdrop extends StatefulWidget {
  const RedCosmicBackdrop({super.key});

  @override
  State<RedCosmicBackdrop> createState() => _RedCosmicBackdropState();
}

class _RedCosmicBackdropState extends State<RedCosmicBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _animationsDisabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsDisabled = MediaQuery.disableAnimationsOf(context);
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
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _RedCosmicPainter(
            animation: _controller,
            still: _animationsDisabled,
          ),
        ),
      ),
    ),
  );
}

class _RedCosmicPainter extends CustomPainter {
  _RedCosmicPainter({required this.animation, required this.still})
    : super(repaint: animation);

  final Animation<double> animation;
  final bool still;

  static const _backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xff21080d), Color(0xff3c1018), Color(0xff16070b)],
    stops: [0, 0.52, 1],
  );
  static const _glowGradient = RadialGradient(
    colors: [Color(0x5ca32430), Color(0x1453101a), Colors.transparent],
    stops: [0, 0.52, 1],
  );
  static const _twoPi = math.pi * 2;

  double _fraction(double value) => value - value.floorToDouble();
  double _seed(int index, double salt) =>
      _fraction(math.sin((index + 1) * salt) * 43758.5453);

  @override
  void paint(Canvas canvas, Size size) {
    final time = still ? 0.22 : animation.value;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = _backgroundGradient.createShader(Offset.zero & size),
    );

    final glowCenter = Offset(
      size.width * (0.18 + (time * 0.12)),
      size.height * (0.34 + (time * 0.08)),
    );
    canvas.drawCircle(
      glowCenter,
      size.shortestSide * 0.68,
      Paint()
        ..shader = _glowGradient.createShader(
          Rect.fromCircle(center: glowCenter, radius: size.shortestSide * 0.68),
        ),
    );

    final starCount = (size.width * size.height / 2500).round().clamp(105, 210);
    final twinkleBase = time * 9 * math.pi;
    for (var i = 0; i < starCount; i++) {
      final phase = _seed(i, 39.425);
      final speed = 0.5 + (_seed(i, 93.117) * 1.1);
      final x = _fraction(_seed(i, 12.9898) + (time * speed * 0.018));
      final y = _fraction(_seed(i, 78.233) - (time * speed * 0.025));
      final twinkle =
          0.12 +
          (0.88 *
              (0.5 +
                  (0.5 * math.sin((twinkleBase * speed) + (phase * _twoPi)))));
      final radius = 0.65 + (_seed(i, 51.977) * 1.8);
      final warm = _seed(i, 66.521) < 0.62;
      final color = warm ? const Color(0xffffd05a) : const Color(0xffff9e8e);
      final center = Offset(x * size.width, y * size.height);
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = color.withValues(alpha: 0.22 + (twinkle * 0.78)),
      );
      if (radius > 1.45 && twinkle > 0.58) {
        final flare = radius * (2.5 + (twinkle * 1.4));
        final flarePaint = Paint()
          ..color = color.withValues(alpha: twinkle * 0.62)
          ..strokeWidth = 0.9;
        canvas.drawLine(
          center.translate(-flare, 0),
          center.translate(flare, 0),
          flarePaint,
        );
        canvas.drawLine(
          center.translate(0, -flare),
          center.translate(0, flare),
          flarePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RedCosmicPainter oldDelegate) =>
      oldDelegate.still != still;
}

/// In Cosmic Mode, completes a full opaque → transparent → opaque loop every
/// five seconds. Reduced-motion users see a stable bright-orange title.
class CosmicFadingTitle extends StatefulWidget {
  const CosmicFadingTitle({super.key, required this.text});

  final String text;

  @override
  State<CosmicFadingTitle> createState() => _CosmicFadingTitleState();
}

/// Gives the mascot a calm idle motion and animates its Cosmic Mode beams.
class CosmicFrog extends StatefulWidget {
  const CosmicFrog({super.key, required this.cosmicMode});

  final bool cosmicMode;

  @override
  State<CosmicFrog> createState() => _CosmicFrogState();
}

class _CosmicFrogState extends State<CosmicFrog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _animationsDisabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsDisabled = MediaQuery.disableAnimationsOf(context);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant CosmicFrog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cosmicMode != widget.cosmicMode) _syncAnimation();
  }

  void _syncAnimation() {
    if (!_animationsDisabled) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _blink(double value) {
    const center = 0.68;
    const halfWidth = 0.07;
    return (1 - ((value - center).abs() / halfWidth))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final phase = _animationsDisabled ? 0.0 : _controller.value * math.pi * 2;
      final breathing = math.sin(phase);
      return CustomPaint(
        painter: FrogPainter(
          eyesClosed: false,
          winkLeft: false,
          lightning: false,
          cosmicMode: widget.cosmicMode,
          reactionFlash: false,
          isFrozen: false,
          shimmerValue: _animationsDisabled ? 0 : _controller.value,
          headTilt: _animationsDisabled ? 0 : breathing * 0.035,
          squishX: _animationsDisabled ? 1 : 1 + breathing * 0.018,
          squishY: _animationsDisabled ? 1 : 1 - breathing * 0.018,
          slowBlink: _animationsDisabled ? 0 : _blink(_controller.value),
        ),
      );
    },
  );
}

class _CosmicFadingTitleState extends State<CosmicFadingTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _animationsDisabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsDisabled = MediaQuery.disableAnimationsOf(context);
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final opacity = _animationsDisabled
          ? 1.0
          : 0.5 + (0.5 * math.cos(_controller.value * 2 * math.pi));
      return Opacity(
        key: const ValueKey('cosmic-title-opacity'),
        opacity: opacity,
        child: Transform.scale(
          scale: 0.94 + (opacity * 0.06),
          alignment: Alignment.centerLeft,
          child: child,
        ),
      );
    },
    child: ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xfffff17a), Color(0xffffa000), Color(0xffff5a14)],
      ).createShader(bounds),
      child: Text(
        widget.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.35,
          shadows: [
            Shadow(color: Color(0xffff4e14), blurRadius: 20),
            Shadow(color: Color(0xffff8a00), blurRadius: 11),
            Shadow(color: Color(0xffffd14a), blurRadius: 4),
          ],
        ),
      ),
    ),
  );
}
