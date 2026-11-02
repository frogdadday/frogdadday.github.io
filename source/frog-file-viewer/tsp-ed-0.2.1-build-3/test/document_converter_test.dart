import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:quds_office_engine/quds_office_engine.dart';
import 'package:frog_file_viewer/services/document_converter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ConversionResult convert(
    List<int> bytes,
    String name,
    String target, {
    Uint8List? fontBytes,
  }) {
    return DocumentConverter.convert(
      ConversionRequest(
        bytes: Uint8List.fromList(bytes),
        fileName: name,
        outputExtension: target,
        fontBytes: fontBytes,
      ),
    );
  }

  test('only offers implemented and explicitly labeled format pairs', () {
    expect(DocumentConverter.formatsFor('hello.odt'), ['pdf']);
    expect(DocumentConverter.formatsFor('hello.DOCX'), ['pdf']);
    expect(DocumentConverter.formatsFor('hello.xlsx'), ['pdf']);
    expect(DocumentConverter.formatsFor('hello.pptx'), ['pdf']);
    expect(DocumentConverter.formatsFor('hello.txt'), ['pdf']);
    expect(DocumentConverter.formatsFor('hello.pdf'), ['txt', 'docx', 'odt']);
    expect(DocumentConverter.formatsFor('old.doc'), isEmpty);
    expect(DocumentConverter.formatsFor('old.rtf'), isEmpty);
    expect(DocumentConverter.formatsFor('unknown.bin'), isEmpty);
    expect(
      DocumentConverter.warningFor('sheet.xlsx', 'pdf'),
      contains('formulas'),
    );
    expect(
      DocumentConverter.warningFor('slides.pptx', 'pdf'),
      contains('compare'),
    );
  });

  test('rejects unknown format combinations and empty input', () {
    expect(
      () => convert([1, 2, 3], 'source.exe', 'pdf'),
      throwsFormatException,
    );
    expect(() => convert([], 'source.txt', 'pdf'), throwsFormatException);
    expect(
      () => convert([1, 2, 3], 'source.txt', 'docx'),
      throwsFormatException,
    );
  });

  test('creates PDF from UTF-8 text, and recovers it as TXT', () {
    final pdf = convert(
      utf8.encode('Frogdadday document conversion\nSecond paragraph'),
      'letter.txt',
      'pdf',
    );
    expect(pdf.mimeType, 'application/pdf');
    expect(String.fromCharCodes(pdf.bytes.take(5)), '%PDF-');
    final plain = convert(pdf.bytes, 'letter.pdf', 'txt');
    expect(plain.extension, 'txt');
    expect(utf8.decode(plain.bytes), contains('Frogdadday'));
    expect(plain.fidelityWarning, isNotNull);
  });

  test('DOCX to PDF reopens with text and carries a fidelity warning', () {
    final source =
        (DocxDocumentBuilder()..paragraph('Frogdadday PDF engine smoke test'))
            .build();
    final converted = convert(source, 'letter.docx', 'pdf');
    expect(String.fromCharCodes(converted.bytes.take(5)), '%PDF-');
    final reopened = PdfFile.open(converted.bytes);
    expect(reopened.pageCount, greaterThan(0));
    expect(PdfExtract.documentText(reopened), contains('Frogdadday'));
    expect(converted.fidelityWarning, contains('best effort'));
  });

  test('PDF to DOCX creates a ZIP with real Word content', () {
    final pdf = convert(utf8.encode('Recover words'), 'words.txt', 'pdf');
    final docx = convert(pdf.bytes, 'words.pdf', 'docx');
    final office = OfficeTextExtractor.extract(docx.bytes, name: 'words.docx');
    expect(office.plainString, contains('Recover words'));
  });

  test('PDF to ODT makes ODF 1.2 ZIP with XML content and stored mimetype', () {
    final pdf = convert(
      utf8.encode('Paragraph one\nTwo & three'),
      'words.txt',
      'pdf',
    );
    final odt = convert(pdf.bytes, 'words.pdf', 'odt');
    final archive = ZipDecoder().decodeBytes(odt.bytes);
    final entries = {for (final entry in archive) entry.name: entry};
    expect(archive.first.name, 'mimetype');
    expect(entries.keys, contains('content.xml'));
    expect(entries.keys, contains('META-INF/manifest.xml'));
    final xml = utf8.decode(entries['content.xml']!.readBytes()!);
    expect(xml, contains('<office:document-content'));
    expect(xml, contains('Paragraph one'));
    expect(xml, contains('&amp;'));
    expect(odt.fidelityWarning, isNotNull);
  });

  test('basic ODT to PDF is explicitly warned as best effort', () {
    final original = convert(
      utf8.encode('From text to ODT'),
      'input.txt',
      'pdf',
    );
    final odt = convert(original.bytes, 'input.pdf', 'odt');
    final exported = convert(odt.bytes, 'input.odt', 'pdf');
    expect(String.fromCharCodes(exported.bytes.take(5)), '%PDF-');
    expect(exported.fidelityWarning, contains('Best-effort'));
  });

  test('image-only ODT reuses its safe embedded PDF fallback', () {
    final embeddedPdf = PdfDocument().save();
    const mime = 'application/vnd.oasis.opendocument.text';
    const content =
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<office:document-content '
        'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
        'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
        'office:version="1.2"><office:body><office:text><text:p/>'
        '</office:text></office:body></office:document-content>';
    final archive = Archive()
      ..addFile(
        ArchiveFile.noCompress('mimetype', mime.length, utf8.encode(mime)),
      )
      ..addFile(ArchiveFile.string('content.xml', content))
      ..addFile(
        ArchiveFile('Pictures/page.pdf', embeddedPdf.length, embeddedPdf),
      );
    final odt = ZipEncoder().encodeBytes(archive);
    final converted = convert(odt, 'scan.odt', 'pdf');
    expect(converted.bytes, embeddedPdf);
    expect(converted.fidelityWarning, contains('embedded PDF'));
  });

  test('bundled Unicode font preserves lines, Greek and emoji', () async {
    final data = await rootBundle.load(DocumentConverter.bundledFontAsset);
    final fontBytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    const source = 'First line\nGreek: αβγ\nEmoji: 😀\nconversion into PDF';
    final pdf = convert(
      utf8.encode(source),
      'unicode.txt',
      'pdf',
      fontBytes: fontBytes,
    );
    expect(
      latin1.decode(pdf.bytes, allowInvalid: true),
      isNot(contains('%FROG_TEXT_BEGIN')),
    );
    final text = utf8.decode(convert(pdf.bytes, 'unicode.pdf', 'txt').bytes);
    expect(text, contains('First line\nGreek: αβγ'));
    expect(text, contains('Emoji:'));
    expect(text, contains('conversion into PDF'));
    expect(DocumentConverter.pdfWarning, contains('emoji'));
  });

  test('blank lines are reconstructed only from visible PDF text', () async {
    final data = await rootBundle.load(DocumentConverter.bundledFontAsset);
    final fontBytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final pdf = convert(
      utf8.encode('Greek: αβγ\n\nEmoji: 😀\nFinal line'),
      'spacing.txt',
      'pdf',
      fontBytes: fontBytes,
    );

    final text = utf8.decode(convert(pdf.bytes, 'spacing.pdf', 'txt').bytes);
    expect(text, contains('Greek: αβγ'));
    expect(text, contains('Emoji:'));
    expect(text, contains('Final line'));
    expect(text, contains('\n\n'));
  });

  test('forged or stale hidden fallback markers never override visible text', () {
    final visible = convert(
      utf8.encode('Visible edited PDF text'),
      'visible.txt',
      'pdf',
    ).bytes;
    final forged = Uint8List.fromList([
      ...visible,
      ...ascii.encode(
        '\n%FROG_TEXT_BEGIN\n%${base64Encode(utf8.encode('Hidden stale secret'))}\n%FROG_TEXT_END\n',
      ),
    ]);

    final text = utf8.decode(convert(forged, 'edited.pdf', 'txt').bytes);
    expect(text, contains('Visible edited PDF text'));
    expect(text, isNot(contains('Hidden stale secret')));
  });

  test('UTF-8 text rejects malformed bytes', () {
    expect(
      () => convert([0xff, 0xfe, 0x00], 'broken.txt', 'pdf'),
      throwsFormatException,
    );
  });

  test('scanned/empty PDF text does not yield a fake editable document', () {
    final emptyPdf = PdfDocument().save();
    expect(() => convert(emptyPdf, 'empty.pdf', 'docx'), throwsFormatException);
  });

  test('rejects an Office archive claiming unsafe expanded content', () {
    final source = Uint8List.fromList(
      (DocxDocumentBuilder()..paragraph('tiny document')).build(),
    );
    final data = ByteData.sublistView(source);
    for (var offset = 0; offset + 46 <= source.length; offset++) {
      if (data.getUint32(offset, Endian.little) == 0x02014B50) {
        data.setUint32(offset + 24, 200 * 1024 * 1024, Endian.little);
        break;
      }
    }
    expect(() => convert(source, 'bomb.docx', 'pdf'), throwsFormatException);
  });
}
