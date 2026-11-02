import 'dart:math' as math;

import 'package:flutter/material.dart';

class CosmicBackdrop extends StatefulWidget {
  const CosmicBackdrop({super.key});

  @override
  State<CosmicBackdrop> createState() => _CosmicBackdropState();
}

class _CosmicBackdropState extends State<CosmicBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      _controller.stop();
      _controller.value = 0.18;
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
          painter: _CosmicBackdropPainter(
            animation: _controller,
            still: _reducedMotion,
          ),
        ),
      ),
    ),
  );
}

class _CosmicBackdropPainter extends CustomPainter {
  _CosmicBackdropPainter({required this.animation, required this.still})
    : super(repaint: animation);

  final Animation<double> animation;
  final bool still;
  static const _twoPi = math.pi * 2;

  double _fraction(double value) => value - value.floorToDouble();
  double _seed(int index, double salt) =>
      _fraction(math.sin((index + 1) * salt) * 43758.5453);

  @override
  void paint(Canvas canvas, Size size) {
    final time = still ? 0.18 : animation.value;
    final hue = 0.5 + 0.5 * math.sin(time * _twoPi);
    final left = Color.lerp(
      const Color(0xff21003d),
      const Color(0xff5a075e),
      hue,
    )!;
    final right = Color.lerp(
      const Color(0xff43004c),
      const Color(0xffff198c),
      hue,
    )!;
    final glow = Color.lerp(
      const Color(0xff9f20ff),
      const Color(0xffff5cab),
      hue,
    )!;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [left, right, const Color(0xff13001f)],
          stops: const [0, 0.6, 1],
        ).createShader(Offset.zero & size),
    );

    final glowCenter = Offset(
      size.width * (0.2 + time * 0.55),
      size.height * (0.28 + 0.08 * math.sin(time * _twoPi)),
    );
    canvas.drawCircle(
      glowCenter,
      size.shortestSide * 0.72,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                glow.withValues(alpha: 0.46),
                glow.withValues(alpha: 0.08),
                Colors.transparent,
              ],
              stops: const [0, 0.48, 1],
            ).createShader(
              Rect.fromCircle(
                center: glowCenter,
                radius: size.shortestSide * 0.72,
              ),
            ),
    );

    final count = (size.width * size.height / 2000).round().clamp(130, 250);
    for (var index = 0; index < count; index++) {
      final speed = 0.45 + _seed(index, 93.117) * 1.25;
      final phase = _seed(index, 39.425);
      final x = _fraction(_seed(index, 12.9898) + time * speed * 0.018);
      final y = _fraction(_seed(index, 78.233) - time * speed * 0.026);
      final twinkle =
          0.12 +
          0.88 *
              (0.5 +
                  0.5 * math.sin(time * speed * 8 * math.pi + phase * _twoPi));
      final radius = 0.55 + _seed(index, 51.977) * 1.85;
      final color = _seed(index, 66.521) < 0.5
          ? Colors.white
          : const Color(0xffffb5dc);
      final center = Offset(x * size.width, y * size.height);
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = color.withValues(alpha: 0.18 + twinkle * 0.82),
      );
      if (radius > 1.55 && twinkle > 0.64) {
        final flare = radius * 2.5;
        final paint = Paint()
          ..color = color.withValues(alpha: twinkle * 0.7)
          ..strokeWidth = 0.8;
        canvas.drawLine(
          center.translate(-flare, 0),
          center.translate(flare, 0),
          paint,
        );
        canvas.drawLine(
          center.translate(0, -flare),
          center.translate(0, flare),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CosmicBackdropPainter oldDelegate) =>
      oldDelegate.still != still;
}

class FlowingBlobTitle extends StatefulWidget {
  const FlowingBlobTitle({super.key, required this.text});
  final String text;

  @override
  State<FlowingBlobTitle> createState() => _FlowingBlobTitleState();
}

class _FlowingBlobTitleState extends State<FlowingBlobTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reducedMotion = false;

  double _titleHeight(BuildContext context, double width) {
    final painter = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.1,
        ),
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      _controller.stop();
      _controller.value = 0.22;
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
  Widget build(BuildContext context) => RepaintBoundary(
    child: LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: _titleHeight(context, constraints.maxWidth),
        width: constraints.maxWidth,
        child: CustomPaint(
          painter: _BlobTitlePainter(
            text: widget.text,
            textScaler: MediaQuery.textScalerOf(context),
            animation: _controller,
            still: _reducedMotion,
          ),
        ),
      ),
    ),
  );
}

class _BlobTitlePainter extends CustomPainter {
  _BlobTitlePainter({
    required this.text,
    required this.textScaler,
    required this.animation,
    required this.still,
  }) : super(repaint: animation);
  final String text;
  final TextScaler textScaler;
  final Animation<double> animation;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.1,
        ),
      ),
      textScaler: textScaler,

      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    final offset = Offset(0, (size.height - painter.height) / 2);
    final rect = offset & painter.size;
    canvas.saveLayer(rect, Paint());
    painter.paint(canvas, offset);
    final time = still ? 0.22 : animation.value;
    final black = Paint()
      ..color = Colors.black
      ..blendMode = BlendMode.srcATop;
    for (var index = 0; index < 5; index++) {
      final x =
          rect.left +
          ((time + index * 0.24) % 1.25) * rect.width -
          rect.width * 0.18;
      final y =
          rect.center.dy +
          math.sin(time * math.pi * 2 + index * 1.8) * rect.height * 0.18;
      canvas.drawCircle(
        Offset(x, y),
        rect.height * (0.38 + (index % 2) * 0.12),
        black,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BlobTitlePainter oldDelegate) =>
      oldDelegate.text != text ||
      oldDelegate.still != still ||
      oldDelegate.textScaler != textScaler;
}
