//Block ONE/////////////////////////////////////////////////////////////

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'frog_widget.dart'; // add this import

class FrogIdleAnimator extends StatefulWidget {
  final Widget child;
  final GlobalKey<FrogWidgetState> frogKey; // type it correctly

  const FrogIdleAnimator({
    super.key,
    required this.child,
    required this.frogKey,
  });

  @override
  FrogIdleAnimatorState createState() => FrogIdleAnimatorState();
}

class FrogIdleAnimatorState extends State<FrogIdleAnimator>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ------------------------------------------------------------
  // Idle timer
  // ------------------------------------------------------------
  Timer? _idleTimer;
  static const Duration _idleDuration = Duration(seconds: 15);

  // ------------------------------------------------------------
  // Animation controllers
  // ------------------------------------------------------------
  late AnimationController _positionController; // arc motion
  late AnimationController _scaleController; // 1.0 → 5.0
  late AnimationController _anticipationController; // squish + tilt
  late AnimationController _blinkController; // slow 3-second blink

  // ------------------------------------------------------------
  // Animation values
  // ------------------------------------------------------------
  double _horizontalOffset = 0.0; // animated movement toward screen center
  double _verticalOffset = 0.0; // animated downward movement
  double _scale = 1.0; // animated scale
  bool _isAnimating = false; // prevents overlapping sequences

  // Current position animations used by the single controller listener
  Animation<double>? _horizontalPositionAnimation;
  Animation<double>? _positionAnimation;

  // Changes whenever an animation sequence is cancelled or replaced.
  // Async steps use this to know whether they are still valid.
  int _animationRunId = 0;

  // Tracks whether the app is currently active.
  bool _isAppActive = true;

  // Prevents the large idle animation from overlapping a frog reaction.
  bool _pausedForSpecialReaction = false;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();

    // Watch app lifecycle so idle behavior pauses in the background.
    WidgetsBinding.instance.addObserver(this);

    // Watch pointer activity anywhere in the app.
    GestureBinding.instance.pointerRouter.addGlobalRoute(
      _handleGlobalPointerEvent,
    );

    // Position controller (arc motion)
    _positionController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 500),
        )..addListener(() {
          if (!mounted || _positionAnimation == null) return;

          setState(() {
            _horizontalOffset = _horizontalPositionAnimation?.value ?? 0.0;
            _verticalOffset = _positionAnimation!.value;
          });
        });

    // Scale controller (1.0 → 5.0)
    _scaleController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 500),
          lowerBound: 1.0,
          upperBound: 5.0,
        )..addListener(() {
          if (!mounted) return;

          setState(() {
            _scale = _scaleController.value;
          });
        });

    // Anticipation controller (squish + head tilt)
    _anticipationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    // Slow blink controller (3 seconds)
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _startIdleTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion && _isAnimating) _interruptAnimation();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();

    GestureBinding.instance.pointerRouter.removeGlobalRoute(
      _handleGlobalPointerEvent,
    );

    WidgetsBinding.instance.removeObserver(this);

    _positionController.dispose();
    _scaleController.dispose();
    _anticipationController.dispose();
    _blinkController.dispose();

    super.dispose();
  }

  // ------------------------------------------------------------
  // App lifecycle handling
  // ------------------------------------------------------------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppActive = true;
      _startIdleTimer();
      return;
    }

    _isAppActive = false;
    _idleTimer?.cancel();

    if (_isAnimating) {
      _interruptAnimation();
    }
  }

  // ------------------------------------------------------------
  // Global user interaction
  // ------------------------------------------------------------
  void _handleGlobalPointerEvent(PointerEvent event) {
    if (event is! PointerDownEvent) return;
    if (!_isAppActive) return;
    if (_pausedForSpecialReaction) return;

    if (_isAnimating) {
      _interruptAnimation();
    } else {
      _resetIdleTimer();
    }
  }

  // ------------------------------------------------------------
  // Special frog reaction coordination
  // ------------------------------------------------------------
  void pauseForSpecialReaction() {
    if (_pausedForSpecialReaction) return;

    _pausedForSpecialReaction = true;
    _idleTimer?.cancel();
    _idleTimer = null;

    if (_isAnimating) {
      _interruptAnimation();
    }
  }

  void resumeAfterSpecialReaction() {
    if (!_pausedForSpecialReaction) return;

    _pausedForSpecialReaction = false;

    if (_isAppActive) {
      _startIdleTimer();
    }
  }

  // ------------------------------------------------------------
  // Animation run tracking
  // ------------------------------------------------------------
  int _beginAnimationRun() {
    _animationRunId++;
    return _animationRunId;
  }

  void _cancelAnimationRun() {
    _animationRunId++;
  }

  bool _isAnimationRunValid(int runId) {
    return mounted &&
        _isAppActive &&
        !_pausedForSpecialReaction &&
        _isAnimating &&
        runId == _animationRunId;
  }

  // ------------------------------------------------------------
  // Idle timer logic
  // ------------------------------------------------------------
  void _startIdleTimer() {
    _idleTimer?.cancel();

    if (!_isAppActive || _pausedForSpecialReaction || _reducedMotion) return;

    _idleTimer = Timer(_idleDuration, _triggerIdleAnimation);
  }

  void _resetIdleTimer() {
    if (_isAnimating) return; // active animation is interrupted elsewhere
    _startIdleTimer();
  }

  // Block TWO/////////////////////////////////////////////////////////

  // ------------------------------------------------------------
  // Cancellation-aware delay helper
  // ------------------------------------------------------------
  Future<bool> _waitForAnimation(Duration duration, int runId) async {
    await Future.delayed(duration);
    return _isAnimationRunValid(runId);
  }

  // ------------------------------------------------------------
  // Idle animation sequence
  // ------------------------------------------------------------
  Future<void> _triggerIdleAnimation() async {
    if (_isAnimating || !_isAppActive || _pausedForSpecialReaction) return;

    _isAnimating = true;
    final int runId = _beginAnimationRun();

    // Pause frog's internal idle loop
    widget.frogKey.currentState?.pauseIdleLoop();

    // 1. Anticipation: squish + head tilt
    _anticipationController.forward(from: 0.0);

    if (widget.frogKey.currentState != null &&
        widget.frogKey.currentState!.mounted) {
      widget.frogKey.currentState?.triggerHeadTilt();
    }

    if (!await _waitForAnimation(const Duration(milliseconds: 180), runId)) {
      return;
    }

    if (!mounted) {
      return;
    }

    // 2. Launch: arc motion + scale up
    final screenSize = MediaQuery.sizeOf(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    final initialCenterX = renderBox == null
        ? 0.0
        : renderBox.localToGlobal(Offset(renderBox.size.width / 2, 0)).dx;
    final double centerLanding = (screenSize.width / 2) - initialCenterX;
    final initialCenterY = renderBox == null
        ? 0.0
        : renderBox.localToGlobal(Offset(0, renderBox.size.height / 2)).dy;
    final insets = MediaQuery.of(context);
    // Keep the 200px frog above the footer, keyboard and navigation area.
    final bottomInset = insets.viewInsets.bottom > insets.viewPadding.bottom
        ? insets.viewInsets.bottom
        : insets.viewPadding.bottom;
    final double bottomLanding =
        (screenSize.height - bottomInset - 180 - initialCenterY)
            .clamp(0.0, screenSize.height)
            .toDouble();

    _horizontalPositionAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: centerLanding * 0.12,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: centerLanding * 0.12,
          end: centerLanding,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 80,
      ),
    ]).animate(_positionController);

    _positionAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: -20.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -20.0,
          end: bottomLanding,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 80,
      ),
    ]).animate(_positionController);

    try {
      await Future.wait([
        _positionController.forward(from: 0.0).orCancel,
        _scaleController.forward(from: 1.0).orCancel,
      ]);
    } catch (_) {
      return;
    }

    if (!_isAnimationRunValid(runId)) return;

    // 3. Landing squash
    if (!await _waitForAnimation(const Duration(milliseconds: 120), runId)) {
      return;
    }

    // 4. Slow 3-second blink + head tilt on reopen
    _blinkController.forward(from: 0.0);

    if (widget.frogKey.currentState != null &&
        widget.frogKey.currentState!.mounted) {
      widget.frogKey.currentState?.triggerSlowBlink();
    }

    if (!await _waitForAnimation(const Duration(seconds: 3), runId)) {
      return;
    }

    // 5. Return: arc motion back up + shrink
    _horizontalPositionAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween(
          begin: centerLanding,
          end: centerLanding * 0.88,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: centerLanding * 0.88,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 80,
      ),
    ]).animate(_positionController);

    _positionAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween(
          begin: bottomLanding,
          end: bottomLanding - 20,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: bottomLanding - 20,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 80,
      ),
    ]).animate(_positionController);

    try {
      await Future.wait([
        _positionController.forward(from: 0.0).orCancel,
        _scaleController.reverse().orCancel,
      ]);
    } catch (_) {
      return;
    }

    if (!_isAnimationRunValid(runId)) return;

    // 6. Reset everything
    widget.frogKey.currentState?.resetIdleExpressions();

    // Resume frog's internal idle loop
    widget.frogKey.currentState?.resumeIdleLoop();

    _horizontalPositionAnimation = null;
    _positionAnimation = null;

    if (mounted) {
      setState(() {
        _horizontalOffset = 0.0;
        _verticalOffset = 0.0;
        _scale = 1.0;
      });
    }

    _isAnimating = false;
    _startIdleTimer();
  }

  // ------------------------------------------------------------
  // Interrupt logic
  // ------------------------------------------------------------
  void _interruptAnimation() {
    if (!_isAnimating) {
      _resetIdleTimer();
      return;
    }

    // Invalidate any async steps still waiting.
    _cancelAnimationRun();
    _isAnimating = false;

    // Stop active animation controllers.
    _positionController.stop();
    _scaleController.stop();
    _anticipationController.stop();
    _blinkController.stop();

    // Remove the active arc before resetting the controller
    // so its listener cannot briefly move the frog again.
    _horizontalPositionAnimation = null;
    _positionAnimation = null;

    // Return all controllers to their clean starting positions.
    _positionController.reset();
    _scaleController.reset();
    _anticipationController.reset();
    _blinkController.reset();

    widget.frogKey.currentState?.resetIdleExpressions();

    // Resume frog's internal idle loop on interrupt.
    widget.frogKey.currentState?.resumeIdleLoop();

    if (mounted) {
      setState(() {
        _horizontalOffset = 0.0;
        _verticalOffset = 0.0;
        _scale = 1.0;
      });
    }

    _startIdleTimer();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _interruptAnimation,
      onPanDown: (_) => _interruptAnimation(),
      child: Transform.translate(
        offset: Offset(_horizontalOffset, _verticalOffset),
        child: Transform.scale(
          scale: _scale,
          child: Padding(
            padding: const EdgeInsets.all(20), // ⭐ bigger hit area
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
