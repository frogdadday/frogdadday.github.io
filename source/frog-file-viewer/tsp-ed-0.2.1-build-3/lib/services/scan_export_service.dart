import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'file_tools.dart';

/// Local-only processing for camera scans; no filesystem or network access.
class ScanExportService {
  const ScanExportService._();

  static const maxPages = 30;
  static const maxPageBytes = FileTools.maxInputBytes;
  static const maxTotalBytes = FileTools.maxAggregateInputBytes;

  /// Bound both decoded pixels and encoded size before the UI retains a page.
  static Uint8List preparePage(Uint8List source) {
    final decoded = FileTools.decodeImage(source);
    final scale = math.min(
      1.0,
      math.min(
        FileTools.maxPdfImageWidth / decoded.width,
        FileTools.maxPdfImageHeight / decoded.height,
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
    final encoded = Uint8List.fromList(img.encodeJpg(prepared, quality: 87));
    if (encoded.length > maxPageBytes) {
      throw const FormatException('The scanned page is too large.');
    }
    return encoded;
  }

  static Uint8List rotateClockwise(Uint8List source) {
    final decoded = FileTools.decodeImage(source);
    return preparePage(
      Uint8List.fromList(img.encodeJpg(
        img.copyRotate(decoded, angle: 90),
        quality: 90,
      )),
    );
  }

  static Uint8List asPng(Uint8List source) {
    return FileTools.convertImage(source, 'png');
  }

  /// Unlike a general image importer, scanner pages have already been
  /// downscaled and encoded. Process one page at a time and hold only its
  /// compact JPEG inside the document; retain strict page/byte caps.
  static Future<Uint8List> asPdf(List<Uint8List> jpegPages) async {
    if (jpegPages.isEmpty || jpegPages.length > maxPages) {
      throw const FormatException('Scan between 1 and 30 pages.');
    }
    var total = 0;
    final document = pw.Document(compress: true);
    for (final bytes in jpegPages) {
      if (bytes.isEmpty || bytes.length > maxPageBytes) {
        throw const FormatException('A scanned page is empty or too large.');
      }
      total += bytes.length;
      if (total > maxTotalBytes) {
        throw const FormatException('Scans exceed the 60 MB safety limit.');
      }
      final decoder = img.findDecoderForData(bytes);
      final info = decoder?.startDecode(bytes);
      if (info == null ||
          info.width <= 0 ||
          info.height <= 0 ||
          info.width > FileTools.maxPdfImageWidth ||
          info.height > FileTools.maxPdfImageHeight) {
        throw const FormatException('A scanned page is not a prepared image.');
      }
      final image = pw.MemoryImage(bytes);
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
    final output = await document.save();
    if (output.length > maxTotalBytes) {
      throw const FormatException('The finished PDF exceeds 60 MB.');
    }
    return output;
  }
}
