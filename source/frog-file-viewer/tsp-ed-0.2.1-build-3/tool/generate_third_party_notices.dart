import 'dart:collection';
import 'dart:convert';
import 'dart:io';

const _noticeNames = <String>{
  'license',
  'license.txt',
  'license.md',
  'copying',
  'copying.txt',
  'notice',
  'notice.txt',
};

void main() {
  final configFile = File('.dart_tool/package_config.json').absolute;
  if (!configFile.existsSync()) {
    stderr.writeln('Run flutter pub get before generating notices.');
    exitCode = 2;
    return;
  }

  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, Object?>;
  final packages = (config['packages']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final entries = <_Notice>[];
  final missing = <String>[];

  for (final package in packages) {
    final name = package['name']! as String;
    if (name == 'frog_file_viewer') continue;
    final rootUri = configFile.uri.resolve(package['rootUri']! as String);
    final root = Directory.fromUri(rootUri);
    final files = _licenseFiles(root);
    if (files.isEmpty) {
      final sdkLicense = _nearestSdkLicense(root);
      if (sdkLicense == null) {
        missing.add(name);
        continue;
      }
      files.add(sdkLicense);
    }
    for (final file in files) {
      final text = file
          .readAsStringSync()
          .replaceAll('\r\n', '\n')
          .replaceAll(RegExp(r'[ \t]+$', multiLine: true), '')
          .trim();
      if (text.isEmpty) continue;
      entries.add(_Notice(package: name, source: file.path, text: text));
    }
  }

  if (missing.isNotEmpty) {
    stderr.writeln('No license found for: ${missing.join(', ')}');
    exitCode = 1;
    return;
  }

  final grouped = <String, _NoticeGroup>{};
  for (final entry in entries) {
    final group = grouped.putIfAbsent(
      entry.text,
      () => _NoticeGroup(text: entry.text),
    );
    group.packages.add(entry.package);
    group.sources.add(_displayName(entry.source));
  }
  final groups = grouped.values.toList()
    ..sort((a, b) => a.packages.first.compareTo(b.packages.first));
  final nativeComponents = _nativeComponents();
  if (nativeComponents == null) return;
  final output = StringBuffer()
    ..writeln('FROG FILE VIEWER — THIRD-PARTY NOTICES')
    ..writeln()
    ..writeln(
      'Generated from the resolved Flutter package graph by '
      'tool/generate_third_party_notices.dart.',
    )
    ..writeln(
      'The notices below apply to their named components; they do not change '
      'the license of Frogdadday application code.',
    );
  output
    ..writeln()
    ..writeln('=' * 78)
    ..writeln('ANDROID RUNTIME COMPONENT INVENTORY')
    ..writeln('=' * 78)
    ..writeln(
      'This inventory is maintained in tool/android_third_party_components.json '
      'and must be reviewed against the resolved Gradle release graph before '
      'each public release.',
    );
  for (final component in nativeComponents) {
    output
      ..writeln()
      ..writeln('COMPONENT: ${component.name}')
      ..writeln('VERSION: ${component.version}')
      ..writeln('ARTIFACTS: ${component.artifacts.join(', ')}')
      ..writeln('LICENSE: ${component.license}')
      ..writeln('SOURCE: ${component.source}');
  }
  for (final group in groups) {
    output
      ..writeln()
      ..writeln('=' * 78)
      ..writeln('PACKAGES: ${group.packages.join(', ')}')
      ..writeln('NOTICE FILES: ${group.sources.join(', ')}')
      ..writeln('=' * 78)
      ..writeln(group.text);
  }

  final destination = File('assets/THIRD_PARTY_NOTICES.txt');
  destination.parent.createSync(recursive: true);
  destination.writeAsStringSync('${output.toString().trimRight()}\n');
  stdout.writeln(
    'Wrote ${groups.length} unique notices for ${entries.length} package '
    'entries to ${destination.path}.',
  );
}

List<_NativeComponent>? _nativeComponents() {
  final file = File('tool/android_third_party_components.json');
  if (!file.existsSync()) {
    stderr.writeln('Missing native component inventory: ${file.path}');
    exitCode = 2;
    return null;
  }
  try {
    final decoded = jsonDecode(file.readAsStringSync()) as List<Object?>;
    if (decoded.isEmpty) {
      throw const FormatException('inventory is empty');
    }
    final components = decoded
        .cast<Map<String, Object?>>()
        .map(
          (entry) => _NativeComponent(
            name: _requiredString(entry, 'name'),
            version: _requiredString(entry, 'version'),
            artifacts: _requiredStrings(entry, 'artifacts'),
            license: _requiredString(entry, 'license'),
            source: _requiredString(entry, 'source'),
          ),
        )
        .toList(growable: false);
    for (final component in components) {
      if (!const {'Apache-2.0', 'BSD-3-Clause'}.contains(component.license)) {
        throw FormatException(
          '${component.name} has unsupported license identifier '
          '${component.license}',
        );
      }
      final source = Uri.tryParse(component.source);
      if (source == null || source.scheme != 'https' || source.host.isEmpty) {
        throw FormatException('${component.name} has an invalid source URL');
      }
    }
    return components;
  } on Object catch (error) {
    stderr.writeln('Invalid native component inventory: $error');
    exitCode = 2;
    return null;
  }
}

String _requiredString(Map<String, Object?> entry, String key) {
  final value = entry[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('missing or empty $key');
  }
  return value.trim();
}

List<String> _requiredStrings(Map<String, Object?> entry, String key) {
  final value = entry[key];
  if (value is! List<Object?> || value.isEmpty) {
    throw FormatException('missing or empty $key');
  }
  return value
      .map((item) {
        if (item is! String || item.trim().isEmpty) {
          throw FormatException('$key contains an empty value');
        }
        return item.trim();
      })
      .toList(growable: false);
}

List<File> _licenseFiles(Directory root) {
  final result = <File>[];
  if (!root.existsSync()) return result;
  for (final entity in root.listSync(followLinks: false)) {
    if (entity is! File) continue;
    if (_noticeNames.contains(_baseName(entity.path).toLowerCase())) {
      result.add(entity);
    }
  }
  final assets = Directory('${root.path}${Platform.pathSeparator}assets');
  if (assets.existsSync()) {
    for (final entity in assets.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final name = _baseName(entity.path).toLowerCase();
      if (_noticeNames.contains(name) ||
          name.contains('-license.') ||
          name.contains('_license.')) {
        result.add(entity);
      }
    }
  }
  return result;
}

File? _nearestSdkLicense(Directory start) {
  var current = start;
  for (var depth = 0; depth < 8; depth++) {
    for (final name in const ['LICENSE', 'LICENSE.txt', 'LICENSE.md']) {
      final candidate = File('${current.path}${Platform.pathSeparator}$name');
      if (candidate.existsSync()) return candidate;
    }
    final parent = current.parent;
    if (parent.path == current.path) break;
    current = parent;
  }
  return null;
}

String _displayName(String path) {
  final parts = path.split(RegExp(r'[/\\]'));
  final assetsIndex = parts.lastIndexOf('assets');
  if (assetsIndex >= 0) return parts.sublist(assetsIndex).join('/');
  return parts.last;
}

String _baseName(String path) => path.split(RegExp(r'[/\\]')).last;

final class _Notice {
  const _Notice({
    required this.package,
    required this.source,
    required this.text,
  });

  final String package;
  final String source;
  final String text;
}

final class _NoticeGroup {
  _NoticeGroup({required this.text});

  final String text;
  final SplayTreeSet<String> packages = SplayTreeSet<String>();
  final SplayTreeSet<String> sources = SplayTreeSet<String>();
}

final class _NativeComponent {
  const _NativeComponent({
    required this.name,
    required this.version,
    required this.artifacts,
    required this.license,
    required this.source,
  });

  final String name;
  final String version;
  final List<String> artifacts;
  final String license;
  final String source;
}
