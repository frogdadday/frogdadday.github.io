// There is ONLY One Block Here /////////////////////////////////////////////

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// An intentionally excessive animated rainbow title for Cosmic Mode.
class CosmicRainbowTitle extends StatefulWidget {
  final String text;
  final bool enabled;

  const CosmicRainbowTitle({
    super.key,
    required this.text,
    required this.enabled,
  });

  @override
  State<CosmicRainbowTitle> createState() => _CosmicRainbowTitleState();
}

class _CosmicRainbowTitleState extends State<CosmicRainbowTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _animationsDisabled = false;

  static const _titleStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.35,
    color: Colors.white,
    shadows: [
      Shadow(color: Colors.white, blurRadius: 2),
      Shadow(color: Color(0xFFFF00FF), blurRadius: 9),
      Shadow(color: Color(0xFF00FFFF), blurRadius: 15),
      Shadow(color: Color(0xFFFFF000), blurRadius: 22),
    ],
  );

  static const _rainbow = [
    Color(0xFFFF1744),
    Color(0xFFFF6D00),
    Color(0xFFFFFF00),
    Color(0xFF00FF66),
    Color(0xFF00E5FF),
    Color(0xFF2979FF),
    Color(0xFFAA00FF),
    Color(0xFFFF00E5),
    Color(0xFFFF1744),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _animationsDisabled = MediaQuery.disableAnimationsOf(context);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant CosmicRainbowTitle oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.enabled != widget.enabled) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.enabled && !_animationsDisabled) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      return;
    }

    _controller.stop();
    if (!widget.enabled) {
      _controller.value = 0.0;
    } else if (_animationsDisabled) {
      // Preserve the rainbow appearance when reduced motion is requested.
      _controller.value = 0.15;
    }
  }

  Widget _buildRainbowTitle() {
    return RepaintBoundary(
      key: const ValueKey("rainbow-title"),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          final pulse = 1.0 + (0.025 * math.sin(progress * 4 * math.pi));

          return Transform.scale(
            scale: pulse,
            alignment: Alignment.centerLeft,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: _rainbow,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  tileMode: TileMode.mirror,
                  transform: GradientRotation(progress * 2 * math.pi),
                ).createShader(bounds);
              },
              child: child,
            ),
          );
        },
        child: Text(
          widget.text,
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: _titleStyle,
        ),
      ),
    );
  }

  Widget _buildTealTitle() {
    return Text(
      widget.text,
      key: const ValueKey("teal-title"),
      maxLines: 1,
      overflow: TextOverflow.visible,
      style: const TextStyle(
        fontSize: 24,
        color: Colors.tealAccent,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: widget.enabled ? _buildRainbowTitle() : _buildTealTitle(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
