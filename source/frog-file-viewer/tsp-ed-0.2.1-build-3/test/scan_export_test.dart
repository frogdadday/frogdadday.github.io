import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/services/scan_export_service.dart';
import 'package:image/image.dart' as img;

void main() {
  Uint8List samplePng({int width = 80, int height = 120}) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(245, 245, 245));
    return Uint8List.fromList(img.encodePng(image));
  }

  test('scanner prepares JPEG pages entirely in memory', () {
    final prepared = ScanExportService.preparePage(samplePng());
    expect(prepared, isNotEmpty);
    expect(prepared[0], 0xff);
    expect(prepared[1], 0xd8);
    final decoded = img.decodeJpg(prepared)!;
    expect(decoded.width, 80);
    expect(decoded.height, 120);
  });

  test('scanner rotation swaps page dimensions', () {
    final prepared = ScanExportService.preparePage(samplePng());
    final rotated = ScanExportService.rotateClockwise(prepared);
    final decoded = img.decodeJpg(rotated)!;
    expect(decoded.width, 120);
    expect(decoded.height, 80);
  });

  test('single scan exports PNG', () {
    final prepared = ScanExportService.preparePage(samplePng());
    final png = ScanExportService.asPng(prepared);
    expect(img.decodePng(png), isNotNull);
  });

  test('two scanned pages become one PDF', () async {
    final first = ScanExportService.preparePage(samplePng());
    final second = ScanExportService.preparePage(
      samplePng(width: 110, height: 75),
    );
    final pdf = await ScanExportService.asPdf([first, second]);
    expect(ascii.decode(pdf.take(5).toList()), '%PDF-');
    expect(pdf.length, greaterThan(500));
  });

  test('scanner rejects invalid images and empty PDF batches', () async {
    expect(
      () => ScanExportService.preparePage(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    await expectLater(
      ScanExportService.asPdf([]),
      throwsFormatException,
    );
  });

  test('scanner limits large page batches', () async {
    final page = ScanExportService.preparePage(samplePng());
    await expectLater(
      ScanExportService.asPdf(List.filled(31, page)),
      throwsFormatException,
    );
  });
}
