import 'dart:math' as math;

/// Idle expressions ported from Cosmic Converter's FrogWidget / FrogPainter:
/// 3-second randomized reaction choices, 0.7/0.65/0.7s slow blink,
/// 2-second tilt, 0.3-second squish, and 1-second blink or left wink.
///
/// This reuses Converter's behavior and eye-geometry, keeping the PDF app's
/// own tie-dye silhouette, without additional accessories.
class FrogPose {
  const FrogPose({
    this.blink = 0,
    this.winkLeft = false,
    this.tilt = 0,
    this.squishX = 1,
    this.squishY = 1,
  });

  final double blink;
  final bool winkLeft;
  final double tilt;
  final double squishX;
  final double squishY;
}

class FrogIdleMotion {
  FrogIdleMotion({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;
  double _untilReaction = 3;
  double _reactionTime = 0;
  int _choice = -1;
  FrogPose pose = const FrogPose();

  static double _ease(double t) {
    final v = t.clamp(0.0, 1.0).toDouble();
    return v * v * (3 - 2 * v);
  }

  /// Maps Converter's slow 700ms close, 650ms hold, 700ms reopen to a
  /// smooth fractional eyelid closure, without allocating an animation.
  static double slowBlink(double elapsed) {
    if (elapsed < 0) return 0;
    if (elapsed < 0.70) return _ease(elapsed / 0.70);
    if (elapsed < 1.35) return 1;
    if (elapsed < 2.05) return 1 - _ease((elapsed - 1.35) / 0.70);
    return 0;
  }

  /// Exactly two deliberate, slow Converter-style blinks during the
  /// five-second full-puddle hold. Each blink fully closes, pauses briefly,
  /// then opens; the eyes otherwise remain visibly open in the goo.
  static double puddleBlink(double elapsed) {
    final first = slowBlink(elapsed - 0.15);
    final second = slowBlink(elapsed - 2.72);
    return math.max(first, second);
  }

  static FrogPose reactionPose(int choice, double elapsed) {
    switch (choice) {
      case 0:
        return FrogPose(blink: slowBlink(elapsed));
      case 1:
        final inRamp = _ease(elapsed / 0.24);
        final outRamp = 1 - _ease((elapsed - 1.75) / 0.25);
        return FrogPose(tilt: 0.25 * math.min(inRamp, outRamp));
      case 2:
        final wave = math.sin(math.pi * (elapsed / 0.30).clamp(0.0, 1.0));
        return FrogPose(squishX: 1 + 0.10 * wave, squishY: 1 - 0.10 * wave);
      case 3:
        return FrogPose(blink: math.sin(math.pi * (elapsed / 1).clamp(0.0, 1.0)));
      case 4:
        return FrogPose(winkLeft: elapsed < 1);
      default:
        return const FrogPose();
    }
  }

  static double reactionDuration(int choice) => switch (choice) {
    0 => 2.05,
    1 => 2.0,
    2 => 0.30,
    3 => 1.0,
    4 => 1.0,
    _ => 0,
  };

  void advance(double deltaSeconds) {
    if (!deltaSeconds.isFinite || deltaSeconds <= 0) return;
    // The normal Converter idle loop chooses a fresh random expression
    // roughly every three seconds. No canned repeating animation sequence.
    var dt = deltaSeconds;
    while (dt > 0) {
      final chunk = math.min(dt, _untilReaction);
      dt -= chunk;
      _untilReaction -= chunk;
      _reactionTime += chunk;
      if (_untilReaction <= 0.00000001) {
        _choice = _random.nextInt(5);
        _reactionTime = 0;
        _untilReaction = 3;
      }
    }
    pose = _reactionTime <= reactionDuration(_choice)
        ? reactionPose(_choice, _reactionTime)
        : const FrogPose();
  }
}
