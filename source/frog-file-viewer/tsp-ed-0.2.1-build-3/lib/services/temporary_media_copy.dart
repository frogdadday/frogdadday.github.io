import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class PreviewCopyCancelled implements Exception {
  const PreviewCopyCancelled();
}

class TemporaryStorageProbe {
  const TemporaryStorageProbe._();

  static const MethodChannel _channel = MethodChannel(
    'frog_file_viewer/storage',
  );

  static Future<int?> availableBytes() async {
    try {
      return await _channel.invokeMethod<int>('availableTempBytes');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

/// Owns one provider-stream copy and can promptly cancel its subscription.
class TemporaryMediaCopy {
  StreamIterator<List<int>>? _iterator;
  RandomAccessFile? _output;
  bool _cancelled = false;

  Future<String> copy({
    required Stream<List<int>> chunks,
    required File partialFile,
    required File completedFile,
    required int maxBytes,
  }) async {
    final iterator = StreamIterator<List<int>>(chunks);
    _iterator = iterator;
    final output = await partialFile.open(mode: FileMode.write);
    _output = output;
    var received = 0;
    Object? primaryError;
    StackTrace? primaryStack;
    try {
      while (await iterator.moveNext()) {
        if (_cancelled) throw const PreviewCopyCancelled();
        final chunk = iterator.current;
        if (chunk.length > maxBytes - received) {
          throw const FormatException('File exceeds the preview size limit.');
        }
        received += chunk.length;
        // RandomAccessFile writes complete before another provider chunk is
        // requested, enforcing disk backpressure with bounded memory.
        await output.writeFrom(chunk);
      }
      if (_cancelled) throw const PreviewCopyCancelled();
      if (received == 0) throw const FormatException('This file is empty.');
      await output.flush();
      await output.close();
      _output = null;
      await partialFile.rename(completedFile.path);
      return completedFile.path;
    } catch (error, stackTrace) {
      primaryError = error;
      primaryStack = stackTrace;
    } finally {
      if (identical(_iterator, iterator)) {
        _iterator = null;
        try {
          await iterator.cancel();
        } catch (_) {
          // Never replace the stream/copy error with provider cleanup failure.
        }
      }
      if (identical(_output, output)) {
        _output = null;
        try {
          await output.close();
        } catch (_) {
          // Never replace the primary processing error.
        }
      }
      await _deleteBestEffort(partialFile);
    }
    Error.throwWithStackTrace(primaryError, primaryStack);
  }

  Future<void> cancel() async {
    _cancelled = true;
    final iterator = _iterator;
    try {
      await iterator?.cancel();
    } catch (_) {
      // Provider cancellation is best effort.
    }
    // The copy's finally block owns closing and deletion. Closing the output
    // here can race an in-flight write on Windows and leave a locked partial.
  }

  static Future<void> cleanupAfterRestart(Directory directory) async {
    if (!await directory.exists()) return;
    final now = DateTime.now();
    try {
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith('frog_preview_')) continue;
        if (name.endsWith('.partial')) {
          await _deleteBestEffort(entity);
          continue;
        }
        try {
          final modified = await entity.lastModified();
          if (now.difference(modified) > const Duration(hours: 24)) {
            await _deleteBestEffort(entity);
          }
        } on FileSystemException {
          // Stale-cache cleanup must not prevent opening a new preview.
        }
      }
    } on FileSystemException {
      // Cache enumeration is an optimization, not a reason to hide a file.
    }
  }

  static Future<void> _deleteBestEffort(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Cleanup failure must not hide the original operation result.
    }
  }
}
