import 'package:flutter/foundation.dart';

import 'storage.dart';

class StorageStateData {
  const StorageStateData({
    required this.files,
    required this.roots,
    required this.ignored,
    required this.hasScan,
    required this.allFilesAccess,
    required this.scanStatusKnown,
    required this.scanCancelled,
    required this.scanLimited,
    required this.scanErrors,
    this.total,
    this.free,
    this.scanSavedAt,
    this.saveWarning,
  });

  final List<StorageFile> files;
  final List<Map<Object?, Object?>> roots, ignored;
  final bool hasScan, allFilesAccess, scanStatusKnown;
  final bool scanCancelled, scanLimited;
  final int scanErrors;
  final int? total, free, scanSavedAt;
  final String? saveWarning;
}

class ScanOutcome {
  const ScanOutcome({
    required this.files,
    required this.errors,
    required this.skipped,
    required this.cancelled,
    required this.limited,
    this.saveWarning,
  });

  final List<StorageFile> files;
  final int errors, skipped;
  final bool cancelled, limited;
  final String? saveWarning;
}

class DuplicateOutcome {
  const DuplicateOutcome({
    required this.groups,
    required this.hashed,
    required this.errors,
    required this.cancelled,
  });

  final List<List<String>> groups;
  final int hashed, errors;
  final bool cancelled;
}

class RemovalOutcome {
  const RemovalOutcome({
    required this.removed,
    required this.failed,
    required this.bytes,
    this.message,
    this.saveWarning,
  });

  final Set<String> removed;
  final List<String> failed;
  final int bytes;
  final String? message, saveWarning;
}

class StorageScanController {
  StorageScanController({StorageBridge? bridge})
    : bridge = bridge ?? StorageBridge();

  final StorageBridge bridge;

  Future<StorageStateData> readState() async {
    final data = await bridge.call('state');
    return StorageStateData(
      files: _files(data['files']),
      roots: _maps(data['roots']),
      ignored: _maps(data['ignored']),
      hasScan: data['hasScan'] == true,
      allFilesAccess: data['allFilesAccess'] == true,
      scanStatusKnown: data['scanStatusKnown'] == true,
      scanCancelled: data['scanCancelled'] == true,
      scanLimited: data['scanLimited'] == true,
      scanErrors: _integer(data['scanErrors']),
      total: _nullableInteger(data['total']),
      free: _nullableInteger(data['free']),
      scanSavedAt: _nullableInteger(data['scanSavedAt']),
      saveWarning: _text(data['saveWarning']),
    );
  }

  Future<ScanOutcome> scan() async {
    final data = await bridge.call('scan');
    return ScanOutcome(
      files: _files(data['files']),
      errors: _integer(data['errors']),
      skipped: _integer(data['skipped']),
      cancelled: data['cancelled'] == true,
      limited: data['limited'] == true,
      saveWarning: _text(data['saveWarning']),
    );
  }

  Future<DuplicateOutcome> findDuplicates() async {
    final data = await bridge.call('duplicates');
    final groups = <List<String>>[];
    for (final rawGroup in _list(data['groups'])) {
      if (rawGroup is! List) continue;
      final ids = <String>[];
      for (final rawItem in rawGroup) {
        if (rawItem is Map && rawItem['id'] is String) {
          ids.add(rawItem['id'] as String);
        }
      }
      if (ids.length > 1) groups.add(ids);
    }
    return DuplicateOutcome(
      groups: groups,
      hashed: _integer(data['hashed']),
      errors: _integer(data['errors']),
      cancelled: data['cancelled'] == true,
    );
  }

  Future<RemovalOutcome> delete(
    Iterable<String> ids,
    List<List<String>> duplicateRetainedGroups,
  ) async {
    final data = await bridge.call('delete', {
      'ids': ids.toList(),
      'duplicateRetainedGroups': duplicateRetainedGroups,
    });
    return _removal(data, 'deleted');
  }

  Future<RemovalOutcome> trash(
    Iterable<String> ids,
    List<List<String>> duplicateRetainedGroups,
  ) async {
    final data = await bridge.call('trash', {
      'ids': ids.toList(),
      'duplicateRetainedGroups': duplicateRetainedGroups,
    });
    return _removal(data, 'trashed');
  }

  Future<Uint8List?> thumbnail(String id, int maxDimension) async {
    final data = await bridge.call('thumbnail', {
      'id': id,
      'maxDimension': maxDimension,
    });
    final value = data['bytes'];
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    return null;
  }

  Future<String?> addFolder() => _message('pick');
  Future<String?> requestFullAnalysis() => _message('requestAllFilesAccess');
  Future<String?> openManageApps() => _message('openManageApps');
  Future<String?> openFile(String id) => _message('open', {'id': id});
  Future<void> ignore(String id, String label) async {
    await bridge.call('ignore', {'id': id, 'label': label});
  }

  Future<void> restoreExclusion(String id) async {
    await bridge.call('unignore', {'id': id});
  }

  Future<void> forgetFolder(String uri) async {
    await bridge.call('forget', {'uri': uri});
  }

  Future<void> cancel() async => bridge.call('cancel');
  Future<bool> openSupport() => _opened('openSupport');
  Future<bool> openPrivacyPolicy() => _opened('openPrivacyPolicy');

  Future<String?> _message(
    String method, [
    Map<String, Object?>? arguments,
  ]) async => _text((await bridge.call(method, arguments))['message']);

  Future<bool> _opened(String method) async =>
      (await bridge.call(method))['opened'] == true;

  RemovalOutcome _removal(Map<Object?, Object?> data, String key) =>
      RemovalOutcome(
        removed: _list(data[key]).whereType<String>().toSet(),
        failed: _list(data['failed']).whereType<String>().toList(),
        bytes: _integer(data['bytes']),
        message: _text(data['message']),
        saveWarning: _text(data['saveWarning']),
      );

  List<StorageFile> _files(Object? value) {
    final result = <StorageFile>[];
    for (final item in _list(value)) {
      if (item is! Map) continue;
      try {
        result.add(StorageFile(item.cast<Object?, Object?>()));
      } on Object catch (error) {
        debugPrint('Frog Cleaner ignored malformed file metadata: $error');
      }
    }
    return uniqueFiles(result)
      ..sort((a, b) => (b.size ?? -1).compareTo(a.size ?? -1));
  }

  List<Map<Object?, Object?>> _maps(Object? value) => _list(
    value,
  ).whereType<Map>().map((item) => item.cast<Object?, Object?>()).toList();

  List<Object?> _list(Object? value) => value is List ? value : const [];
  int _integer(Object? value) => (value as num?)?.toInt() ?? 0;
  int? _nullableInteger(Object? value) => (value as num?)?.toInt();
  String? _text(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}
