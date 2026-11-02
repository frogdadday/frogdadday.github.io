import 'dart:math' as math;

import '../widgets/frog_motion.dart';

/// Independent, non-looping motion schedules for Cosmic Mode.
///
/// Shape changes use gentle easing. Color currents choose fresh destinations
/// continuously, so the backdrop never jumps back to frame zero.
class CosmicMotion {
  CosmicMotion({math.Random? random}) : _random = random ?? math.Random() {
    blobs = List<CosmicBlob>.generate(8, (index) {
      return CosmicBlob(_random, index);
    });
    _heartDuration = _between(20, 30);
    _frogDuration = _between(14, 22);
  }

  final math.Random _random;
  late final List<CosmicBlob> blobs;
  final FrogIdleMotion frogIdle = FrogIdleMotion();

  double seconds = 0;
  double heart = 0;
  double melt = 0;

  int _heartPhase = 0; // abstract, forming, holding, dissolving
  double _heartClock = 0;
  late double _heartDuration;

  int _frogPhase = 0; // normal, melting, puddled, reforming
  double _frogClock = 0;
  late double _frogDuration;

  double get heartInterval => _heartDuration;
  int get heartPhase => _heartPhase;
  int get frogPhase => _frogPhase;
  double get frogPhaseElapsed => _frogClock;
  double get frogPhaseDuration => _frogDuration;

  double _between(double min, double max) =>
      min + _random.nextDouble() * (max - min);

  static double _ease(double value) {
    final t = value.clamp(0.0, 1.0).toDouble();
    return t * t * (3 - 2 * t);
  }

  void advance(double deltaSeconds) {
    if (!deltaSeconds.isFinite || deltaSeconds <= 0) return;
    seconds += deltaSeconds;
    frogIdle.advance(deltaSeconds);
    for (final blob in blobs) {
      blob.advance(deltaSeconds, _random);
    }

    _heartClock += deltaSeconds;
    while (_heartClock >= _heartDuration) {
      _heartClock -= _heartDuration;
      _heartPhase = (_heartPhase + 1) % 4;
      _heartDuration = switch (_heartPhase) {
        0 => _between(20, 30),
        1 => _between(4, 6),
        2 => 3.0, // Fully formed drawn heart holds one extra second.
        _ => _between(4, 6),
      };
    }
    final heartPosition = _ease(_heartClock / _heartDuration);
    heart = switch (_heartPhase) {
      0 => 0.0,
      1 => heartPosition,
      2 => 1.0,
      _ => 1.0 - heartPosition,
    };

    _frogClock += deltaSeconds;
    while (_frogClock >= _frogDuration) {
      _frogClock -= _frogDuration;
      _frogPhase = (_frogPhase + 1) % 4;
      _frogDuration = switch (_frogPhase) {
        0 => _between(14, 22),
        1 => _between(11, 14),
        2 => 5.0, // Exactly five seconds with two distinct puddle blinks.
        _ => _between(9, 12),
      };
    }
    final frogPosition = _ease(_frogClock / _frogDuration);
    melt = switch (_frogPhase) {
      0 => 0.0,
      1 => frogPosition,
      2 => 1.0,
      _ => 1.0 - frogPosition,
    };
  }
}

/// Mutable, smoothly interpolated lava current. Each arrival picks a new
/// stochastic target and duration rather than repeating a baked animation.
class CosmicBlob {
  CosmicBlob(math.Random random, this.index)
    : x = random.nextDouble(),
      y = random.nextDouble(),
      radius = 0.20 + random.nextDouble() * 0.26 {
    _fromX = x;
    _fromY = y;
    _fromRadius = radius;
    _next(random);
  }

  final int index;
  double x;
  double y;
  double radius;

  late double _fromX;
  late double _fromY;
  late double _fromRadius;
  late double _targetX;
  late double _targetY;
  late double _targetRadius;
  double _elapsed = 0;
  double _duration = 1;

  void _next(math.Random random) {
    _targetX = random.nextDouble();
    _targetY = random.nextDouble();
    _targetRadius = 0.20 + random.nextDouble() * 0.26;
    _duration = 7 + random.nextDouble() * 13;
  }

  void advance(double deltaSeconds, math.Random random) {
    _elapsed += deltaSeconds;
    while (_elapsed >= _duration) {
      _elapsed -= _duration;
      x = _targetX;
      y = _targetY;
      radius = _targetRadius;
      _fromX = x;
      _fromY = y;
      _fromRadius = radius;
      _next(random);
    }
    final t = _elapsed / _duration;
    final eased = t * t * (3 - 2 * t);
    x = _fromX + (_targetX - _fromX) * eased;
    y = _fromY + (_targetY - _fromY) * eased;
    radius = _fromRadius + (_targetRadius - _fromRadius) * eased;
  }
}
