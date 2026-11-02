import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' as archive;
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:quds_office_engine/quds_office_engine.dart';

/// Core local-only conversion code. No network or file-system access occurs here.
class FileTools {
  const FileTools._();

  static const maxInputBytes = 15 * 1024 * 1024;
  static const maxAggregateInputBytes = 60 * 1024 * 1024;
  static const maxPixelCount = 16 * 1000 * 1000;
  static const maxAggregatePixelCount = 48 * 1000 * 1000;
  static const maxAggregatePreparedPixels = 20 * 1000 * 1000;
  static const maxPdfImageWidth = 1654;
  static const maxPdfImageHeight = 2339;
  static const maxScannerPages = 30;
  static const maxScannerStreamBytes = 15 * 1024 * 1024;
  static const maxScannerAggregateBytes = 60 * 1024 * 1024;

  static String withoutExtension(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^a-zA-Z0-9._ -]'), '_');
    final lastDot = cleaned.lastIndexOf('.');
    final stem = lastDot > 0 ? cleaned.substring(0, lastDot) : cleaned;
    final safe = stem.trim().replaceAll(RegExp(r'^\.+|\.+$'), '');
    return safe.isEmpty ? 'document' : safe;
  }

  static bool isSupportedImageName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return false;
    return const {
      'jpg',
      'jpeg',
      'png',
      'webp',
    }.contains(name.substring(dot + 1).toLowerCase());
  }

  static void checkInputSize(Uint8List input) {
    if (input.isEmpty) throw const FormatException('This file is empty.');
    if (input.length > maxInputBytes) {
      throw const FormatException(
        'Each selected image is limited to 15 MB to protect memory.',
      );
    }
  }

  static img.Image decodeImage(Uint8List bytes) {
    checkInputSize(bytes);
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null) {
      throw const FormatException('This is not a supported or readable image.');
    }
    if (info.width <= 0 ||
        info.height <= 0 ||
        info.width * info.height > maxPixelCount) {
      throw const FormatException(
        'Image dimensions are too large. The limit is 16 megapixels.',
      );
    }
    final decoded = decoder!.decode(bytes);
    if (decoded == null) {
      throw const FormatException('This is not a supported or readable image.');
    }
    return img.bakeOrientation(decoded);
  }

  static Uint8List convertImage(Uint8List original, String extension) {
    final image = decodeImage(original);
    switch (extension.toLowerCase()) {
      case 'png':
        return img.encodePng(image);
      case 'jpg':
        return img.encodeJpg(_jpegReady(image), quality: 90);
      case 'webp':
        return img.encodeWebP(image, lossless: true);
      default:
        throw const FormatException('Unsupported target format.');
    }
  }

  /// Each image becomes a separate A4 page. Original images aren't changed.
  static Future<Uint8List> imagesToPdf(List<Uint8List> images) async {
    if (images.isEmpty) {
      throw const FormatException('Select at least one image.');
    }
    if (images.length > 30) {
      throw const FormatException('Maximum 30 images per PDF.');
    }
    final aggregateBytes = images.fold<int>(
      0,
      (total, image) => total + image.length,
    );
    if (aggregateBytes > maxAggregateInputBytes) {
      throw const FormatException(
        'Selected images exceed the combined 60 MB safety limit.',
      );
    }

    var aggregatePixels = 0;
    var aggregatePreparedPixels = 0;
    for (final original in images) {
      checkInputSize(original);
      final decoder = img.findDecoderForData(original);
      final info = decoder?.startDecode(original);
      if (info == null || info.width <= 0 || info.height <= 0) {
        throw const FormatException(
          'This is not a supported or readable image.',
        );
      }
      final pixels = info.width * info.height;
      if (pixels > maxPixelCount) {
        throw const FormatException(
          'Image dimensions are too large. The limit is 16 megapixels.',
        );
      }
      aggregatePixels += pixels;
      if (aggregatePixels > maxAggregatePixelCount) {
        throw const FormatException(
          'The selected images need too much decoded memory. Choose fewer or smaller images.',
        );
      }
      final scale = math.min(
        1.0,
        math.min(
          maxPdfImageWidth / info.width,
          maxPdfImageHeight / info.height,
        ),
      );
      aggregatePreparedPixels +=
          math.max(1, (info.width * scale).round()) *
          math.max(1, (info.height * scale).round());
      if (aggregatePreparedPixels > maxAggregatePreparedPixels) {
        throw const FormatException(
          'The PDF would require too much image memory. Choose fewer pages per batch.',
        );
      }
    }

    final document = pw.Document(compress: true);
    for (final original in images) {
      final decoded = decodeImage(original);
      final scale = math.min(
        1.0,
        math.min(
          maxPdfImageWidth / decoded.width,
          maxPdfImageHeight / decoded.height,
        ),
      );
      final prepared = scale < 1
          ? img.copyResize(
              decoded,
              width: math.max(1, (decoded.width * scale).round()),
              height: math.max(1, (decoded.height * scale).round()),
              interpolation: img.Interpolation.average,
            )
          : decoded;
      final encoded = prepared.numChannels == 4
          ? img.encodePng(prepared, level: 6)
          : img.encodeJpg(prepared, quality: 88);
      final image = pw.MemoryImage(encoded);
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(18),
          build: (context) => pw.Center(
            child: pw.Image(
              image,
              width: PdfPageFormat.a4.width - 36,
              height: PdfPageFormat.a4.height - 36,
              fit: pw.BoxFit.contain,
            ),
          ),
        ),
      );
    }
    return document.save();
  }

  static Future<Uint8List> blankPdf() async {
    final document = pw.Document(compress: true);
    document.addPage(
      pw.Page(pageFormat: PdfPageFormat.a4, build: (_) => pw.SizedBox()),
    );
    return document.save();
  }

  static img.Image _jpegReady(img.Image image) {
    if (image.numChannels < 4) return image;
    final background = img.Image(
      width: image.width,
      height: image.height,
      numChannels: 3,
    );
    img.fill(background, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(background, image);
    return background;
  }

  /// Check that the PDF parser actually recognizes a nonempty document.
  ///
  /// A %PDF header alone is not enough to safely replace an unsaved editor
  /// session; a truncated or mislabeled file can have a valid header.
  /// This method is isolate-safe and is used before committing an import.
  static bool canOpenEditablePdf(Uint8List bytes) {
    if (!looksLikePdf(bytes)) return false;
    try {
      return PdfFile.open(bytes).pageCount > 0;
    } catch (_) {
      return false;
    }
  }

  static bool looksLikePdf(Uint8List bytes) {
    if (bytes.length < 5) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D;
  }

  /// Some scanner drivers wrap a JPEG stream in Flate compression. The PDF is
  /// valid, but a few pure-Dart renderers currently paint these chained image
  /// filters as a blank page. Detect only that narrow, known-bad encoding so
  /// ordinary PDFs are never flattened unnecessarily.
  // PDF whitespace includes NUL, and PDF comments may separate tokens.
  // Keep the two filter names in order: filter order affects decoding.
  static final RegExp _scannerFilter = RegExp(
    r'/Filter(?:[\x00\t\n\f\r ]|%[^\r\n]*(?:\r\n|\r|\n))*\[(?:[\x00\t\n\f\r ]|%[^\r\n]*(?:\r\n|\r|\n))*/FlateDecode(?:[\x00\t\n\f\r ]|%[^\r\n]*(?:\r\n|\r|\n))*/DCTDecode(?:[\x00\t\n\f\r ]|%[^\r\n]*(?:\r\n|\r|\n))*\]',
  );

  static bool needsScannedPdfCompatibilityCopy(Uint8List bytes) {
    if (!looksLikePdf(bytes)) return false;
    final source = latin1.decode(bytes, allowInvalid: true);
    return _scannerFilter.hasMatch(source);
  }

  /// Rebuilds image-only scanner output into a broadly compatible local PDF.
  /// This intentionally supports only Flate-wrapped JPEG image streams and is
  /// offered to the user as an opt-in fallback because rebuilding flattens the
  /// original page content.
  static Future<Uint8List> makeScannedPdfCompatibilityCopy(
    Uint8List original,
  ) async {
    if (!needsScannedPdfCompatibilityCopy(original)) {
      throw const FormatException(
        'This PDF does not use the supported scanned-image repair format.',
      );
    }

    final source = latin1.decode(original, allowInvalid: true);
    final objects = _pdfObjects(source);
    final pages = _scannerPages(objects);
    if (pages.isEmpty || pages.length > maxScannerPages) {
      throw const FormatException(
        'The scan has an unsupported or unsafe page structure.',
      );
    }

    final scannerImageObjects = objects.values
        .where(
          (object) =>
              RegExp(r'/Subtype\s*/Image\b').hasMatch(object.body) &&
              _scannerFilter.hasMatch(object.body),
        )
        .map((object) => object.number)
        .toSet();
    final usedImageObjects = <int>{};
    final images = <Uint8List>[];
    final mediaBoxes = <PdfPageFormat>[];
    var aggregateBytes = 0;
    for (final page in pages) {
      final imageRefs = _pageImageRefs(page, objects);
      if (imageRefs.length != 1 ||
          !scannerImageObjects.contains(imageRefs.single)) {
        throw const FormatException(
          'Each repaired scan page must contain exactly one supported image.',
        );
      }
      final imageObject = objects[imageRefs.single];
      if (imageObject == null) {
        throw const FormatException('A scan page references a missing image.');
      }
      final jpeg = _boundedScannerJpeg(original, source, imageObject);
      aggregateBytes += jpeg.length;
      if (aggregateBytes > maxScannerAggregateBytes) {
        throw const FormatException(
          'The repaired scan exceeds the 60 MB decoded-image limit.',
        );
      }
      usedImageObjects.add(imageObject.number);
      images.add(jpeg);
      mediaBoxes.add(_pageFormat(page, objects, jpeg));
    }
    if (usedImageObjects.length != scannerImageObjects.length) {
      throw const FormatException(
        'The scan contains unassociated image data and cannot be rebuilt safely.',
      );
    }

    final document = pw.Document(compress: true);
    for (var index = 0; index < images.length; index++) {
      final image = pw.MemoryImage(images[index]);
      document.addPage(
        pw.Page(
          pageFormat: mediaBoxes[index],
          margin: pw.EdgeInsets.zero,
          build: (_) =>
              pw.SizedBox.expand(child: pw.Image(image, fit: pw.BoxFit.fill)),
        ),
      );
    }
    final rebuilt = await document.save();
    try {
      final reopened = PdfFile.open(rebuilt);
      if (reopened.pageCount != pages.length) throw const FormatException();
      for (var index = 0; index < reopened.pageCount; index++) {
        reopened.displayList(index);
      }
    } catch (_) {
      throw const FormatException(
        'The compatibility copy failed its page validation.',
      );
    }
    return rebuilt;
  }

  static Map<int, _PdfObject> _pdfObjects(String source) {
    final matches = RegExp(
      r'(\d+)\s+(\d+)\s+obj\b',
      multiLine: true,
    ).allMatches(source).toList();
    final objects = <int, _PdfObject>{};
    for (var index = 0; index < matches.length; index++) {
      final match = matches[index];
      final limit = index + 1 < matches.length
          ? matches[index + 1].start
          : source.length;
      final end = source.indexOf('endobj', match.end);
      if (end < 0 || end >= limit) continue;
      final number = int.parse(match.group(1)!);
      if (objects.containsKey(number)) {
        throw const FormatException(
          'Duplicate PDF objects are not supported by scan repair.',
        );
      }
      objects[number] = _PdfObject(
        number: number,
        start: match.start,
        end: end + 'endobj'.length,
        body: source.substring(match.end, end),
      );
    }
    return objects;
  }

  static List<_PdfObject> _scannerPages(Map<int, _PdfObject> objects) {
    final catalogs = objects.values
        .where((object) => RegExp(r'/Type\s*/Catalog\b').hasMatch(object.body))
        .toList();
    if (catalogs.length != 1) {
      throw const FormatException('The PDF page tree is ambiguous.');
    }
    final root = _referenceAfter(catalogs.single.body, '/Pages');
    if (root == null) throw const FormatException('The PDF has no page tree.');
    final pages = <_PdfObject>[];
    final visiting = <int>{};
    final visited = <int>{};
    var traversed = 0;

    void visit(int reference) {
      traversed++;
      if (traversed > maxScannerPages * 2 + 1) {
        throw const FormatException('The PDF page tree is too complex.');
      }
      if (!visiting.add(reference)) {
        throw const FormatException('The PDF page tree contains a cycle.');
      }
      if (!visited.add(reference)) {
        throw const FormatException(
          'The PDF page tree contains a shared or duplicate node.',
        );
      }
      final object = objects[reference];
      if (object == null) {
        throw const FormatException('The PDF page tree is incomplete.');
      }
      if (RegExp(r'/Type\s*/Page\b').hasMatch(object.body)) {
        pages.add(object);
        if (pages.length > maxScannerPages) {
          throw const FormatException('The scan has too many pages.');
        }
      } else if (RegExp(r'/Type\s*/Pages\b').hasMatch(object.body)) {
        final kids = _referencesInArray(object.body, '/Kids');
        if (kids.isEmpty) {
          throw const FormatException('The PDF page tree has no pages.');
        }
        for (final kid in kids) {
          visit(kid);
        }
      } else {
        throw const FormatException('The PDF page tree is malformed.');
      }
      visiting.remove(reference);
    }

    visit(root);
    return pages;
  }

  static Set<int> _pageImageRefs(
    _PdfObject page,
    Map<int, _PdfObject> objects,
  ) {
    var resources = _dictionaryAfter(page.body, '/Resources');
    if (resources == null) {
      final resourceRef = _referenceAfter(page.body, '/Resources');
      resources = resourceRef == null ? null : objects[resourceRef]?.body;
    }
    if (resources == null) {
      throw const FormatException('A scan page has no explicit resources.');
    }
    var xObjects = _dictionaryAfter(resources, '/XObject');
    if (xObjects == null) {
      final xObjectRef = _referenceAfter(resources, '/XObject');
      xObjects = xObjectRef == null ? null : objects[xObjectRef]?.body;
    }
    if (xObjects == null) {
      throw const FormatException('A scan page has no image resources.');
    }
    return RegExp(r'(\d+)\s+\d+\s+R')
        .allMatches(xObjects)
        .map((match) => int.parse(match.group(1)!))
        .where(
          (reference) =>
              RegExp(r'/Subtype\s*/Image\b')
                  .hasMatch(objects[reference]?.body ?? ''),
        )
        .toSet();
  }

  static Uint8List _boundedScannerJpeg(
    Uint8List original,
    String source,
    _PdfObject object,
  ) {
    final width = _positiveIntAfter(object.body, '/Width');
    final height = _positiveIntAfter(object.body, '/Height');
    if (width == null || height == null || width > maxPixelCount ~/ height) {
      throw const FormatException(
        'A scanned image has unsafe or missing dimensions.',
      );
    }
    final streamMarker = source.indexOf('stream', object.start);
    if (streamMarker < 0 || streamMarker >= object.end) {
      throw const FormatException('A scanned image stream is missing.');
    }
    var streamStart = streamMarker + 'stream'.length;
    if (streamStart < object.end && original[streamStart] == 0x0d) {
      streamStart++;
    }
    if (streamStart < object.end && original[streamStart] == 0x0a) {
      streamStart++;
    }
    final end = source.indexOf('endstream', streamStart);
    if (end < 0 || end > object.end) {
      throw const FormatException('A scanned image stream is truncated.');
    }
    var streamEnd = end;
    while (streamEnd > streamStart &&
        (original[streamEnd - 1] == 0x0a || original[streamEnd - 1] == 0x0d)) {
      streamEnd--;
    }
    final decoded = Uint8List.fromList(
      archive.ZLibDecoder().decodeBytes(
        original.sublist(streamStart, streamEnd),
        verify: true,
        maxOutputSize: maxScannerStreamBytes,
      ),
    );
    var jpegEnd = -1;
    for (var index = decoded.length - 2; index >= 2; index--) {
      if (decoded[index] == 0xff && decoded[index + 1] == 0xd9) {
        jpegEnd = index + 2;
        break;
      }
    }
    if (decoded.length < 4 ||
        decoded[0] != 0xff ||
        decoded[1] != 0xd8 ||
        jpegEnd < 0) {
      throw const FormatException('A repaired image is not a complete JPEG.');
    }
    final jpeg = Uint8List.sublistView(decoded, 0, jpegEnd);
    final decoder = img.findDecoderForData(jpeg);
    final info = decoder?.startDecode(jpeg);
    if (info == null ||
        info.width != width ||
        info.height != height ||
        info.width > maxPixelCount ~/ info.height) {
      throw const FormatException(
        'A scanned image does not match its declared dimensions.',
      );
    }
    if (decoder!.decode(jpeg) == null) {
      throw const FormatException('A scanned image could not be decoded.');
    }
    return jpeg;
  }

  static PdfPageFormat _pageFormat(
    _PdfObject page,
    Map<int, _PdfObject> objects,
    Uint8List jpeg,
  ) {
    String? mediaBox = _arrayAfter(page.body, '/MediaBox');
    if (mediaBox == null) {
      final parent = _referenceAfter(page.body, '/Parent');
      mediaBox = parent == null
          ? null
          : _arrayAfter(objects[parent]?.body ?? '', '/MediaBox');
    }
    if (mediaBox != null) {
      final numbers = RegExp(r'[-+]?(?:\d+\.?\d*|\.\d+)')
          .allMatches(mediaBox)
          .map((match) => double.parse(match.group(0)!))
          .toList();
      if (numbers.length == 4) {
        final width = numbers[2] - numbers[0];
        final height = numbers[3] - numbers[1];
        if (width > 0 && height > 0 && width <= 20000 && height <= 20000) {
          return PdfPageFormat(width, height);
        }
      }
    }
    final info = img.findDecoderForData(jpeg)!.startDecode(jpeg)!;
    return info.width >= info.height
        ? PdfPageFormat.a4.landscape
        : PdfPageFormat.a4;
  }

  static int? _referenceAfter(String body, String key) {
    final match = RegExp('${RegExp.escape(key)}\\s+(\\d+)\\s+\\d+\\s+R')
        .firstMatch(body);
    return match == null ? null : int.parse(match.group(1)!);
  }

  static int? _positiveIntAfter(String body, String key) {
    final match = RegExp('${RegExp.escape(key)}\\s+(\\d+)').firstMatch(body);
    final value = match == null ? null : int.tryParse(match.group(1)!);
    return value != null && value > 0 ? value : null;
  }

  static List<int> _referencesInArray(String body, String key) {
    final array = _arrayAfter(body, key);
    if (array == null) return const [];
    return RegExp(r'(\d+)\s+\d+\s+R')
        .allMatches(array)
        .map((match) => int.parse(match.group(1)!))
        .toList();
  }

  static String? _arrayAfter(String body, String key) {
    final keyIndex = body.indexOf(key);
    if (keyIndex < 0) return null;
    final start = body.indexOf('[', keyIndex + key.length);
    if (start < 0) return null;
    final end = body.indexOf(']', start + 1);
    return end < 0 ? null : body.substring(start + 1, end);
  }

  static String? _dictionaryAfter(String body, String key) {
    final keyIndex = body.indexOf(key);
    if (keyIndex < 0) return null;
    final start = body.indexOf('<<', keyIndex + key.length);
    if (start < 0) return null;
    var depth = 0;
    for (var index = start; index + 1 < body.length; index++) {
      final token = body.substring(index, index + 2);
      if (token == '<<') {
        depth++;
        index++;
      } else if (token == '>>') {
        depth--;
        if (depth == 0) return body.substring(start, index + 2);
        index++;
      }
    }
    return null;
  }

  /// Conservative marker check used only to decide whether to show a
  /// protection-loss warning before exporting or splitting pages.
  static bool mayBeEncryptedPdf(Uint8List bytes) {
    const marker = <int>[0x2f, 0x45, 0x6e, 0x63, 0x72, 0x79, 0x70, 0x74];
    for (var i = 0; i <= bytes.length - marker.length; i++) {
      var matches = true;
      for (var j = 0; j < marker.length; j++) {
        if (bytes[i + j] != marker[j]) {
          matches = false;
          break;
        }
      }
      if (matches) return true;
    }
    return false;
  }
}

class _PdfObject {
  const _PdfObject({
    required this.number,
    required this.start,
    required this.end,
    required this.body,
  });

  final int number;
  final int start;
  final int end;
  final String body;
}
