import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Reads picked files without assuming an Android filesystem path.
///
/// `PlatformFile.size` was removed in file_picker 12. Native metadata is
/// available via lengthSync(), which performs no filesystem read. When the
/// platform does not know the size, the stream limit still protects memory.
class BoundedFileReader {
  const BoundedFileReader._();

  static Future<Uint8List> read(
    PlatformFile file, {
    required int maxBytes,
    required String limitMessage,
  }) {
    return readStream(
      file.readAsByteStream(),
      reportedLength: file.lengthSync(),
      maxBytes: maxBytes,
      limitMessage: limitMessage,
    );
  }

  /// Also exercised with unknown size metadata, as can occur with SAF URIs.
  static Future<Uint8List> readStream(
    Stream<List<int>> chunks, {
    required int? reportedLength,
    required int maxBytes,
    required String limitMessage,
  }) async {
    if (reportedLength != null && reportedLength > maxBytes) {
      throw FormatException(limitMessage);
    }
    final builder = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk in chunks) {
      // Subtraction avoids integer overflow and prevents accepting a final
      // oversized chunk even if provider metadata was wrong or unavailable.
      if (chunk.length > maxBytes - received) {
        throw FormatException(limitMessage);
      }
      received += chunk.length;
      builder.add(chunk);
    }
    if (received == 0) {
      throw const FormatException('This file is empty.');
    }
    return builder.takeBytes();
  }
}
