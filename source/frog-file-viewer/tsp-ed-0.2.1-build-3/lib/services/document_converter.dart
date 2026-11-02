import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:quds_office_engine/quds_office_engine.dart';

/// Transferable input/output for Flutter compute() isolates.
class ConversionRequest {
  final Uint8List bytes;
  final String fileName;
  final String outputExtension;
  final Uint8List? fontBytes;
  const ConversionRequest({
    required this.bytes,
    required this.fileName,
    required this.outputExtension,
    this.fontBytes,
  });
}

class ConversionResult {
  final Uint8List bytes;
  final String extension;
  final String mimeType;
  final String? fidelityWarning;
  const ConversionResult({
    required this.bytes,
    required this.extension,
    required this.mimeType,
    this.fidelityWarning,
  });
}

/// This is an offline starter, not a full fidelity file converter.
/// PDF -> editable documents reconstructs extracted text, not original layout.
class DocumentConverter {
  const DocumentConverter._();

  static const bundledFontAsset =
      'packages/dart_pdf_editor_assets/assets/fonts/DejaVuSans.ttf';

  static const maxInputBytes = 16 * 1024 * 1024;
  static const maxTextCharacters = 250000;
  static const maxParagraphs = 4000;
  static const maxPdfPages = 300;
  static const maxArchiveEntries = 2000;
  static const maxExpandedArchiveBytes = 128 * 1024 * 1024;
  static const maxCompressionRatio = 100;

  static const odtWarning =
      'Best-effort conversion. Text is reconstructed when available. '
      'Image-only ODT files can use an embedded PDF page copy, but tables, '
      'pagination, fonts, lists and advanced formatting may still change.';

  static const pdfWarning =
      'Text-only reconstruction. Images, tables, columns, layout, '
      'form fields, signatures and original styles will not be retained. '
      'Some fonts, spacing, symbols and emoji may extract incorrectly. '
      'Scanned PDFs without searchable text require OCR (not included).';

  static const officeWarning =
      'Office-to-PDF conversion is best effort. Complex layouts, embedded '
      'fonts, formulas, charts, animations, comments, and slide elements may '
      'change or be omitted. Always compare the saved PDF with the original.';

  static String? warningFor(String fileName, String target) {
    final source = extensionOf(fileName);
    if (source == 'pdf') return pdfWarning;
    if (source == 'odt') return odtWarning;
    if (target == 'pdf' &&
        (source == 'docx' || source == 'xlsx' || source == 'pptx')) {
      return officeWarning;
    }
    return null;
  }

  static String extensionOf(String fileName) {
    final index = fileName.lastIndexOf('.');
    return index < 0 ? '' : fileName.substring(index + 1).toLowerCase();
  }

  static List<String> formatsFor(String fileName) {
    return switch (extensionOf(fileName)) {
      'pdf' => const ['txt', 'docx', 'odt'],
      'docx' || 'odt' || 'txt' || 'xlsx' || 'pptx' => const ['pdf'],
      _ => const <String>[],
    };
  }

  static ConversionResult convert(ConversionRequest request) {
    final input = request.bytes;
    final name = request.fileName;
    final source = extensionOf(name);
    final target = request.outputExtension.toLowerCase();
    if (!formatsFor(name).contains(target)) {
      throw const FormatException('Unsupported file conversion.');
    }
    if (input.isEmpty || input.length > maxInputBytes) {
      throw const FormatException(
        'Files must be nonempty and no larger than 16 MB.',
      );
    }
    if (source == 'docx' ||
        source == 'xlsx' ||
        source == 'pptx' ||
        source == 'odt') {
      _checkArchiveSafety(input);
    }

    if (target == 'pdf') {
      final fonts = _fontSet(request.fontBytes);
      if (source == 'docx' || source == 'xlsx' || source == 'pptx') {
        final pdf = OfficePdfExport.fromBytes(input, title: name, fonts: fonts);
        _verifyPdf(pdf);
        return ConversionResult(
          bytes: pdf,
          extension: 'pdf',
          mimeType: 'application/pdf',
          fidelityWarning: officeWarning,
        );
      }
      final extracted = source == 'odt'
          ? OfficeTextExtractor.extract(input, name: name).plainString
          : _decodeText(input);
      if (source == 'odt' && extracted.trim().isEmpty) {
        final embeddedPdf = _embeddedOdtPdf(input);
        if (embeddedPdf != null) {
          _verifyPdf(embeddedPdf);
          return ConversionResult(
            bytes: embeddedPdf,
            extension: 'pdf',
            mimeType: 'application/pdf',
            fidelityWarning: odtWarning,
          );
        }
      }
      final docx = _simpleDocx(_checkedText(extracted));
      final pdf = OfficePdfExport.fromBytes(docx, title: name, fonts: fonts);
      _verifyPdf(pdf);
      return ConversionResult(
        bytes: pdf,
        extension: 'pdf',
        mimeType: 'application/pdf',
        fidelityWarning: source == 'odt' ? odtWarning : null,
      );
    }

    if (source != 'pdf' ||
        input.length < 5 ||
        input[0] != 0x25 ||
        input[1] != 0x50 ||
        input[2] != 0x44 ||
        input[3] != 0x46 ||
        input[4] != 0x2d) {
      throw const FormatException('The selected file is not a PDF.');
    }
    final pdf = PdfFile.open(input);
    if (pdf.pageCount > maxPdfPages) {
      throw const FormatException('PDF exceeds the 300-page starter limit.');
    }
    // Only visible PDF text runs are trusted. Older Frog builds appended a
    // Base64 source-text comment trailer, but that hidden copy could become
    // stale after editing and an imported PDF could forge it. Ignoring all
    // such trailers keeps conversion aligned with the document users see.
    final text = _checkedText(_extractPdfText(pdf));
    if (target == 'txt') {
      return ConversionResult(
        bytes: Uint8List.fromList(utf8.encode(text)),
        extension: 'txt',
        mimeType: 'text/plain',
        fidelityWarning: pdfWarning,
      );
    }
    if (target == 'docx') {
      return ConversionResult(
        bytes: _simpleDocx(text),
        extension: 'docx',
        mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        fidelityWarning: pdfWarning,
      );
    }
    return ConversionResult(
      bytes: _simpleOdt(text),
      extension: 'odt',
      mimeType: 'application/vnd.oasis.opendocument.text',
      fidelityWarning: pdfWarning,
    );
  }

  static String _decodeText(Uint8List input) {
    try {
      final result = utf8.decode(input, allowMalformed: false);
      return result.startsWith('\uFEFF') ? result.substring(1) : result;
    } on FormatException {
      throw const FormatException(
        'Text must be UTF-8. Save it as UTF-8 first.',
      );
    }
  }

  static String _checkedText(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (normalized.trim().isEmpty) {
      throw const FormatException(
        'No selectable text could be extracted. '
        'Scanned pages require OCR.',
      );
    }
    if (normalized.length > maxTextCharacters ||
        '\n'.allMatches(normalized).length > maxParagraphs) {
      throw const FormatException('Document text exceeds the starter limits.');
    }
    return normalized;
  }

  static Uint8List _simpleDocx(String text) {
    final builder = DocxDocumentBuilder();
    for (final line in text.split('\n')) {
      builder.paragraph(line.isEmpty ? ' ' : line);
    }
    return builder.build();
  }

  static OfficeFontSet? _fontSet(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    return OfficeFontSet.single(SfntFont.parse(bytes));
  }

  /// Reconstruct line and word boundaries from positioned PDF text runs.
  /// Some valid PDFs omit explicit line-break markers even though successive
  /// runs are visibly separated on the page.
  static String _extractPdfText(PdfFile pdf) {
    final document = StringBuffer();
    for (var pageIndex = 0; pageIndex < pdf.pageCount; pageIndex++) {
      final runs = pdf.displayList(pageIndex).runs;
      final page = StringBuffer();
      double? previousY;
      double? previousRight;
      double? previousHeight;
      String previousText = '';
      for (final run in runs) {
        if (run.text.isEmpty) continue;
        var lineBreak = run.breakBefore;
        var visualLineBreaks = lineBreak ? 1 : 0;
        if (previousY != null && previousHeight != null) {
          final lineThreshold = math.max(
            2.0,
            math.min(previousHeight, run.height) * 0.45,
          );
          final verticalGap = (run.y - previousY).abs();
          if (verticalGap > lineThreshold) {
            lineBreak = true;
            final lineHeight = math.max(
              1.0,
              math.min(previousHeight, run.height),
            );
            // A visibly empty line produces roughly two line-height steps.
            // Preserve up to two blank lines without trusting hidden metadata.
            visualLineBreaks = math.max(
              visualLineBreaks,
              math.min(3, (verticalGap / (lineHeight * 2)).round()),
            );
          }
        }
        if (page.isNotEmpty && lineBreak) {
          page.write('\n' * math.max(1, visualLineBreaks));
        } else if (page.isNotEmpty && previousRight != null) {
          final gap = run.x - previousRight;
          final em = math.max(previousHeight ?? run.height, run.height);
          if (gap > em * 0.45 &&
              !RegExp(r'\s$').hasMatch(previousText) &&
              !RegExp(r'^\s').hasMatch(run.text)) {
            page.write(' ');
          }
        }
        page.write(run.text);
        previousY = run.y;
        previousRight = run.x + run.width;
        previousHeight = run.height;
        previousText = run.text;
      }
      if (page.isEmpty) continue;
      if (document.isNotEmpty) document.write('\n');
      document.write(page);
    }
    return document.toString();
  }

  /// LibreOffice can store a scan as an embedded PDF plus an image fallback
  /// without any selectable ODT text. Reuse that local PDF instead of
  /// incorrectly reporting that the document is empty.
  static Uint8List? _embeddedOdtPdf(Uint8List input) {
    final archive = ZipDecoder().decodeBytes(input, verify: true);
    for (final file in archive.files) {
      final name = file.name.toLowerCase();
      if (!file.isFile ||
          !name.startsWith('pictures/') ||
          !name.endsWith('.pdf')) {
        continue;
      }
      final bytes = file.readBytes();
      if (bytes != null &&
          bytes.length <= maxExpandedArchiveBytes &&
          bytes.length >= 5 &&
          bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46 &&
          bytes[4] == 0x2d) {
        return bytes;
      }
    }
    return null;
  }

  static void _verifyPdf(Uint8List bytes) {
    if (bytes.length < 5 ||
        bytes[0] != 0x25 ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x44 ||
        bytes[3] != 0x46 ||
        bytes[4] != 0x2d) {
      throw const FormatException('Office conversion did not produce a PDF.');
    }
  }

  static String _sanitizeXml10(String input) => String.fromCharCodes(
    input.runes.where(
      (codePoint) =>
          codePoint == 0x9 ||
          codePoint == 0xA ||
          codePoint == 0xD ||
          codePoint >= 0x20 && codePoint <= 0xD7FF ||
          codePoint >= 0xE000 && codePoint <= 0xFFFD ||
          codePoint >= 0x10000 && codePoint <= 0x10FFFF,
    ),
  );

  static String _xmlEscape(String input) =>
      _sanitizeXml10(input)
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;')
          .replaceAll("'", '&apos;');

  /// Minimal ODT 1.2 output. Mimetype must be the first stored ZIP entry.
  static Uint8List _simpleOdt(String text) {
    const mime = 'application/vnd.oasis.opendocument.text';
    final paragraphs = text.split('\n').map((line) {
      if (line.isEmpty) return '<text:p/>';
      final chunks = line.split('\t').map((part) {
        return _xmlEscape(part).replaceAllMapped(
          RegExp(r' {2,}'),
          (match) => ' <text:s text:c="${match.group(0)!.length - 1}"/>',
        );
      });
      return '<text:p>${chunks.join('<text:tab/>')}</text:p>';
    }).join();

    final contentXml =
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<office:document-content '
        'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
        'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
        'office:version="1.2">'
        '<office:body><office:text>$paragraphs'
        '</office:text></office:body></office:document-content>';

    const stylesXml =
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<office:document-styles '
        'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
        'office:version="1.2"><office:styles/></office:document-styles>';
    const manifestXml =
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<manifest:manifest '
        'xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" '
        'manifest:version="1.2">'
        '<manifest:file-entry manifest:full-path="/" '
        'manifest:media-type="application/vnd.oasis.opendocument.text"/>'
        '<manifest:file-entry manifest:full-path="content.xml" '
        'manifest:media-type="text/xml"/>'
        '<manifest:file-entry manifest:full-path="styles.xml" '
        'manifest:media-type="text/xml"/>'
        '</manifest:manifest>';

    final mimeBytes = utf8.encode(mime);
    final archive = Archive()
      ..addFile(ArchiveFile.noCompress('mimetype', mimeBytes.length, mimeBytes))
      ..addFile(ArchiveFile.string('content.xml', contentXml))
      ..addFile(ArchiveFile.string('styles.xml', stylesXml))
      ..addFile(ArchiveFile.string('META-INF/manifest.xml', manifestXml));
    final encoded = ZipEncoder().encodeBytes(archive);
    final reopened = ZipDecoder().decodeBytes(encoded, verify: true);
    final names = reopened.files.map((file) => file.name).toSet();
    if (!names.contains('mimetype') ||
        !names.contains('content.xml') ||
        !names.contains('META-INF/manifest.xml')) {
      throw const FormatException('Generated ODT package failed validation.');
    }
    return encoded;
  }

  static void _checkArchiveSafety(Uint8List input) {
    if (input.length < 22 || input[0] != 0x50 || input[1] != 0x4B) {
      throw const FormatException(
        'Encrypted or malformed Office packages are not supported.',
      );
    }
    final data = ByteData.sublistView(input);
    final searchStart = input.length > 65557 ? input.length - 65557 : 0;
    var eocd = -1;
    for (var offset = input.length - 22; offset >= searchStart; offset--) {
      if (_u32(data, offset) == 0x06054B50) {
        eocd = offset;
        break;
      }
    }
    if (eocd < 0) {
      throw const FormatException('Office package has no valid ZIP directory.');
    }
    final entryCount = _u16(data, eocd + 10);
    final centralOffset = _u32(data, eocd + 16);
    if (entryCount > maxArchiveEntries || entryCount == 0xFFFF) {
      throw const FormatException('Office package contains too many entries.');
    }
    var cursor = centralOffset;
    var expandedTotal = 0;
    for (var index = 0; index < entryCount; index++) {
      if (cursor < 0 ||
          cursor + 46 > input.length ||
          _u32(data, cursor) != 0x02014B50) {
        throw const FormatException('Office package directory is malformed.');
      }
      final compressed = _u32(data, cursor + 20);
      final expanded = _u32(data, cursor + 24);
      if (compressed == 0xFFFFFFFF || expanded == 0xFFFFFFFF) {
        throw const FormatException('ZIP64 Office packages are not supported.');
      }
      expandedTotal += expanded;
      if (expandedTotal > maxExpandedArchiveBytes) {
        throw const FormatException(
          'Office package expands beyond the 128 MB safety limit.',
        );
      }
      if (expanded > 1024 * 1024 &&
          (compressed == 0 || expanded > compressed * maxCompressionRatio)) {
        throw const FormatException(
          'Office package compression ratio is unsafe.',
        );
      }
      final nameLength = _u16(data, cursor + 28);
      final extraLength = _u16(data, cursor + 30);
      final commentLength = _u16(data, cursor + 32);
      cursor += 46 + nameLength + extraLength + commentLength;
    }
  }

  static int _u16(ByteData data, int offset) {
    if (offset < 0 || offset + 2 > data.lengthInBytes) {
      throw const FormatException('Office package is truncated.');
    }
    return data.getUint16(offset, Endian.little);
  }

  static int _u32(ByteData data, int offset) {
    if (offset < 0 || offset + 4 > data.lengthInBytes) {
      throw const FormatException('Office package is truncated.');
    }
    return data.getUint32(offset, Endian.little);
  }
}
