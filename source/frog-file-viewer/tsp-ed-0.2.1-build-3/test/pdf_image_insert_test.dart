import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/services/pdf_image_insert.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_document/pdf_document.dart' show PdfRect;
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('accepts only the documented image file names', () {
    for (final name in ['photo.jpg', 'photo.JPEG', 'art.png', 'frog.webp']) {
      expect(PdfImageInsert.isSupportedName(name), isTrue, reason: name);
    }
    for (final name in ['photo.gif', 'photo.bmp', 'photo', 'photo.png.exe']) {
      expect(PdfImageInsert.isSupportedName(name), isFalse, reason: name);
    }
  });

  test('normalizes JPEG and WebP to editor-compatible bytes', () {
    final opaque = img.Image(width: 8, height: 6, numChannels: 3);
    img.fill(opaque, color: img.ColorRgb8(20, 120, 220));

    final jpeg = PdfImageInsert.normalize(img.encodeJpg(opaque));
    expect(jpeg.take(3), [0xff, 0xd8, 0xff]);
    expect(img.decodeImage(jpeg), isNotNull);

    final webp = PdfImageInsert.normalize(img.encodeWebP(opaque));
    expect(img.decodeImage(webp), isNotNull);
    expect(_isPng(webp) || _isJpeg(webp), isTrue);
  });

  test('preserves PNG transparency', () {
    final transparent = img.Image(width: 4, height: 3, numChannels: 4);
    img.fill(transparent, color: img.ColorRgba8(10, 20, 30, 0));
    transparent.setPixelRgba(1, 1, 200, 100, 50, 128);

    final normalized = PdfImageInsert.normalize(img.encodePng(transparent));
    expect(_isPng(normalized), isTrue);
    final decoded = img.decodePng(normalized)!;
    expect(decoded.getPixel(0, 0).a.toInt(), 0);
    expect(decoded.getPixel(1, 1).a.toInt(), 128);
  });

  test('bakes EXIF orientation before insertion', () {
    final source = img.Image(width: 2, height: 3, numChannels: 3);
    source.exif.imageIfd.orientation = 6;
    final normalized = PdfImageInsert.normalize(img.encodeJpg(source));
    final decoded = img.decodeJpg(normalized)!;

    expect(decoded.width, 3);
    expect(decoded.height, 2);
    expect(decoded.exif.imageIfd.hasOrientation, isFalse);
  });

  test('rejects empty, invalid, unsupported and oversized images', () {
    expect(() => PdfImageInsert.normalize(Uint8List(0)), throwsFormatException);
    expect(
      () => PdfImageInsert.normalize(Uint8List.fromList([1, 2, 3, 4])),
      throwsFormatException,
    );
    expect(
      () => PdfImageInsert.normalize(
        Uint8List.fromList('GIF89a not accepted'.codeUnits),
      ),
      throwsFormatException,
    );
    expect(
      () => PdfImageInsert.normalize(
        Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
      ),
      throwsFormatException,
    );
    expect(
      () =>
          PdfImageInsert.normalize(Uint8List(PdfImageInsert.maxInputBytes + 1)),
      throwsFormatException,
    );
  });

  test('rejects images above the 16 megapixel decoded limit', () {
    final headerOnly = _pngWithDimensions(width: 4001, height: 4000);
    expect(
      () => PdfImageInsert.normalize(headerOnly),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('16 megapixels'),
        ),
      ),
    );
  });

  test('saved copy flattens only inserted images on every page', () async {
    final source = await _blankPdf(pageCount: 2);
    final editing = PdfEditingController(source);
    addTearDown(editing.dispose);

    final image = img.Image(width: 6, height: 4, numChannels: 4);
    img.fill(image, color: img.ColorRgba8(20, 180, 80, 128));
    final imageBytes = Uint8List.fromList(img.encodePng(image));

    expect(editing.placeImage(0, 200, 300, imageBytes), isTrue);
    editing.addRectangle(0, const PdfRect(50, 50, 150, 120));
    expect(editing.placeImage(1, 250, 350, imageBytes), isTrue);

    final compatible = PdfImageInsert.makeSavedCopyCompatible(editing.bytes);
    final reopened = PdfEditingController(compatible);
    addTearDown(reopened.dispose);

    expect(
      reopened.document.page(0).annotations.any((a) => a.isImageStamp),
      isFalse,
    );
    expect(
      reopened.document.page(1).annotations.any((a) => a.isImageStamp),
      isFalse,
    );
    expect(
      reopened.document.page(0).annotations.any((a) => a.subtype == 'Square'),
      isTrue,
    );
    expect(reopened.document.page(1).annotations, isEmpty);
    expect(
      editing.document.page(0).annotations.any((a) => a.isImageStamp),
      isTrue,
    );
    expect(editing.canUndo, isTrue);
  });

  test('saved copy without inserted images is unchanged', () async {
    final source = await _blankPdf(pageCount: 1);
    expect(PdfImageInsert.makeSavedCopyCompatible(source), same(source));
  });
}

Future<Uint8List> _blankPdf({required int pageCount}) async {
  final document = pw.Document();
  for (var page = 0; page < pageCount; page++) {
    document.addPage(pw.Page(build: (_) => pw.SizedBox()));
  }
  return document.save();
}

bool _isPng(Uint8List bytes) =>
    bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50;

bool _isJpeg(Uint8List bytes) =>
    bytes.length >= 3 &&
    bytes[0] == 0xff &&
    bytes[1] == 0xd8 &&
    bytes[2] == 0xff;

Uint8List _pngWithDimensions({required int width, required int height}) {
  final bytes = Uint8List.fromList(
    img.encodePng(img.Image(width: 1, height: 1)),
  );
  final data = ByteData.sublistView(bytes);
  data.setUint32(16, width, Endian.big);
  data.setUint32(20, height, Endian.big);
  data.setUint32(29, _crc32(bytes.sublist(12, 29)), Endian.big);
  return bytes;
}

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 1 ? (crc >>> 1) ^ 0xedb88320 : crc >>> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
