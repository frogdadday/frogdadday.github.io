// ////Block One//////////////////////////////////////////////////////////////
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/spinner_model.dart';

class SpinnerWheel extends StatelessWidget {
  const SpinnerWheel({
    super.key,
    required this.spinner,
    this.rotation = 0,
    this.winningIndex,
    this.showLabels = true,
  });

  final SpinnerModel spinner;
  final double rotation;
  final int? winningIndex;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '${spinner.title} wheel with ${spinner.slices.length} choices',
      child: AspectRatio(
        aspectRatio: 1,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: SpinnerWheelPainter(
              spinner: spinner,
              rotation: rotation,
              winningIndex: winningIndex,
              showLabels: showLabels,
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            ),
          ),
        ),
      ),
    );
  }
}

// ////Block Two//////////////////////////////////////////////////////////////
class SpinnerWheelPainter extends CustomPainter {
  const SpinnerWheelPainter({
    required this.spinner,
    required this.rotation,
    this.fontFamily,
    this.winningIndex,
    this.showLabels = true,
  });

  static const radiusFraction = 0.475;

  final String? fontFamily;

  final SpinnerModel spinner;
  final double rotation;
  final int? winningIndex;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * radiusFraction;
    final wheelRect = Rect.fromCircle(center: center, radius: radius);
    final count = spinner.slices.length;
    final sweep = math.pi * 2 / count;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    for (var i = 0; i < count; i++) {
      final start = -math.pi / 2 + i * sweep;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(wheelRect, start, sweep, false)
        ..close();
      canvas.drawPath(path, Paint()..color = spinner.sliceColor(i));
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.5, radius * 0.018)
          ..strokeJoin = StrokeJoin.round,
      );
      if (showLabels) {
        _drawLabel(
          canvas,
          center,
          radius,
          start + sweep / 2,
          count >= 12
              ? (radius < 110 ? '${i + 1}' : '${i + 1}. ${spinner.slices[i]}')
              : spinner.slices[i],
          count,
          spinner.sliceTextColor(i),
        );
      }
    }
    // Paint after all wedges so neighboring borders cannot cover the highlight.
    final winner = winningIndex;
    if (winner != null && winner >= 0 && winner < count) {
      final outline = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(wheelRect, -math.pi / 2 + winner * sweep, sweep, false)
        ..close();
      canvas.drawPath(
        outline,
        Paint()
          ..color = const Color(0xFFFFDC45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(3.5, radius * 0.025)
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.restore();

    canvas.drawCircle(
      center,
      radius * 0.095,
      Paint()..color = const Color(0xFF07111F),
    );
    canvas.drawCircle(
      center,
      radius * 0.095,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(center, radius * 0.035, Paint()..color = Colors.white70);
  }

  void _drawLabel(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    String rawLabel,
    int count,
    Color textColor,
  ) {
    final label = rawLabel.trim().isEmpty ? '(blank)' : rawLabel.trim();
    final dense = count >= 12;
    final compact = dense && radius < 110;
    final fontSize = compact
        ? (radius * 0.18).clamp(5.0, 14.0)
        : dense
        ? (radius * 0.085).clamp(11.0, 16.0)
        : (radius * (count <= 6 ? 0.105 : 0.085)).clamp(10.0, 18.0);
    final painter =
        TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontFamily: fontFamily,
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              shadows: <Shadow>[
                Shadow(
                  color: textColor == Colors.black
                      ? Colors.white38
                      : Colors.black54,
                  blurRadius: 1,
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
          textAlign: TextAlign.center,
        )..layout(
          maxWidth:
              radius *
              (compact
                  ? 0.30
                  : dense
                  ? 0.52
                  : 0.67),
        );

    // Narrow wedges have more room for taller text away from the hub.
    final labelRadius =
        radius *
        (compact
            ? 0.72
            : dense
            ? 0.66
            : 0.60);
    final position = Offset(
      center.dx + math.cos(angle) * labelRadius,
      center.dy + math.sin(angle) * labelRadius,
    );
    // All labels read from the center toward the rim and rotate with the wheel.
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(angle);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SpinnerWheelPainter oldDelegate) {
    return oldDelegate.spinner != spinner ||
        oldDelegate.rotation != rotation ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.winningIndex != winningIndex ||
        oldDelegate.fontFamily != fontFamily;
  }
}
