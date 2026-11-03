// ////Block One//////////////////////////////////////////////////////////////
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import '../theme/app_theme.dart';
import 'frog_heart_button.dart';
import 'labeled_icon_button.dart';
import 'yellow_frog.dart';

class CosmicScaffold extends StatelessWidget {
  const CosmicScaffold({
    super.key,
    required this.controller,
    required this.body,
    this.showAppBarFrog = true,
    this.canGoBack = true,
  });

  final AppController controller;
  final Widget body;
  final bool showAppBarFrog;
  final bool canGoBack;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leadingWidth: MediaQuery.textScalerOf(context).scale(80),
            leading: canGoBack && Navigator.canPop(context)
                ? LabeledIconButton(
                    label: 'Back',
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back, size: 20),
                    onPressed: () => Navigator.maybePop(context),
                  )
                : null,
            toolbarHeight: 78,
            backgroundColor: AppColors.background.withValues(alpha: 0.96),
            surfaceTintColor: Colors.transparent,
            titleSpacing: canGoBack ? 0 : 18,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: OutlinedAppTitle(cosmicMode: controller.cosmicMode),
                ),
                if (showAppBarFrog) ...<Widget>[
                  const SizedBox(width: 8),
                  YellowFrog(size: 58, cosmicMode: controller.cosmicMode),
                ],
              ],
            ),
          ),
          body: Stack(
            children: <Widget>[
              Positioned.fill(
                child: CosmicBackdrop(cosmicMode: controller.cosmicMode),
              ),
              SafeArea(top: false, bottom: false, child: body),
            ],
          ),
          bottomNavigationBar: Material(
            color: AppColors.background,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _RoundControl(
                        key: const Key('sound-toggle'),
                        label: controller.soundOn ? 'Sound on' : 'Sound off',
                        tooltip: controller.soundOn
                            ? 'Turn sound off'
                            : 'Turn sound on',
                        icon: controller.soundOn
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        onPressed: controller.toggleSound,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RoundControl(
                        key: const Key('cosmic-toggle'),
                        label: controller.cosmicMode
                            ? 'Cosmic on'
                            : 'Cosmic off',
                        tooltip: controller.cosmicMode
                            ? 'Calm the cosmos'
                            : 'Make it cosmic',
                        icon: controller.cosmicMode
                            ? Icons.auto_awesome
                            : Icons.nights_stay_rounded,
                        highlighted: controller.cosmicMode,
                        onPressed: controller.toggleCosmicMode,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: FrogHeartButton()),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class OutlinedAppTitle extends StatefulWidget {
  const OutlinedAppTitle({super.key, required this.cosmicMode});

  final bool cosmicMode;

  @override
  State<OutlinedAppTitle> createState() => _OutlinedAppTitleState();
}

class _OutlinedAppTitleState extends State<OutlinedAppTitle>
    with SingleTickerProviderStateMixin {
  static const _cosmicColors = <Color>[
    Color(0xFF7354C2),
    Color(0xFF167D8D),
    Color(0xFFB83F73),
    Color(0xFF4657B0),
    Color(0xFF237A62),
    Color(0xFFB9582D),
  ];
  late final AnimationController _sparkleController;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    if (widget.cosmicMode && !_reduceMotion) _sparkleController.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _sparkleController
        ..stop()
        ..value = 0;
    } else if (widget.cosmicMode && !_sparkleController.isAnimating) {
      _sparkleController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant OutlinedAppTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cosmicMode == widget.cosmicMode) return;
    if (widget.cosmicMode && !_reduceMotion) {
      _sparkleController.repeat();
    } else {
      _sparkleController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const text = 'COSMIC SPINNER';
    const style = TextStyle(
      fontSize: 23,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.7,
    );
    return Semantics(
      header: true,
      label: text,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _sparkleController,
          builder: (context, _) {
            if (!widget.cosmicMode) {
              return Stack(
                children: <Widget>[
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: style.copyWith(
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 2.4
                        ..color = AppColors.darkRed,
                    ),
                  ),
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: style.copyWith(color: AppColors.vibrantGreen),
                  ),
                ],
              );
            }
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: style.copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 2.4
                      ..color =
                          _cosmicColors[(_sparkleController.value *
                                      _cosmicColors.length)
                                  .floor() %
                              _cosmicColors.length],
                  ),
                ),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment(-1.8 + _sparkleController.value * 3.6, 0),
                    end: Alignment(0.2 + _sparkleController.value * 3.6, 0),
                    colors: _cosmicColors,
                    tileMode: TileMode.mirror,
                  ).createShader(bounds),
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: style,
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _TitleSparklePainter(_sparkleController),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TitleSparklePainter extends CustomPainter {
  _TitleSparklePainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final time = animation.value * math.pi * 2;
    const colors = <Color>[
      Color(0xFF7354C2),
      Color(0xFF167D8D),
      Color(0xFFB83F73),
      Color(0xFF4657B0),
      Color(0xFF237A62),
      Color(0xFFB9582D),
    ];
    for (var i = 0; i < 17; i++) {
      final phase = i * 1.83;
      final flash =
          math.pow((math.sin(time * 2.6 + phase) + 1) / 2, 5) as double;
      if (flash < 0.05) continue;
      final center = Offset(
        size.width * ((i * 0.173 + 0.04) % 1),
        size.height * (0.14 + (i % 4) * 0.24),
      );
      final radius = 1.5 + flash * 5.2;
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: flash)
        ..strokeWidth = 1.2 + flash * 1.4
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
  bool shouldRepaint(covariant _TitleSparklePainter oldDelegate) => false;
}

// ////Block Two//////////////////////////////////////////////////////////////
class _RoundControl extends StatelessWidget {
  const _RoundControl({
    super.key,
    required this.tooltip,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.highlighted = false,
  });

  final String tooltip;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return LabeledIconButton(
      label: label,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 26,
        color: highlighted ? AppColors.frogYellow : null,
      ),
    );
  }
}

class CosmicBackdrop extends StatefulWidget {
  const CosmicBackdrop({super.key, required this.cosmicMode});

  final bool cosmicMode;

  @override
  State<CosmicBackdrop> createState() => _CosmicBackdropState();
}

class _CosmicBackdropState extends State<CosmicBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkleController;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _twinkleController = AnimationController(
      vsync: this,
      // One long seamless cycle leaves room for a slow nebula turn while
      // individual stars still twinkle several times within the minute.
      duration: const Duration(seconds: 60),
    );
    if (widget.cosmicMode && !_reduceMotion) _twinkleController.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _twinkleController
        ..stop()
        ..value = 0;
    } else if (widget.cosmicMode && !_twinkleController.isAnimating) {
      _twinkleController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant CosmicBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cosmicMode == widget.cosmicMode) return;
    if (widget.cosmicMode && !_reduceMotion) {
      _twinkleController.repeat();
    } else {
      _twinkleController.stop();
    }
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        gradient: widget.cosmicMode
            ? const RadialGradient(
                center: Alignment(-0.45, -0.65),
                radius: 1.35,
                colors: <Color>[
                  Color(0xFF4C145F),
                  Color(0xFF102B68),
                  Color(0xFF07111F),
                  Color(0xFF02040C),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF0A182A), AppColors.background],
              ),
      ),
      child: widget.cosmicMode
          ? CustomPaint(painter: _StarPainter(_twinkleController))
          : null,
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.twinkle) : super(repaint: twinkle);

  final Animation<double> twinkle;

  @override
  void paint(Canvas canvas, Size size) {
    final cycle = twinkle.value;
    final seconds = cycle * 60;
    _paintNebula(canvas, size, cycle);
    _paintShootingStars(canvas, size, seconds);

    for (var i = 0; i < 82; i++) {
      final x = ((math.sin(i * 12.9898) + 1) / 2) * size.width;
      final y = ((math.sin(i * 78.233 + 1.7) + 1) / 2) * size.height;
      final phase = i * 2.41;
      final pulse =
          (math.sin(cycle * math.pi * 2 * (13 + i % 7 * 3) + phase) + 1) / 2;
      final shimmer =
          (math.sin(cycle * math.pi * 2 * (29 + i % 5 * 4) + phase * 1.7) + 1) /
          2;
      final intensity = (0.20 + pulse * 0.65 + shimmer * 0.25).clamp(0.0, 1.0);
      final radius = (0.7 + (i % 5) * 0.28) * (0.72 + intensity * 0.72);
      final color = i % 7 == 0 ? const Color(0xFFFF8FE8) : Colors.white;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = color.withValues(alpha: intensity),
      );
    }
  }

  void _paintNebula(Canvas canvas, Size size, double cycle) {
    final center = Offset(size.width * 0.73, size.height * 0.33);
    final nebulaSize = math.max(size.width, size.height) * 0.64;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(cycle * math.pi * 2);
    canvas.translate(-center.dx, -center.dy);

    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final offset =
          Offset(math.cos(angle), math.sin(angle) * 0.56) * nebulaSize * 0.17;
      final rect = Rect.fromCenter(
        center: center + offset,
        width: nebulaSize * (0.88 - i * 0.11),
        height: nebulaSize * (0.28 - i * 0.026),
      );
      canvas.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              const Color(0xFFB571FF).withValues(alpha: 0.20),
              const Color(0xFF4E9DFF).withValues(alpha: 0.075),
              Colors.transparent,
            ],
            stops: const <double>[0, 0.45, 1],
          ).createShader(rect),
      );
    }
    canvas.restore();
  }

  void _paintShootingStars(Canvas canvas, Size size, double seconds) {
    const burstInterval = 11.0;
    const burstLength = 1.15;
    final burstNumber = (seconds / burstInterval).floor();
    final progress = (seconds % burstInterval) / burstLength;
    if (progress > 1) return;

    for (var i = 0; i < 2; i++) {
      final seed = burstNumber * 19.37 + i * 7.91;
      final start = Offset(
        size.width * (0.06 + _unitNoise(seed) * 0.68),
        size.height * (0.08 + _unitNoise(seed + 4.2) * 0.58),
      );
      final direction = Offset(
        size.width * (0.16 + _unitNoise(seed + 9.1) * 0.14),
        size.height * (0.07 + _unitNoise(seed + 2.8) * 0.10),
      );
      final head = start + direction * progress;
      final tail = head - direction * 0.30;
      final fade = math.sin(progress * math.pi).clamp(0.0, 1.0);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: <Color>[
            Colors.transparent,
            const Color(0xFF9DFBFF).withValues(alpha: fade * 0.45),
            Colors.white.withValues(alpha: fade),
          ],
        ).createShader(Rect.fromPoints(tail, head))
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(tail, head, paint);
      canvas.drawCircle(
        head,
        1.7 + fade * 1.7,
        Paint()..color = Colors.white.withValues(alpha: fade),
      );
    }
  }

  double _unitNoise(double value) =>
      (math.sin(value * 12.9898) * 43758.5453).abs() % 1;

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) => false;
}
