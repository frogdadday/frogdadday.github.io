import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/cosmic/cosmic_painters.dart';
import 'package:frog_file_viewer/cosmic/frog_liquid_geometry.dart';
import 'package:frog_file_viewer/widgets/frog_motion.dart';

void main() {
  test('attached eyes follow the exact body rotation about the same pivot', () {
    const center = Offset(50, 50);
    const leftEye = Offset(34, 29);
    const rightEye = Offset(66, 29);
    const tilt = math.pi / 2;

    const positions = [leftEye, rightEye];
    for (final resting in positions) {
      final eye = FrogLiquidGeometry.attachedEyePosition(
        resting,
        bodyCenter: center,
        tilt: tilt,
        squishX: 1,
        squishY: 1,
        strength: 1,
      );
      // A 90-degree tilt about (50,50) maps (dx,dy) to (-dy,dx).
      expect(eye.dx, closeTo(center.dx - (resting.dy - center.dy), 1e-8));
      expect(eye.dy, closeTo(center.dy + (resting.dx - center.dx), 1e-8));
    }

    final left = FrogLiquidGeometry.attachedEyePosition(
      leftEye,
      bodyCenter: center,
      tilt: tilt,
      squishX: 1,
      squishY: 1,
      strength: 1,
    );
    final right = FrogLiquidGeometry.attachedEyePosition(
      rightEye,
      bodyCenter: center,
      tilt: tilt,
      squishX: 1,
      squishY: 1,
      strength: 1,
    );
    // Rotating the frog's face must rotate the line between the two eyes.
    expect(right.dx - left.dx, closeTo(0, 1e-8));
    expect(right.dy - left.dy, closeTo(32, 1e-8));
  });

  test('eyes match both the resting position and the body squish', () {
    const center = Offset(50, 50);
    const eye = Offset(34, 29);

    final noPose = FrogLiquidGeometry.attachedEyePosition(
      eye,
      bodyCenter: center,
      tilt: 0.25,
      squishX: 1.3,
      squishY: 0.7,
      strength: 0,
    );
    expect(noPose, eye);

    final squished = FrogLiquidGeometry.attachedEyePosition(
      eye,
      bodyCenter: center,
      tilt: 0,
      squishX: 1.3,
      squishY: 0.7,
      strength: 1,
    );
    expect(squished.dx, closeTo(29.2, 1e-8));
    expect(squished.dy, closeTo(35.3, 1e-8));
  });

  test('Converter idle tilt applies smoothly to both cosmic eye centers', () {
    final tiltPose = FrogIdleMotion.reactionPose(1, 1.0);
    expect(tiltPose.tilt, greaterThan(0));
    const center = Offset(44, 44);
    const eyes = [Offset(29.92, 25.52), Offset(58.08, 25.52)];
    for (final eye in eyes) {
      final transformed = FrogLiquidGeometry.attachedEyePosition(
        eye,
        bodyCenter: center,
        tilt: tiltPose.tilt,
        squishX: tiltPose.squishX,
        squishY: tiltPose.squishY,
        strength: 1,
      );
      expect(transformed, isNot(eye));
    }
  });

  test('Cosmic title has visible, smooth but bounded psychedelic motion', () {
    var biggestVertical = 0.0;
    var biggestRotation = 0.0;
    var smallestStretch = 2.0;
    var biggestStretch = 0.0;
    var biggestShear = 0.0;
    for (var step = 0; step < 800; step++) {
      final t = step * 0.1;
      final pose = CosmicTitlePainter.glyphPose(t, 5);
      biggestVertical = math.max(biggestVertical, pose.dy.abs());
      biggestRotation = math.max(biggestRotation, pose.rotation.abs());
      smallestStretch = math.min(smallestStretch, pose.scaleX);
      biggestStretch = math.max(biggestStretch, pose.scaleX);
      biggestShear = math.max(biggestShear, pose.skewX.abs());

      expect(pose.dy.abs(), lessThanOrEqualTo(5.31));
      expect(pose.rotation.abs(), lessThanOrEqualTo(0.096));
      expect(pose.scaleX, inInclusiveRange(0.88, 1.12));
      expect(pose.scaleY, inInclusiveRange(0.86, 1.14));
    }
    expect(biggestVertical, greaterThan(5));
    expect(biggestRotation, greaterThan(0.09));
    expect(smallestStretch, lessThan(0.90));
    expect(biggestStretch, greaterThan(1.10));
    expect(biggestShear, greaterThan(0.04));
  });
}
