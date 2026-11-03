// /////Block One/////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

class ConstellationTitle extends StatelessWidget {
  const ConstellationTitle({super.key, this.height = 38});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Cosmic Chores',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: height * 5.65,
          child: const CustomPaint(painter: _ConstellationTitlePainter()),
        ),
      ),
    );
  }
}

// /////Block Two/////////////////////////////////////////////////////////////
class _ConstellationTitlePainter extends CustomPainter {
  const _ConstellationTitlePainter();

  static const String _title = 'COSMIC CHORES';
  static const Map<String, List<String>> _glyphs = <String, List<String>>{
    'A': <String>[
      '01110',
      '10001',
      '10001',
      '11111',
      '10001',
      '10001',
      '10001',
    ],
    'C': <String>[
      '01111',
      '10000',
      '10000',
      '10000',
      '10000',
      '10000',
      '01111',
    ],
    'E': <String>[
      '11111',
      '10000',
      '10000',
      '11110',
      '10000',
      '10000',
      '11111',
    ],
    'H': <String>[
      '10001',
      '10001',
      '10001',
      '11111',
      '10001',
      '10001',
      '10001',
    ],
    'I': <String>[
      '11111',
      '00100',
      '00100',
      '00100',
      '00100',
      '00100',
      '11111',
    ],
    'M': <String>[
      '10001',
      '11011',
      '10101',
      '10101',
      '10001',
      '10001',
      '10001',
    ],
    'O': <String>[
      '01110',
      '10001',
      '10001',
      '10001',
      '10001',
      '10001',
      '01110',
    ],
    'R': <String>[
      '11110',
      '10001',
      '10001',
      '11110',
      '10100',
      '10010',
      '10001',
    ],
    'S': <String>[
      '01111',
      '10000',
      '10000',
      '01110',
      '00001',
      '00001',
      '11110',
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    const columnsPerGlyph = 6;
    const spaceColumns = 3;
    final columnCount = _title.runes.fold<int>(
      0,
      (total, rune) =>
          total +
          (String.fromCharCode(rune) == ' ' ? spaceColumns : columnsPerGlyph),
    );
    final cell = (size.width / columnCount).clamp(1.4, size.height / 7);
    final contentWidth = columnCount * cell;
    final origin = Offset(
      (size.width - contentWidth) / 2,
      (size.height - 7 * cell) / 2,
    );
    final linePaint = Paint()
      ..color = const Color(0xFF9CCBFF).withValues(alpha: 0.34)
      ..strokeWidth = (cell * 0.22).clamp(0.55, 1.25)
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..color = const Color(0xFFB9DAFF).withValues(alpha: 0.24)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.72);
    final starPaint = Paint()..color = const Color(0xFFF8FCFF);

    var startColumn = 0;
    for (final rune in _title.runes) {
      final character = String.fromCharCode(rune);
      if (character == ' ') {
        startColumn += spaceColumns;
        continue;
      }
      final glyph = _glyphs[character]!;
      for (var row = 0; row < 7; row++) {
        for (var column = 0; column < 5; column++) {
          if (glyph[row][column] != '1') continue;
          final center = Offset(
            origin.dx + (startColumn + column + 0.5) * cell,
            origin.dy + (row + 0.5) * cell,
          );
          if (column < 4 && glyph[row][column + 1] == '1') {
            canvas.drawLine(center, center.translate(cell, 0), linePaint);
          }
          if (row < 6 && glyph[row + 1][column] == '1') {
            canvas.drawLine(center, center.translate(0, cell), linePaint);
          }
          canvas.drawCircle(center, cell * 0.34, glowPaint);
          canvas.drawCircle(center, (cell * 0.14).clamp(0.65, 1.4), starPaint);
        }
      }
      startColumn += columnsPerGlyph;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
