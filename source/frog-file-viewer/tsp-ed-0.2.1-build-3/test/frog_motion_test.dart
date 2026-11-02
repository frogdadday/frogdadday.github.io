import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/widgets/frog_motion.dart';

void main() {
  test('Converter-style slow blink closes, holds then reopens', () {
    expect(FrogIdleMotion.slowBlink(0), 0);
    expect(FrogIdleMotion.slowBlink(0.70), closeTo(1, 0.001));
    expect(FrogIdleMotion.slowBlink(1.10), 1);
    expect(FrogIdleMotion.slowBlink(2.05), closeTo(0, 0.001));
  });

  test('three-second random reaction choice yields expressive poses', () {
    final idle = FrogIdleMotion(random: math.Random(9));
    for (var i = 0; i < 200; i++) {
      idle.advance(0.04);
      expect(idle.pose.blink, inInclusiveRange(0.0, 1.0));
      expect(idle.pose.squishX, inInclusiveRange(1.0, 1.1));
      expect(idle.pose.squishY, inInclusiveRange(0.9, 1.0));
      expect(idle.pose.tilt.abs(), lessThanOrEqualTo(0.25));
    }
  });

  test('Converter head tilt and squish recover their neutral shapes', () {
    expect(FrogIdleMotion.reactionPose(1, 1).tilt, closeTo(0.25, 0.001));
    expect(FrogIdleMotion.reactionPose(1, 2).tilt, closeTo(0, 0.001));
    expect(FrogIdleMotion.reactionPose(2, 0.15).squishX, closeTo(1.1, 0.001));
    expect(FrogIdleMotion.reactionPose(2, 0.30).squishY, closeTo(1.0, 0.001));
    expect(FrogIdleMotion.reactionPose(4, 0.1).winkLeft, isTrue);
    expect(FrogIdleMotion.reactionPose(4, 1).winkLeft, isFalse);
  });

  test('at-bottom puddle expression blinks twice', () {
    expect(FrogIdleMotion.puddleBlink(0), 0);
    expect(FrogIdleMotion.puddleBlink(0.65), greaterThan(0.8));
    expect(FrogIdleMotion.puddleBlink(1.40), greaterThan(0.8));
    expect(FrogIdleMotion.puddleBlink(2.4), 0);
  });
}
