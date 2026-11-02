import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/cosmic/cosmic_motion.dart';

void main() {
  test('heart emerges, holds around three seconds, dissolves and reappears', () {
    final motion = CosmicMotion(random: math.Random(7));
    expect(motion.heartInterval, inInclusiveRange(20.0, 30.0));
    expect(motion.heart, 0.0);

    var peakHeartTicks = 0;
    var completedHearts = 0;
    var previousPhase = motion.heartPhase;
    for (var i = 0; i < 9500; i++) {
      motion.advance(0.04);
      if (motion.heartPhase == 2) peakHeartTicks++;
      if (motion.heartPhase == 0 && previousPhase == 3) completedHearts++;
      previousPhase = motion.heartPhase;
      expect(motion.heart, inInclusiveRange(0.0, 1.0));
    }
    expect(completedHearts, greaterThan(5));
    expect(peakHeartTicks * 0.04, closeTo((completedHearts + 1) * 3.0, 3.0));
  });

  test('fully formed heart holds for three seconds to the nearest frame', () {
    final motion = CosmicMotion(random: math.Random(21));
    const delta = 0.01;
    var holdFrames = 0;
    var enteredHold = false;
    for (var i = 0; i < 10000; i++) {
      motion.advance(delta);
      if (motion.heartPhase == 2) {
        enteredHold = true;
        holdFrames++;
        expect(motion.heart, 1.0);
      } else if (enteredHold) {
        break;
      }
    }
    expect(enteredHold, isTrue);
    expect(holdFrames * delta, closeTo(3.0, 0.02));
  });

  test('melting is independently timed and returns to original shape', () {
    final motion = CosmicMotion(random: math.Random(19));
    var puddles = 0;
    var recovered = 0;
    var oldPhase = 0;
    for (var i = 0; i < 5500; i++) {
      motion.advance(0.04);
      if (motion.frogPhase == 2 && oldPhase == 1) puddles++;
      if (motion.frogPhase == 0 && oldPhase == 3) {
        recovered++;
        expect(motion.melt, closeTo(0.0, 0.0001));
      }
      expect(motion.melt, inInclusiveRange(0.0, 1.0));
      oldPhase = motion.frogPhase;
    }
    expect(puddles, greaterThan(2));
    expect(recovered, greaterThan(2));
  });

  test('random color currents change their destinations, without resets', () {
    final motion = CosmicMotion(random: math.Random(313));
    final first = (motion.blobs.first.x, motion.blobs.first.y);
    motion.advance(8.0);
    final second = (motion.blobs.first.x, motion.blobs.first.y);
    motion.advance(80.0);
    final third = (motion.blobs.first.x, motion.blobs.first.y);
    expect(second, isNot(first));
    expect(third, isNot(second));
    expect(third, isNot(first));
  });

  test('ignores negative or nonfinite time jumps', () {
    final motion = CosmicMotion(random: math.Random(11));
    motion.advance(-3);
    motion.advance(double.nan);
    motion.advance(double.infinity);
    expect(motion.seconds, 0);
    expect(motion.heart, 0);
    expect(motion.melt, 0);
  });
}
