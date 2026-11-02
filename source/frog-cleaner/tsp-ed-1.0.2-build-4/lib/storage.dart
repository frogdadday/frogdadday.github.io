import 'package:flutter/services.dart';

class StorageFile {
  StorageFile(Map<Object?, Object?> data)
    : id = data['id']! as String,
      name = data['name']! as String,
      location = data['location']! as String,
      parentId = data['parentId']! as String,
      size = (data['size'] as num?)?.toInt(),
      modified = (data['modified'] as num?)?.toInt(),
      canDelete = data['canDelete'] == true;
  final String id, name, location, parentId;
  final int? size, modified;
  final bool canDelete;
  String get category {
    if (!name.contains('.')) return 'Other files';
    final ext = name.toLowerCase().split('.').last;
    if (['mp4', 'mkv', 'mov', 'webm', 'avi'].contains(ext)) return 'Videos';
    if (['jpg', 'jpeg', 'png', 'webp', 'heic', 'gif'].contains(ext)) {
      return 'Photos';
    }
    if (['mp3', 'm4a', 'wav', 'ogg', 'flac'].contains(ext)) return 'Audio';
    if (ext == 'apk') return 'Installers';
    if (['zip', '7z', 'rar', 'tar', 'gz'].contains(ext)) return 'Archives';
    return 'Other files';
  }

  bool oldAt(DateTime now) {
    final date = validModifiedDate(modified, now: now);
    return date?.isBefore(now.subtract(const Duration(days: 365))) ?? false;
  }

  String reason(DateTime now) => category == 'Installers'
      ? 'Installation file. Keep it if you need it for reinstalling.'
      : oldAt(now)
      ? 'Last modified over a year ago. This does not mean unused.'
      : (size ?? 0) >= 100 * 1024 * 1024
      ? 'At least 100 MiB. Size does not mean it is unnecessary.'
      : 'Available for review. Only you can decide whether to keep it.';
}

DateTime? validModifiedDate(int? timestamp, {DateTime? now}) {
  if (timestamp == null || timestamp <= 0) return null;
  final comparison = now ?? DateTime.now();
  try {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
    if (date.year < 1970 ||
        date.isAfter(comparison.add(const Duration(days: 366)))) {
      return null;
    }
    return date;
  } on ArgumentError {
    return null;
  }
}

String bytes(int n) {
  if (n < 1024) return '$n B';
  if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KiB';
  if (n < 1024 * 1024 * 1024) {
    return '${(n / (1024 * 1024)).toStringAsFixed(1)} MiB';
  }
  return '${(n / (1024 * 1024 * 1024)).toStringAsFixed(2)} GiB';
}

List<StorageFile> uniqueFiles(Iterable<StorageFile> files) =>
    {for (final file in files) file.id: file}.values.toList();

bool canSelectDuplicateCopy(
  Iterable<String> groupIds,
  Set<String> selectedIds,
  String candidateId,
) {
  if (selectedIds.contains(candidateId)) return true;
  final group = groupIds.toSet();
  final selectedInGroup = selectedIds.where(group.contains).length;
  return selectedInGroup < group.length - 1;
}

class FolderSummary {
  const FolderSummary({
    required this.name,
    required this.path,
    required this.fileCount,
    required this.bytes,
    required this.unknownSizeCount,
    required this.directFiles,
  });

  final String name;
  final List<String> path;
  final int fileCount, bytes, unknownSizeCount;
  final bool directFiles;
}

List<String> storageSegments(String location) {
  var path = location.replaceAll('\\', '/');
  if (path.startsWith('/storage/emulated/0/')) {
    path = path.substring('/storage/emulated/0/'.length);
  } else if (path.startsWith('primary:')) {
    path = path.substring('primary:'.length);
  }
  return path.split('/').where((segment) => segment.isNotEmpty).toList();
}

bool isInFolder(StorageFile file, List<String> folder) {
  final parts = storageSegments(file.location);
  if (parts.length < folder.length + 1) return false;
  for (var index = 0; index < folder.length; index++) {
    if (parts[index] != folder[index]) return false;
  }
  return true;
}

bool isDownloadFile(StorageFile file) => storageSegments(file.location).any(
  (segment) =>
      segment.toLowerCase() == 'download' ||
      segment.toLowerCase() == 'downloads',
);

String downloadReason(StorageFile file, DateTime now) {
  if (file.category == 'Installers') return 'Installer file';
  if (file.category == 'Archives') return 'Downloaded archive';
  if ((file.size ?? 0) >= 100 * 1024 * 1024) return 'Large download';
  if (file.oldAt(now)) return 'Modified over a year ago';
  return 'Downloaded file';
}

List<FolderSummary> folderSummaries(
  Iterable<StorageFile> files,
  List<String> folder,
) {
  final groups = <String, _FolderTotals>{};
  for (final file in files) {
    final parts = storageSegments(file.location);
    if (!isInFolder(file, folder)) continue;
    final directoryParts = parts.sublist(0, parts.length - 1);
    final direct = directoryParts.length == folder.length;
    final name = direct
        ? 'Files in this folder'
        : directoryParts[folder.length];
    final key = direct ? '\u0000' : name;
    final totals = groups.putIfAbsent(
      key,
      () => _FolderTotals(
        name: name,
        path: direct ? folder : [...folder, name],
        directFiles: direct,
      ),
    );
    totals.fileCount++;
    totals.bytes += file.size ?? 0;
    if (file.size == null) totals.unknownSizeCount++;
  }
  return groups.values
      .map(
        (totals) => FolderSummary(
          name: totals.name,
          path: totals.path,
          fileCount: totals.fileCount,
          bytes: totals.bytes,
          unknownSizeCount: totals.unknownSizeCount,
          directFiles: totals.directFiles,
        ),
      )
      .toList()
    ..sort((a, b) => b.bytes.compareTo(a.bytes));
}

class _FolderTotals {
  _FolderTotals({
    required this.name,
    required this.path,
    required this.directFiles,
  });

  final String name;
  final List<String> path;
  final bool directFiles;
  int fileCount = 0, bytes = 0, unknownSizeCount = 0;
}

class StorageBridge {
  static const channel = MethodChannel('frog_cleaner/storage');
  Future<Map<Object?, Object?>> call(
    String method, [
    Map<String, Object?>? args,
  ]) async =>
      await channel.invokeMapMethod<Object?, Object?>(method, args) ?? {};
}
