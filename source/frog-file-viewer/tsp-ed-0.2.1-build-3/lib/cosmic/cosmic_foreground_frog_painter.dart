import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../widgets/frog_motion.dart';
import '../widgets/tie_dye_frog.dart';
import 'cosmic_motion.dart';
import 'frog_liquid_geometry.dart';

/// Foreground-only liquid version of the little home-screen mascot.
///
/// His body *stays at its original location* and erodes from the bottom
/// upwards; it does not squash into moving horizontal strips. A staggered
/// series of real teardrops falls into a growing goo puddle. His two intact
/// eyes are the last to fall and blink twice during the five-second hold.
/// All timing and positions are deterministic from [CosmicMotion].
class CosmicForegroundFrogPainter extends CustomPainter {
  CosmicForegroundFrogPainter({
    required this.motion,
    required this.frogBody,
    required this.anchorKey,
    required this.canvasKey,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final CosmicMotion motion;
  final ui.Image? frogBody;
  final GlobalKey anchorKey;
  final GlobalKey canvasKey;

  static const _dye = <Color>[
    Color(0xFFFF4938),
    Color(0xFFFFA42A),
    Color(0xFFFFE04A),
    Color(0xFF3FC66F),
    Color(0xFF38CCE5),
    Color(0xFF426AE9),
    Color(0xFF9C56DF),
    Color(0xFFED62C8),
  ];

  RenderBox? _activeBox(GlobalKey key) {
    try {
      final context = key.currentContext;
      if (context == null || !context.mounted) return null;
      final object = context.findRenderObject();
      return object is RenderBox && object.attached && object.hasSize
          ? object
          : null;
    } on FlutterError {
      // Switching off Cosmic Mode may temporarily deactivate either key.
      return null;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final anchor = _activeBox(anchorKey);
    final foreground = _activeBox(canvasKey);
    if (anchor == null || foreground == null) return;

    final origin =
        anchor.localToGlobal(Offset.zero) - foreground.localToGlobal(Offset.zero);
    final side = math.min(anchor.size.width, anchor.size.height);
    if (side <= 0) return;

    final home = Rect.fromLTWH(
      origin.dx + (anchor.size.width - side) / 2,
      origin.dy + (anchor.size.height - side) / 2,
      side,
      side,
    );
    final phase = motion.frogPhase;
    final melt = motion.melt.clamp(0.0, 1.0).toDouble();
    final remaining = FrogLiquidGeometry.bodyRemaining(melt);
    final poolAmount = FrogLiquidGeometry.poolMass(melt);
    final poolPosition = Offset(
      size.width / 2,
      math.max(home.top + side, size.height - 16),
    );
    final seconds = motion.frogPhaseElapsed;

    // Mass transferred from the original body gives the puddle its volume.
    if (poolAmount > 0.003) {
      _paintPuddle(canvas, poolPosition, side, poolAmount, motion.seconds);
    }

    // Keep the colorful body at its ORIGINAL location. Erode its lower edge
    // until no dyed mass remains; never translate the whole frog down.
    if (remaining > 0.002) {
      _paintErodingBody(canvas, home, remaining, melt, motion.seconds);
    }

    if (phase == 1 || phase == 3) {
      for (var i = 0; i < FrogLiquidGeometry.dropCount; i++) {
        final progress = phase == 1
            ? FrogLiquidGeometry.fallingDrop(
                i, seconds, motion.frogPhaseDuration)
            : FrogLiquidGeometry.risingDrop(
                i, seconds, motion.frogPhaseDuration);
        if (progress == null) continue;

        final fraction = FrogLiquidGeometry.releaseFraction(i);
        final start = Offset(
          home.left + side *
              (0.15 + 0.70 * FrogLiquidGeometry.scatter(i, 1)),
          home.top + side *
              (0.10 + 0.80 *
                  FrogLiquidGeometry.bodyRemaining(fraction)),
        );
        final end = Offset(
          poolPosition.dx + side *
              0.66 * (FrogLiquidGeometry.scatter(i, 3) - 0.5),
          poolPosition.dy - side * 0.12,
        );
        final travel = phase == 1 ? progress : 1 - progress;
        final position = Offset.lerp(start, end, travel)!;
        final radius = side *
            (0.033 + 0.043 * FrogLiquidGeometry.scatter(i, 2));
        _paintTeardrop(
          canvas,
          position,
          radius,
          _dye[i % _dye.length],
          pointUp: phase == 1,
        );
      }

      // Small rounded beads form and detach from the dissolving edge.
      // They are deliberately wider than a "paper streamer".
      if (remaining > 0.10 && remaining < 0.97) {
        for (var i = 0; i < 3; i++) {
          final swell = 0.7 +
              0.3 * math.sin(seconds * 2.2 + i * 2.1).abs();
          _paintTeardrop(
            canvas,
            Offset(
              home.left + side * (0.27 + i * 0.23),
              home.top + side * (0.06 + 0.94 * remaining) +
                  side * 0.020 * swell,
            ),
            side * (0.020 + 0.015 * swell),
            _dye[(i + 3) % _dye.length],
            pointUp: true,
          );
        }
      }
    }

    // Intact eyes are independent of the colorful body. They fall *last*,
    // land in the goo, blink there, and move home during late reassembly.
    for (var eye = 0; eye < 2; eye++) {
      final idle = motion.frogIdle.pose;
      final strength = 1 - melt * 0.80;
      final restingEye = Offset(
        home.left + side * (eye == 0 ? 0.34 : 0.66),
        home.top + side * 0.29,
      );
      // The body raster tilts and squishes about home.center. Until each
      // eye falls into the puddle, its center must undergo *the same matrix*.
      // Otherwise the eyes appear to detach during a regular idle head tilt.
      final start = FrogLiquidGeometry.attachedEyePosition(
        restingEye,
        bodyCenter: home.center,
        tilt: idle.tilt,
        squishX: idle.squishX,
        squishY: idle.squishY,
        strength: strength,
      );
      final end = Offset(
        poolPosition.dx + side * (eye == 0 ? -0.20 : 0.20),
        poolPosition.dy - side * 0.16,
      );
      final eyeMelt =
          (melt + (eye == 0 ? 0.012 : -0.012)).clamp(0.0, 1.0).toDouble();
      final atBottom = phase == 2
          ? 1.0
          : phase == 0
              ? 0.0
              : FrogLiquidGeometry.eyesAtPuddle(
                  eyeMelt, reforming: phase == 3);
      final center = Offset.lerp(
        start,
        end,
        FrogLiquidGeometry.fallProgress(atBottom, 1),
      )!;
      final blink = phase == 2
          ? FrogIdleMotion.puddleBlink(seconds)
          : idle.blink;
      // Rotate/squish the eye itself too, so its pupil and highlight
      // share the body's pose. Ease to an upright eye as it detaches.
      final attached = 1.0 - atBottom;
      final eyeStrength = strength * attached;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(idle.tilt * eyeStrength);
      canvas.scale(
        1 + (idle.squishX - 1) * eyeStrength,
        1 + (idle.squishY - 1) * eyeStrength,
      );
      canvas.translate(-center.dx, -center.dy);
      TieDyeFrogPainter.drawIntactEye(
        canvas,
        center,
        side * 0.15,
        phase == 0 && eye == 0 && idle.winkLeft ? 1.0 : blink,
      );
      canvas.restore();
    }
  }

  void _paintErodingBody(
    Canvas canvas,
    Rect home,
    double remaining,
    double melt,
    double seconds,
  ) {
    final boundary = home.top + home.height * (0.06 + 0.94 * remaining);
    final path = Path()
      ..moveTo(home.left - 2, home.top - 2)
      ..lineTo(home.right + 2, home.top - 2)
      ..lineTo(home.right + 2, boundary);

    // Smooth scallops soften the retreating lower edge. The raster itself
    // is never stretched or divided into horizontal strips.
    for (var i = 20; i >= 0; i--) {
      final fraction = i / 20;
      final wave = math.sin(fraction * 18.3 + seconds * 1.3) +
          0.45 * math.sin(fraction * 31.0 - seconds * 0.7);
      final extent =
          home.height * 0.016 * math.sin(math.pi * remaining);
      path.lineTo(
        home.left + fraction * home.width,
        boundary + extent * wave,
      );
    }
    path
      ..lineTo(home.left - 2, boundary)
      ..close();
    canvas.save();

    // Retain Converter's normal idle tilt/squish while the body is solid.
    // Apply this pose before clipping: the liquefaction edge must rotate
    // with the body instead of chopping off a tilted head at a fixed box.
    final idle = motion.frogIdle.pose;
    final strength = 1 - melt * 0.80;
    canvas.translate(home.center.dx, home.center.dy);
    canvas.rotate(idle.tilt * strength);
    canvas.scale(
      1 + (idle.squishX - 1) * strength,
      1 + (idle.squishY - 1) * strength,
    );
    canvas.translate(-home.center.dx, -home.center.dy);
    canvas.clipPath(path);

    if (frogBody != null) {
      canvas.drawImageRect(
        frogBody!,
        Rect.fromLTWH(
          0, 0,
          frogBody!.width.toDouble(),
          frogBody!.height.toDouble(),
        ),
        home,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      // Safe fallback while the cached body raster is being prepared.
      canvas.save();
      canvas.translate(home.left, home.top);
      canvas.scale(home.width / 320, home.height / 320);
      const TieDyeFrogPainter(
        cosmicMode: true,
        drawEyes: false,
      ).paint(canvas, const Size(320, 320));
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintPuddle(
    Canvas canvas,
    Offset center,
    double side,
    double amount,
    double seconds,
  ) {
    final spread = FrogLiquidGeometry.smooth(amount);
    final width = side * (0.30 + 1.50 * spread);
    final height = side * (0.04 + 0.25 * spread);
    final edge = Rect.fromCenter(
      center: center,
      width: width,
      height: height,
    );

    final fill = Paint()
      ..shader = ui.Gradient.linear(
        edge.centerLeft,
        edge.centerRight,
        [
          _dye[6].withValues(alpha: 0.58 + 0.38 * spread),
          _dye[7],
          _dye[2],
          _dye[3],
          _dye[4],
        ],
        const [0.0, 0.25, 0.5, 0.75, 1.0],
      );

    // A low, rounded, gently wobbling pool made of two overlapping lobes,
    // not a flat line or a frog-shaped translated sprite.
    canvas.drawOval(edge, fill);
    canvas.drawOval(
      Rect.fromCenter(
        center: edge.center.translate(
          side * 0.035 * math.sin(seconds * 0.65),
          -height * 0.08,
        ),
        width: width * 0.78,
        height: height * 0.82,
      ),
      Paint()
        ..color = _dye[7].withValues(alpha: 0.20 * spread),
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: center.translate(-side * 0.15, -height * 0.11),
        width: width * 0.54,
        height: height * 0.40,
      ),
      math.pi * 1.12,
      math.pi * 0.72,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, side * 0.018)
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.23 * spread),
    );
  }

  void _paintTeardrop(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, {
    required bool pointUp,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (!pointUp) canvas.rotate(math.pi);

    // Rounded base and a softly pinched tip. There are no thin
    // streamer-lines or drawn tails behind the falling drop.
    final shape = Path()
      ..moveTo(0, -radius * 2.1)
      ..cubicTo(
        radius * 0.23, -radius * 1.34,
        radius * 1.02, -radius * 0.66,
        radius * 1.03, radius * 0.06,
      )
      ..cubicTo(
        radius * 1.04, radius * 1.33,
        -radius * 1.04, radius * 1.33,
        -radius * 1.03, radius * 0.06,
      )
      ..cubicTo(
        -radius * 1.02, -radius * 0.66,
        -radius * 0.23, -radius * 1.34,
        0, -radius * 2.1,
      )
      ..close();

    canvas.drawPath(shape, Paint()..color = color);
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.5, radius * 0.12)
        ..color = const Color(0xA8221537),
    );
    canvas.drawOval(
      Rect.fromLTWH(
        -radius * 0.48,
        -radius * 0.26,
        radius * 0.26,
        radius * 0.70,
      ),
      Paint()..color = const Color(0x77FFFFFF),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CosmicForegroundFrogPainter oldDelegate) =>
      oldDelegate.motion != motion ||
      oldDelegate.frogBody != frogBody ||
      oldDelegate.anchorKey != anchorKey ||
      oldDelegate.canvasKey != canvasKey;
}
