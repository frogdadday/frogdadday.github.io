import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/services/file_tools.dart';
import 'package:image/image.dart' as img;
import 'package:quds_office_engine/quds_office_engine.dart';

void main() {
  Uint8List samplePng() {
    final image = img.Image(width: 16, height: 12);
    img.fill(image, color: img.ColorRgb8(60, 150, 70));
    return img.encodePng(image);
  }

  Uint8List scannerPdfFromStreams(
    List<({List<int> bytes, int width, int height})> streams, {
    List<List<int>>? pageImages,
  }) {
    final mapping =
        pageImages ??
        [
          for (var i = 0; i < streams.length; i++) [i],
        ];
    final firstImageObject = 3 + mapping.length;
    final bytes = BytesBuilder(copy: false)
      ..add('%PDF-1.3\n'.codeUnits)
      ..add('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n'.codeUnits)
      ..add(
        ('2 0 obj\n<< /Type /Pages /Count ${mapping.length} /Kids ['
                '${[for (var i = 0; i < mapping.length; i++) '${3 + i} 0 R'].join(' ')}'
                '] >>\nendobj\n')
            .codeUnits,
      );
    for (var pageIndex = 0; pageIndex < mapping.length; pageIndex++) {
      final resources = [
        for (
          var imageIndex = 0;
          imageIndex < mapping[pageIndex].length;
          imageIndex++
        )
          '/Im$imageIndex ${firstImageObject + mapping[pageIndex][imageIndex]} 0 R',
      ].join(' ');
      bytes.add(
        ('${3 + pageIndex} 0 obj\n<< /Type /Page /Parent 2 0 R '
                '/MediaBox [0 0 240 160] '
                '/Resources << /XObject << $resources >> >> >>\nendobj\n')
            .codeUnits,
      );
    }
    for (var index = 0; index < streams.length; index++) {
      final stream = streams[index];
      bytes
        ..add(
          ('${firstImageObject + index} 0 obj\n<< /Subtype /Image '
                  '/Width ${stream.width} /Height ${stream.height} '
                  '/ColorSpace /DeviceRGB /BitsPerComponent 8 '
                  '/Filter [ /FlateDecode /DCTDecode ] '
                  '/Length ${stream.bytes.length} >>\nstream\n')
              .codeUnits,
        )
        ..add(stream.bytes)
        ..add('\nendstream\nendobj\n'.codeUnits);
    }
    bytes.add('%%EOF'.codeUnits);
    return bytes.takeBytes();
  }

  Uint8List flateWrappedJpegScan({int pages = 1}) {
    final streams = <({List<int> bytes, int width, int height})>[];
    for (var index = 0; index < pages; index++) {
      final image = img.Image(width: 24, height: 16);
      img.fill(
        image,
        color: img.ColorRgb8(210 - index * 20, 180, 120 + index * 20),
      );
      streams.add((
        bytes: ZLibEncoder().convert(img.encodeJpg(image)),
        width: 24,
        height: 16,
      ));
    }
    return scannerPdfFromStreams(streams);
  }

  test('filename cleaning keeps output names predictable', () {
    expect(FileTools.withoutExtension('some invoice.pdf'), 'some invoice');
    expect(FileTools.withoutExtension('a/b\\c.jpg'), 'a_b_c');
    expect(FileTools.withoutExtension('.'), 'document');
  });

  test('recognizes PDFs by signature', () {
    expect(
      FileTools.looksLikePdf(Uint8List.fromList('%PDF-1.7'.codeUnits)),
      isTrue,
    );
    expect(FileTools.looksLikePdf(samplePng()), isFalse);
  });

  test('valid header is insufficient to replace an editable PDF', () async {
    final valid = await FileTools.blankPdf();
    expect(FileTools.canOpenEditablePdf(valid), isTrue);

    final forgedHeader = Uint8List.fromList(
      '%PDF-1.7\\nThis is not an actual PDF body.'.codeUnits,
    );
    expect(FileTools.looksLikePdf(forgedHeader), isTrue);
    expect(FileTools.canOpenEditablePdf(forgedHeader), isFalse);
    expect(
      FileTools.canOpenEditablePdf(Uint8List.fromList([1, 2, 3])),
      isFalse,
    );
  });

  test('detects and rebuilds Flate-wrapped JPEG scanner PDFs', () async {
    final scan = flateWrappedJpegScan();
    expect(FileTools.needsScannedPdfCompatibilityCopy(scan), isTrue);

    final compatible = await FileTools.makeScannedPdfCompatibilityCopy(scan);
    expect(FileTools.looksLikePdf(compatible), isTrue);
    expect(PdfFile.open(compatible).pageCount, 1);
    expect(FileTools.needsScannedPdfCompatibilityCopy(compatible), isFalse);
  });

  test(
    'scanner detection tolerates PDF token whitespace and comments',
    () async {
      final baseline = flateWrappedJpegScan();
      final source = String.fromCharCodes(baseline);
      const originalFilter = '/Filter [ /FlateDecode /DCTDecode ]';
      expect(source.contains(originalFilter), isTrue);

      final variants = <String>[
        '/Filter[ /FlateDecode /DCTDecode]',
        '/Filter\r\n[\t/FlateDecode\r\n/DCTDecode ]',
        '/Filter %driver note\r\n[\n/FlateDecode %more\n/DCTDecode]',
        '/Filter\x00[ /FlateDecode /DCTDecode ]',
      ];
      for (final replacement in variants) {
        final changed = Uint8List.fromList(
          source.replaceFirst(originalFilter, replacement).codeUnits,
        );
        expect(
          FileTools.needsScannedPdfCompatibilityCopy(changed),
          isTrue,
          reason: replacement,
        );
        final compatible = await FileTools.makeScannedPdfCompatibilityCopy(
          changed,
        );
        expect(PdfFile.open(compatible).pageCount, 1, reason: replacement);
      }
    },
  );

  test('does not flatten ordinary PDFs as a compatibility copy', () async {
    final ordinary = await FileTools.blankPdf();
    expect(FileTools.needsScannedPdfCompatibilityCopy(ordinary), isFalse);
    await expectLater(
      FileTools.makeScannedPdfCompatibilityCopy(ordinary),
      throwsFormatException,
    );
  });

  test('rebuilds multipage scans in page-tree order', () async {
    final compatible = await FileTools.makeScannedPdfCompatibilityCopy(
      flateWrappedJpegScan(pages: 2),
    );
    expect(PdfFile.open(compatible).pageCount, 2);
  });

  test('rejects duplicate page-tree references before rebuilding', () async {
    final source = String.fromCharCodes(flateWrappedJpegScan());
    final duplicate = Uint8List.fromList(
      source.replaceFirst('/Kids [3 0 R]', '/Kids [3 0 R 3 0 R]').codeUnits,
    );
    await expectLater(
      FileTools.makeScannedPdfCompatibilityCopy(duplicate),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('shared or duplicate'),
        ),
      ),
    );
  });

  test('bounds oversized scanner page trees during traversal', () async {
    final source = String.fromCharCodes(
      flateWrappedJpegScan(pages: FileTools.maxScannerPages + 1),
    );
    await expectLater(
      FileTools.makeScannedPdfCompatibilityCopy(
        Uint8List.fromList(source.codeUnits),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('too many pages'),
        ),
      ),
    );
  });

  test('rejects pages with multiple scanner images as ambiguous', () async {
    final image = img.Image(width: 24, height: 16);
    img.fill(image, color: img.ColorRgb8(80, 120, 160));
    final wrapped = ZLibEncoder().convert(img.encodeJpg(image));
    final ambiguous = scannerPdfFromStreams(
      [
        (bytes: wrapped, width: 24, height: 16),
        (bytes: wrapped, width: 24, height: 16),
      ],
      pageImages: const [
        [0, 1],
      ],
    );
    await expectLater(
      FileTools.makeScannedPdfCompatibilityCopy(ambiguous),
      throwsFormatException,
    );
  });

  test('rejects malformed and over-expanding scanner streams', () async {
    final malformed = Uint8List.fromList(
      String.fromCharCodes(flateWrappedJpegScan())
          .replaceFirst('endstream', 'endstreaX')
          .codeUnits,
    );
    await expectLater(
      FileTools.makeScannedPdfCompatibilityCopy(malformed),
      throwsFormatException,
    );

    final bomb = scannerPdfFromStreams([
      (
        bytes: ZLibEncoder().convert(
          Uint8List(FileTools.maxScannerStreamBytes + 1),
        ),
        width: 1,
        height: 1,
      ),
    ]);
    await expectLater(
      FileTools.makeScannedPdfCompatibilityCopy(bomb),
      throwsFormatException,
    );
  });

  test('PNG converts to JPEG, PNG and WebP', () {
    final original = samplePng();
    final jpg = FileTools.convertImage(original, 'jpg');
    final png = FileTools.convertImage(original, 'png');
    final webp = FileTools.convertImage(original, 'webp');
    expect(jpg.take(2).toList(), [0xff, 0xd8]);
    expect(png.take(4).toList(), [0x89, 0x50, 0x4e, 0x47]);
    expect(String.fromCharCodes(webp.sublist(0, 4)), 'RIFF');
  });

  test('JPEG conversion flattens transparent pixels onto white', () {
    final transparent = img.Image(width: 4, height: 4, numChannels: 4);
    img.fill(transparent, color: img.ColorRgba8(20, 40, 60, 0));
    final jpeg = FileTools.convertImage(img.encodePng(transparent), 'jpg');
    final decoded = img.decodeJpg(jpeg)!;
    final pixel = decoded.getPixel(0, 0);
    expect(pixel.r, greaterThan(240));
    expect(pixel.g, greaterThan(240));
    expect(pixel.b, greaterThan(240));
  });

  test('image conversion bakes EXIF orientation into output pixels', () {
    final oriented = img.Image(width: 3, height: 2);
    img.fill(oriented, color: img.ColorRgb8(100, 140, 180));
    oriented.exif.imageIfd.orientation = 6;
    final source = img.encodeJpg(oriented);

    final converted = img.decodePng(FileTools.convertImage(source, 'png'))!;
    expect(converted.width, 2);
    expect(converted.height, 3);
    expect(converted.exif.imageIfd.hasOrientation, isFalse);
  });

  test('recognizes only image formats supported by the converter', () {
    expect(FileTools.isSupportedImageName('photo.PNG'), isTrue);
    expect(FileTools.isSupportedImageName('photo.jpeg'), isTrue);
    expect(FileTools.isSupportedImageName('photo.webp'), isTrue);
    expect(FileTools.isSupportedImageName('photo.gif'), isFalse);
    expect(FileTools.isSupportedImageName('photo'), isFalse);
  });

  test('creates a two-page reopenable PDF from two images', () async {
    final output = await FileTools.imagesToPdf([samplePng(), samplePng()]);
    expect(FileTools.looksLikePdf(output), isTrue);
    expect(output.length, greaterThan(500));
    expect(PdfFile.open(output).pageCount, 2);
  });

  test('creates a blank PDF', () async {
    expect(FileTools.looksLikePdf(await FileTools.blankPdf()), isTrue);
  });

  test('rejects empty image input and invalid output types', () async {
    expect(
      () => FileTools.convertImage(samplePng(), 'exe'),
      throwsFormatException,
    );
    await expectLater(FileTools.imagesToPdf([]), throwsFormatException);
  });

  test(
    'rejects oversized single and aggregate image inputs before decoding',
    () async {
      expect(
        () => FileTools.checkInputSize(Uint8List(FileTools.maxInputBytes + 1)),
        throwsFormatException,
      );
      final shared = Uint8List(3 * 1024 * 1024);
      await expectLater(
        FileTools.imagesToPdf(List<Uint8List>.filled(21, shared)),
        throwsFormatException,
      );
    },
  );

  test(
    'rejects batches whose decompressed or prepared pixels exceed budget',
    () async {
      final large = img.Image(width: 2000, height: 2000);
      img.fill(large, color: img.ColorRgb8(10, 20, 30));
      final compressed = img.encodePng(large);

      await expectLater(
        FileTools.imagesToPdf(List<Uint8List>.filled(13, compressed)),
        throwsFormatException,
      );
      await expectLater(
        FileTools.imagesToPdf(List<Uint8List>.filled(8, compressed)),
        throwsFormatException,
      );
    },
  );

  test('detects the PDF encryption marker for export warnings', () {
    expect(
      FileTools.mayBeEncryptedPdf(
        Uint8List.fromList('%PDF-1.7\n/Encrypt 4 0 R'.codeUnits),
      ),
      isTrue,
    );
    expect(
      FileTools.mayBeEncryptedPdf(Uint8List.fromList('%PDF-1.7'.codeUnits)),
      isFalse,
    );
  });
}
