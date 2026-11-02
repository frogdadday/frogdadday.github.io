import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:image/image.dart' as img;

import 'file_tools.dart';

/// Validates and normalizes images before handing them to dart_pdf_editor.
///
/// The editor accepts PNG or JPEG bytes. WebP is decoded locally and emitted
/// as PNG when it has an alpha channel or JPEG when it does not. Decoding also
/// bakes EXIF orientation so the placed image has the same orientation the
/// user saw in their photo app.
class PdfImageInsert {
  const PdfImageInsert._();

  static const maxInputBytes = 15 * 1024 * 1024;
  static const maxPixelCount = 16 * 1000 * 1000;

  static bool isSupportedName(String name) =>
      FileTools.isSupportedImageName(name);

  static Uint8List normalize(Uint8List source) {
    if (source.isEmpty) {
      throw const FormatException('The selected image is empty.');
    }
    if (source.length > maxInputBytes) {
      throw const FormatException('Choose an image no larger than 15 MB.');
    }
    if (!_isJpeg(source) && !_isPng(source) && !_isWebP(source)) {
      throw const FormatException(
        'Choose a valid JPG, JPEG, PNG or WebP image.',
      );
    }

    // FileTools performs a bounded header inspection before full decode,
    // rejects images above 16 megapixels, and bakes EXIF orientation.
    late final img.Image decoded;
    try {
      decoded = FileTools.decodeImage(source);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'The selected file is not a valid JPG, JPEG, PNG or WebP image.',
      );
    }
    if (decoded.width * decoded.height > maxPixelCount) {
      throw const FormatException(
        'Image dimensions are too large. The limit is 16 megapixels.',
      );
    }

    return decoded.numChannels >= 4
        ? img.encodePng(decoded, level: 6)
        : img.encodeJpg(decoded, quality: 92);
  }

  /// Bakes inserted image stamps into the page content of a saved copy.
  ///
  /// Images remain ordinary editable annotations in the live editor and its
  /// recovery draft. Only the outbound copy is flattened, because some basic
  /// PDF readers ignore stamp annotations. Other markup stays as annotations.
  static Uint8List makeSavedCopyCompatible(Uint8List source) {
    final editing = PdfEditingController(source);
    try {
      final imageSlots = <(int, int)>[];
      for (
        var pageIndex = 0;
        pageIndex < editing.document.pageCount;
        pageIndex++
      ) {
        final annotations = editing.document.page(pageIndex).annotations;
        for (
          var annotationIndex = 0;
          annotationIndex < annotations.length;
          annotationIndex++
        ) {
          if (annotations[annotationIndex].isImageStamp) {
            imageSlots.add((pageIndex, annotationIndex));
          }
        }
      }
      if (imageSlots.isEmpty) return source;

      editing.selectAnnotationSlots(imageSlots);
      if (!editing.flattenSelectedAnnotations()) return source;
      return editing.bytes;
    } finally {
      editing.dispose();
    }
  }

  static bool _isJpeg(Uint8List bytes) =>
      bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;

  static bool _isPng(Uint8List bytes) =>
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a;

  static bool _isWebP(Uint8List bytes) =>
      bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;
}
