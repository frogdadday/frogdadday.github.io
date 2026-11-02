import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/cosmic/cosmic_motion.dart';
import 'package:frog_file_viewer/cosmic/frog_liquid_geometry.dart';
import 'package:frog_file_viewer/widgets/frog_motion.dart';

void main() {
  test('liquid schedule has a five-second full puddle hold', () {
    final motion = CosmicMotion(random: math.Random(8));
    var phaseChanges = 0;
    var last = motion.frogPhase;
    var holdStarted = 0.0;
    var holdDuration = 0.0;
    for (var i = 0; i < 2500; i++) {
      motion.advance(0.04);
      if (motion.frogPhase != last) {
        phaseChanges++;
        if (motion.frogPhase == 2) {
          holdStarted = motion.seconds;
          expect(motion.frogPhaseDuration, 5);
          expect(motion.melt, closeTo(1, 0.000001));
        }
        if (last == 2) {
          holdDuration = motion.seconds - holdStarted;
          break;
        }
        last = motion.frogPhase;
      }
    }
    expect(phaseChanges, greaterThanOrEqualTo(3));
    expect(holdDuration, closeTo(5, 0.05));
  });

  test('two full eye blinks separated across five seconds in the goo', () {
    // The eyes stay open at the beginning and end of the puddle phase.
    expect(FrogIdleMotion.puddleBlink(0), 0);
    expect(FrogIdleMotion.puddleBlink(5), 0);
    var blinkPeaks = 0;
    var blinkingBefore = false;
    for (var i = 0; i <= 500; i++) {
      final blink = FrogIdleMotion.puddleBlink(i / 100);
      expect(blink, inInclusiveRange(0.0, 1.0));
      final closed = blink > 0.99;
      if (closed && !blinkingBefore) blinkPeaks++;
      blinkingBefore = closed;
    }
    expect(blinkPeaks, 2);
    expect(FrogIdleMotion.puddleBlink(1.15), greaterThan(0.99));
    expect(FrogIdleMotion.puddleBlink(3.7), greaterThan(0.99));
  });

  test('body loses mass while eyes remain solid until near the end', () {
    expect(FrogLiquidGeometry.bodyRemaining(0), closeTo(1, 1e-8));
    expect(FrogLiquidGeometry.bodyRemaining(0.5), lessThan(0.6));
    expect(FrogLiquidGeometry.bodyRemaining(0.9), closeTo(0, 1e-8));
    expect(FrogLiquidGeometry.eyesAtPuddle(0.5, reforming: false), 0);
    expect(FrogLiquidGeometry.eyesAtPuddle(1, reforming: false), 1);
    expect(FrogLiquidGeometry.eyesAtPuddle(1, reforming: true), 1);
    expect(FrogLiquidGeometry.eyesAtPuddle(0, reforming: true), 0);
  });

  test('24 teardrops have staggered release points and normal fall speed', () {
    expect(FrogLiquidGeometry.dropCount, 24);
    for (var i = 0; i < FrogLiquidGeometry.dropCount; i++) {
      final release = FrogLiquidGeometry.releaseFraction(i);
      expect(release, inInclusiveRange(0.0, 1.0));
      expect(FrogLiquidGeometry.fallDuration(i), inInclusiveRange(0.65, 1.15));
      if (i > 0) {
        expect(release, greaterThan(FrogLiquidGeometry.releaseFraction(i - 1)));
      }
    }
    final duration = 12.0;
    final release = FrogLiquidGeometry.releaseFraction(3) * duration;
    expect(FrogLiquidGeometry.fallingDrop(3, release - 0.1, duration), isNull);
    expect(FrogLiquidGeometry.fallingDrop(3, release + 0.3, duration),
        inInclusiveRange(0.0, 1.0));
    expect(FrogLiquidGeometry.fallingDrop(
        3, release + FrogLiquidGeometry.fallDuration(3) + 0.01, duration), isNull);
  });
}
