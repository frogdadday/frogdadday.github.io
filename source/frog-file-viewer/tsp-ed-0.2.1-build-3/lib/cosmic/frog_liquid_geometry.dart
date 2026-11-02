import 'dart:math' as math;
import 'dart:ui' show Offset;

/// One continuous liquefaction of Frogdadday's **existing** home mascot.
/// No translated or strip-stretched sprite: the body erodes from the lower
/// edge while independent teardrops transfer its color to the puddle.
class FrogLiquidGeometry {
  const FrogLiquidGeometry._();

  static const int dropCount = 24;
  static const double puddleHoldSeconds = 5.0;

  /// Apply the *exact same* rotate-and-squish transform as the cached frog
  /// body to an attached eye position. Eyes must follow the head during its
  /// idle tilt; their independent fall starts only after they detach.
  static Offset attachedEyePosition(
    Offset restingEye, {
    required Offset bodyCenter,
    required double tilt,
    required double squishX,
    required double squishY,
    required double strength,
  }) {
    final x = (restingEye.dx - bodyCenter.dx) *
        (1 + (squishX - 1) * strength);
    final y = (restingEye.dy - bodyCenter.dy) *
        (1 + (squishY - 1) * strength);
    final angle = tilt * strength;
    final c = math.cos(angle);
    final si = math.sin(angle);
    return Offset(
      bodyCenter.dx + x * c - y * si,
      bodyCenter.dy + x * si + y * c,
    );
  }

  static double clamp01(double x) => x.clamp(0.0, 1.0).toDouble();

  static double smooth(double x) {
    final t = clamp01(x);
    return t * t * (3 - 2 * t);
  }

  /// 1 while solid, eventually 0 while completely liquefied. The body stays
  /// at its home position: it does not travel down the screen intact.
  static double bodyRemaining(double melt) =>
      1.0 - smooth((melt - 0.035) / 0.835);

  /// The **two eyes never dissolve**: only in the last part of the melt do
  /// they fall into the puddle. During reassembly they return *late*, after
  /// the dyed body has already begun to rebuild.
  static double eyesAtPuddle(double melt, {required bool reforming}) =>
      reforming
          ? smooth((melt - 0.08) / 0.21)
          : smooth((melt - 0.84) / 0.16);

  /// Drops detach at staggered points throughout the overall 11-14-second
  /// melting phase. Each has a separate, normal-speed fall; the long overall
  /// duration does not slow the drops themselves.
  static double releaseFraction(int index) =>
      0.075 + 0.79 * ((index + 0.40) / dropCount);

  static double scatter(int index, double salt) {
    final n = math.sin((index + 1) * 97.33 + salt * 19.17) * 43758.5453;
    return n - n.floorToDouble();
  }

  /// Physical-looking acceleration; travel is about 0.65-1.15 seconds even
  /// though the *body's* transformation takes over ten seconds.
  static double fallDuration(int index) =>
      0.65 + scatter(index, 7.0) * 0.50;

  static double fallProgress(double elapsed, double duration) {
    if (duration <= 0) return 1;
    final t = clamp01(elapsed / duration);
    return t * t * (2.0 - t);
  }

  /// A drop's normalized progress during its falling flight; null when not
  /// flying. Rendered analytically: no mutable particles or frame-rate drift.
  static double? fallingDrop(
    int index,
    double phaseSeconds,
    double phaseDuration,
  ) {
    final elapsed = phaseSeconds - releaseFraction(index) * phaseDuration;
    if (elapsed < 0 || elapsed >= fallDuration(index)) return null;
    return fallProgress(elapsed, fallDuration(index));
  }

  /// Reverse-process droplet reabsorption starts at the puddle, not as an
  /// intact frog sprite rising from the bottom.
  static double? risingDrop(
    int index,
    double phaseSeconds,
    double phaseDuration,
  ) {
    final release = 0.08 + 0.75 * ((dropCount - index - 0.5) / dropCount);
    final elapsed = phaseSeconds - release * phaseDuration;
    final duration = fallDuration(index);
    if (elapsed < 0 || elapsed >= duration) return null;
    return smooth(elapsed / duration);
  }

  /// Progress-dependent, staggered accumulation. Puddle width/height follows
  /// the missing body mass instead of being an unrelated static graphic.
  static double poolMass(double melt) => smooth((melt - 0.09) / 0.88);
}
