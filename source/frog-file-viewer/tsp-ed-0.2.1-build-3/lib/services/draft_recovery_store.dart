import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'file_tools.dart';

class RecoveryDraft {
  const RecoveryDraft({
    required this.bytes,
    required this.documentName,
    required this.savedAt,
  });

  final Uint8List bytes;
  final String documentName;
  final DateTime savedAt;
}

/// Short-lived, local-only crash recovery.
///
/// Each checkpoint is committed as a new PDF/metadata pair. The previous pair
/// is not removed until both new files have been flushed and renamed, so a
/// crash or failed rename cannot destroy the last usable recovery copy.
class DraftRecoveryStore {
  DraftRecoveryStore()
    : _rootOverride = null,
      _now = DateTime.now,
      _idFactory = null;

  DraftRecoveryStore.withRoot(
    this._rootOverride, {
    DateTime Function()? now,
    this._idFactory,
  }) : _now = now ?? DateTime.now;

  static const maxDraftBytes = 50 * 1024 * 1024;
  static const retention = Duration(hours: 24);

  final Directory? _rootOverride;
  final DateTime Function() _now;
  final String Function()? _idFactory;
  Future<void> _operationTail = Future<void>.value();
  int _sequence = 0;

  Future<Directory> _root() async {
    final base = _rootOverride ?? await getApplicationSupportDirectory();
    return Directory('${base.path}${Platform.pathSeparator}frog_pdf_recovery');
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _operationTail = _operationTail.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  String _nextId() {
    final supplied = _idFactory?.call();
    final id =
        supplied ?? '${_now().toUtc().microsecondsSinceEpoch}-${_sequence++}';
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'Unsafe recovery checkpoint id.');
    }
    return id;
  }

  Future<void> save(Uint8List bytes, String documentName) {
    if (bytes.isEmpty ||
        bytes.length > maxDraftBytes ||
        !FileTools.looksLikePdf(bytes)) {
      return Future<void>.value();
    }
    return _serialized(() => _save(bytes, documentName));
  }

  Future<void> _save(Uint8List bytes, String documentName) async {
    final root = await _root();
    await root.create(recursive: true);
    final id = _nextId();
    final prefix = '${root.path}${Platform.pathSeparator}draft-$id';
    final pdf = File('$prefix.pdf');
    final metadata = File('$prefix.json');
    final pdfTemp = File('${pdf.path}.tmp');
    final metadataTemp = File('${metadata.path}.tmp');
    var committed = false;
    try {
      await pdfTemp.writeAsBytes(bytes, flush: true);
      await metadataTemp.writeAsString(
        jsonEncode({
          'documentName': documentName,
          'savedAt': _now().toUtc().toIso8601String(),
        }),
        flush: true,
      );
      await pdfTemp.rename(pdf.path);
      await metadataTemp.rename(metadata.path);
      committed = true;
    } finally {
      for (final temporary in [pdfTemp, metadataTemp]) {
        await _deleteFileBestEffort(temporary);
      }
      if (!committed) {
        // Remove only the half-committed new id. Every previously completed
        // checkpoint remains available.
        await _deleteFileBestEffort(pdf);
        await _deleteFileBestEffort(metadata);
      }
    }
    await _cleanupExcept(root, {pdf.path, metadata.path});
  }

  Future<RecoveryDraft?> load() => _serialized(_load);

  Future<RecoveryDraft?> _load() async {
    final root = await _root();
    if (!await root.exists()) return null;

    final candidates = <({RecoveryDraft draft, File pdf, File metadata})>[];
    await for (final entity in root.list()) {
      if (entity is! File ||
          !entity.path.endsWith('.json') ||
          entity.path.endsWith('.json.tmp')) {
        continue;
      }
      final metadata = entity;
      final pdf = File(metadata.path.replaceFirst(RegExp(r'\.json$'), '.pdf'));
      try {
        final decoded = jsonDecode(await metadata.readAsString());
        if (decoded is! Map<String, dynamic>) throw const FormatException();
        final savedAt = DateTime.parse(decoded['savedAt'] as String).toUtc();
        final now = _now().toUtc();
        if (savedAt.isAfter(now.add(const Duration(minutes: 5))) ||
            now.difference(savedAt) > retention) {
          throw const FormatException('Recovery checkpoint expired.');
        }
        if (!await pdf.exists()) throw const FormatException();
        final length = await pdf.length();
        if (length <= 0 || length > maxDraftBytes) {
          throw const FormatException();
        }
        final bytes = await pdf.readAsBytes();
        if (!FileTools.looksLikePdf(bytes) ||
            !await compute(FileTools.canOpenEditablePdf, bytes)) {
          throw const FormatException('Recovery checkpoint contains a damaged PDF.');
        }
        candidates.add((
          draft: RecoveryDraft(
            bytes: bytes,
            documentName: decoded['documentName'] as String? ?? 'recovered.pdf',
            savedAt: savedAt,
          ),
          pdf: pdf,
          metadata: metadata,
        ));
      } catch (_) {
        await _deleteFileBestEffort(pdf);
        await _deleteFileBestEffort(metadata);
      }
    }

    if (candidates.isEmpty) {
      await _cleanupExcept(root, const <String>{});
      return null;
    }
    candidates.sort((a, b) => b.draft.savedAt.compareTo(a.draft.savedAt));
    final selected = candidates.first;
    await _cleanupExcept(root, {selected.pdf.path, selected.metadata.path});
    return selected.draft;
  }

  Future<void> delete() => _serialized(() async {
    final root = await _root();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<void> _cleanupExcept(Directory root, Set<String> keep) async {
    if (!await root.exists()) return;
    try {
      await for (final entity in root.list()) {
        if (entity is File && !keep.contains(entity.path)) {
          await _deleteFileBestEffort(entity);
        }
      }
      if (keep.isEmpty && await root.exists() && await root.list().isEmpty) {
        await root.delete();
      }
    } on FileSystemException {
      // Cleanup must not hide the successful operation or its primary error.
    }
  }

  static Future<void> _deleteFileBestEffort(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Preserve the operation's primary result/error.
    }
  }
}
