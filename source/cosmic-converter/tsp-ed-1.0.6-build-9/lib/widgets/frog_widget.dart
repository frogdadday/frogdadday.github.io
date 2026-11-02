//Block ONE /////////////////////////////////////////////////////

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

import 'frog_painter.dart';
import 'frog_heat_death.dart';

class FrogWidget extends StatefulWidget {
  final bool cosmicMode;
  final VoidCallback? onSpecialReactionStarted;
  final VoidCallback? onSpecialReactionEnded;

  const FrogWidget({
    super.key,
    required this.cosmicMode,
    this.onSpecialReactionStarted,
    this.onSpecialReactionEnded,
  });

  @override
  FrogWidgetState createState() => FrogWidgetState();
}

class FrogWidgetState extends State<FrogWidget> with TickerProviderStateMixin {
  // ------------------------------------------------------------
  // Painter state
  // ------------------------------------------------------------
  bool eyesClosed = false;
  bool winkLeft = false;
  bool lightning = false;
  late AnimationController lightningController;
  bool reactionFlash = false;
  bool isFrozen = false;

  // Idle animation channels
  double headTilt = 0.0;
  double squishX = 1.0;
  double squishY = 1.0;
  double slowBlink = 0.0;

  // Shimmer animation
  late AnimationController shimmerController;
  double shimmerValue = 0.0;

  // Slow blink animation
  late AnimationController slowBlinkController;

  // Heat-death dissolution animation
  late AnimationController heatDeathController;
  double heatDeathProgress = 0.0;
  int? _heatDeathRunId;

  // Idle loop (keeps frog alive)
  Timer? _idleTimer;
  final Random _rng = Random();

  // ------------------------------------------------------------
  // Idle/reaction coordination
  // ------------------------------------------------------------
  bool _idleLoopPaused = false;
  bool _isReacting = false;

  // Invalidates old delayed reaction callbacks.
  int _reactionRunId = 0;

  // Invalidates old delayed idle-expression callbacks.
  int _idleExpressionRunId = 0;

  // ------------------------------------------------------------
  // Pause/resume controls for the idle loop
  // ------------------------------------------------------------
  void pauseIdleLoop() {
    _idleLoopPaused = true;
    stopIdleLoop();
  }

  void resumeIdleLoop() {
    _idleLoopPaused = false;

    if (!_isReacting) {
      startIdleLoop();
    }
  }

  // ------------------------------------------------------------
  // Reaction tracking
  // ------------------------------------------------------------
  int beginReaction() {
    _reactionRunId++;
    _isReacting = true;
    widget.onSpecialReactionStarted?.call();

    stopIdleLoop();
    cancelIdleExpressions();

    slowBlinkController.stop();
    slowBlinkController.reset();

    // Clear any interrupted idle pose before the special reaction begins.
    eyesClosed = false;
    winkLeft = false;
    headTilt = 0.0;
    squishX = 1.0;
    squishY = 1.0;
    slowBlink = 0.0;

    return _reactionRunId;
  }

  bool isReactionValid(int runId) {
    return mounted && _isReacting && runId == _reactionRunId;
  }

  void endReaction(int runId) {
    if (!mounted || runId != _reactionRunId) return;

    _isReacting = false;
    widget.onSpecialReactionEnded?.call();

    if (!_idleLoopPaused) {
      startIdleLoop();
    }
  }

  void cancelReactions() {
    final wasReacting = _isReacting;
    _reactionRunId++;
    _isReacting = false;

    if (wasReacting) {
      widget.onSpecialReactionEnded?.call();
    }
  }

  // ------------------------------------------------------------
  // Idle expression tracking
  // ------------------------------------------------------------
  int beginIdleExpression() {
    _idleExpressionRunId++;
    return _idleExpressionRunId;
  }

  bool isIdleExpressionValid(int runId) {
    return mounted && !_isReacting && runId == _idleExpressionRunId;
  }

  void cancelIdleExpressions() {
    _idleExpressionRunId++;
  }

  // ------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    // Shimmer loop
    shimmerController =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..addListener(() {
            if (mounted && widget.cosmicMode) {
              setState(() {
                shimmerValue = shimmerController.value;
              });
            }
          });

    if (widget.cosmicMode) {
      shimmerController.repeat();
    }

    // Slow blink controller
    slowBlinkController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 450),
        )..addListener(() {
          if (!mounted) return;

          setState(() {
            slowBlink = slowBlinkController.value;
          });
        });

    heatDeathController =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..addListener(() {
            if (!mounted) return;

            setState(() {
              heatDeathProgress = heatDeathController.value;
            });
          });

    lightningController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2200),
        )..addListener(() {
          if (mounted) setState(() {});
        });

    // Idle animation loop always on
    startIdleLoop();
  }

  @override
  void didUpdateWidget(covariant FrogWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only run shimmer while Cosmic Mode is actually active.
    if (widget.cosmicMode != oldWidget.cosmicMode) {
      if (widget.cosmicMode) {
        shimmerController.repeat();
      } else {
        shimmerController.stop();
      }
    }
  }

  @override
  void dispose() {
    stopIdleLoop();
    shimmerController.dispose();
    slowBlinkController.dispose();
    heatDeathController.dispose();
    lightningController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // Idle Animation Engine (keeps frog alive)
  // ------------------------------------------------------------
  void startIdleLoop() {
    _idleTimer?.cancel();
    _idleTimer = null;

    if (_idleLoopPaused || _isReacting) return;

    _idleTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _tickIdle();
    });
  }

  void stopIdleLoop() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  void _tickIdle() {
    if (!mounted || _idleLoopPaused || _isReacting) return;

    final choice = _rng.nextInt(5);

    switch (choice) {
      case 0:
        triggerSlowBlink();
        break;

      case 1:
        triggerHeadTilt();
        break;

      case 2:
        // Squish
        final int runId = beginIdleExpression();

        setState(() {
          squishX = 1.1;
          squishY = 0.9;
        });

        Future.delayed(const Duration(milliseconds: 300), () {
          if (!isIdleExpressionValid(runId)) return;

          setState(() {
            squishX = 1.0;
            squishY = 1.0;
          });
        });
        break;

      case 3:
        triggerIdleBlink();
        break;

      case 4:
        triggerIdleWink();
        break;
    }
  }

  // Block TWO//////////////////////////////////////////////////////////
  // Public Reaction Methods
  // ------------------------------------------------------------

  Future<bool> _waitForReaction(Duration duration, int runId) async {
    await Future.delayed(duration);
    return isReactionValid(runId);
  }

  void triggerDoubleBlink() async {
    if (!mounted) return;

    final int runId = beginReaction();

    // First exaggerated blink
    setState(() => eyesClosed = true);

    if (!await _waitForReaction(const Duration(milliseconds: 750), runId)) {
      return;
    }

    setState(() => eyesClosed = false);

    // Deliberate pause between blinks
    if (!await _waitForReaction(const Duration(milliseconds: 550), runId)) {
      return;
    }

    // Second blink hangs just a little longer
    setState(() => eyesClosed = true);

    if (!await _waitForReaction(const Duration(milliseconds: 1000), runId)) {
      return;
    }

    setState(() => eyesClosed = false);

    endReaction(runId);
  }

  void triggerNeutralBlink({
    Duration duration = const Duration(milliseconds: 500),
  }) async {
    if (!mounted) return;

    final int runId = beginReaction();

    setState(() => eyesClosed = true);

    // A noticeably deliberate normal blink
    if (!await _waitForReaction(duration, runId)) return;

    setState(() => eyesClosed = false);

    endReaction(runId);
  }

  void triggerWink() async {
    if (!mounted) return;

    final int runId = beginReaction();

    setState(() => winkLeft = true);

    // Hold the wink long enough to make it obvious
    if (!await _waitForReaction(const Duration(milliseconds: 1500), runId)) {
      return;
    }

    setState(() => winkLeft = false);

    endReaction(runId);
  }

  void triggerLightning() async {
    if (!mounted) return;

    final int runId = beginReaction();

    setState(() => lightning = true);
    lightningController.forward(from: 0);

    if (!await _waitForReaction(const Duration(milliseconds: 2200), runId)) {
      return;
    }

    setState(() => lightning = false);

    endReaction(runId);
  }

  void triggerFreezeBlink(Duration duration) async {
    if (!mounted) return;

    final int runId = beginReaction();

    setState(() {
      isFrozen = true;
      eyesClosed = true;
    });

    if (!await _waitForReaction(duration, runId)) return;

    setState(() {
      isFrozen = false;
      eyesClosed = false;
    });

    endReaction(runId);
  }

  void triggerFlash({
    Duration duration = const Duration(milliseconds: 300),
  }) async {
    if (!mounted) return;

    final int runId = beginReaction();

    setState(() => reactionFlash = true);

    if (!await _waitForReaction(duration, runId)) return;

    setState(() => reactionFlash = false);

    endReaction(runId);
  }

  void triggerHeatDeath() async {
    if (!mounted) return;

    final int runId = beginReaction();
    _heatDeathRunId = runId;

    heatDeathController.stop();
    heatDeathController.reset();

    setState(() => heatDeathProgress = 0.0);

    try {
      await heatDeathController.forward(from: 0.0).orCancel;
    } catch (_) {
      return;
    }

    // Deliberately remain dissolved until the dialog is dismissed.
  }

  void endHeatDeath() {
    if (!mounted) return;

    final runId = _heatDeathRunId;
    _heatDeathRunId = null;

    heatDeathController.stop();
    heatDeathController.reset();

    setState(() => heatDeathProgress = 0.0);

    if (runId != null) {
      endReaction(runId);
    }
  }

  void setCosmicMode(bool enabled) {
    if (!mounted) return;

    if (enabled) {
      shimmerController.repeat();
    } else {
      shimmerController.stop();
    }

    setState(() {});
  }

  void setFrozen(bool frozen) {
    if (!mounted) return;

    if (frozen) {
      widget.onSpecialReactionStarted?.call();
      pauseIdleLoop();
      cancelIdleExpressions();
    } else {
      resumeIdleLoop();
      widget.onSpecialReactionEnded?.call();
    }

    setState(() => isFrozen = frozen);
  }

  void neutralize() {
    if (!mounted) return;

    // Kill any delayed reaction or idle-expression callbacks
    // that may still be waiting to run.
    cancelReactions();
    lightningController.reset();
    cancelIdleExpressions();

    slowBlinkController.stop();
    slowBlinkController.reset();
    heatDeathController.stop();
    heatDeathController.reset();
    _heatDeathRunId = null;

    setState(() {
      eyesClosed = false;
      winkLeft = false;
      lightning = false;
      reactionFlash = false;
      isFrozen = false;

      headTilt = 0.0;
      squishX = 1.0;
      squishY = 1.0;
      slowBlink = 0.0;
      heatDeathProgress = 0.0;
    });

    if (!_idleLoopPaused) {
      startIdleLoop();
    }
  }

  // ------------------------------------------------------------
  // Idle Expression Helpers (called by FrogIdleAnimator)
  // ------------------------------------------------------------
  void triggerIdleBlink() async {
    if (!mounted || _isReacting) return;

    final int runId = beginIdleExpression();

    setState(() => eyesClosed = true);

    await Future.delayed(const Duration(seconds: 1));

    if (!isIdleExpressionValid(runId)) return;

    setState(() => eyesClosed = false);
  }

  void triggerIdleWink() async {
    if (!mounted || _isReacting) return;

    final int runId = beginIdleExpression();

    setState(() => winkLeft = true);

    await Future.delayed(const Duration(seconds: 1));

    if (!isIdleExpressionValid(runId)) return;

    setState(() => winkLeft = false);
  }

  void triggerHeadTilt() async {
    if (!mounted || _isReacting) return;

    final int runId = beginIdleExpression();

    setState(() => headTilt = 0.25);

    await Future.delayed(const Duration(seconds: 2));

    if (!isIdleExpressionValid(runId)) return;

    setState(() => headTilt = 0.0);
  }

  void triggerSlowBlink() async {
    if (!mounted || _isReacting) return;

    final int runId = beginIdleExpression();

    // ------------------------------------------------------------
    // Slowly CLOSE the eyelids
    // ------------------------------------------------------------
    try {
      await slowBlinkController
          .animateTo(
            1.0,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
          )
          .orCancel;
    } catch (_) {
      return;
    }

    if (!isIdleExpressionValid(runId)) return;

    // ------------------------------------------------------------
    // Hold the fully closed expression
    // ------------------------------------------------------------
    await Future.delayed(const Duration(milliseconds: 650));

    if (!isIdleExpressionValid(runId)) return;

    // ------------------------------------------------------------
    // Slowly OPEN the eyelids
    // ------------------------------------------------------------
    try {
      await slowBlinkController
          .animateBack(
            0.0,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
          )
          .orCancel;
    } catch (_) {
      return;
    }
  }

  void resetIdleExpressions() {
    if (!mounted) return;

    cancelIdleExpressions();

    slowBlinkController.stop();
    slowBlinkController.reset();

    setState(() {
      headTilt = 0.0;
      squishX = 1.0;
      squishY = 1.0;
      slowBlink = 0.0;
    });
  }

  // ------------------------------------------------------------
  // Build
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return FrogHeatDeath(
      progress: heatDeathProgress,
      child: CustomPaint(
        painter: FrogPainter(
          eyesClosed: eyesClosed,
          winkLeft: winkLeft,
          lightning: lightning,
          lightningProgress: lightningController.value,
          cosmicMode: widget.cosmicMode,
          reactionFlash: reactionFlash,
          isFrozen: isFrozen,
          shimmerValue: shimmerValue,
          headTilt: headTilt,
          squishX: squishX,
          squishY: squishY,
          slowBlink: slowBlink,
        ),
        size: const Size(40, 40),
      ),
    );
  }
}
