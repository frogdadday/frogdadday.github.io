import 'package:flutter/foundation.dart';

import 'storage.dart';

class CacheApp {
  const CacheApp({required this.packageName, required this.label});
  final String packageName, label;
}

class CacheAutomationStatus {
  const CacheAutomationStatus({
    required this.running,
    required this.enabled,
    required this.connected,
    this.message,
  });
  final bool running, enabled, connected;
  final String? message;
}

class CacheClearOutcome {
  const CacheClearOutcome({required this.bytes, required this.failures});
  final int bytes, failures;
}

class CacheStartOutcome {
  const CacheStartOutcome({required this.started, this.message});
  final bool started;
  final String? message;
}

class CacheAutomationController {
  CacheAutomationController({StorageBridge? bridge})
    : bridge = bridge ?? StorageBridge();
  final StorageBridge bridge;

  Future<List<CacheApp>> apps() async {
    final data = await bridge.call('cacheCandidates');
    final result = <CacheApp>[];
    for (final item in _list(data['apps'])) {
      if (item is! Map) continue;
      final packageName = item['package'];
      final label = item['label'];
      if (packageName is String && label is String) {
        result.add(CacheApp(packageName: packageName, label: label));
      } else {
        debugPrint('Frog Cleaner ignored a malformed cache-app entry.');
      }
    }
    return result;
  }

  Future<CacheAutomationStatus> status() async {
    final data = await bridge.call('cacheAutomationStatus');
    return CacheAutomationStatus(
      running: data['running'] == true,
      enabled: data['enabled'] == true,
      connected: data['connected'] == true,
      message: _text(data['message']),
    );
  }

  Future<CacheClearOutcome> clearOwnCache() async {
    final data = await bridge.call('clearCache');
    return CacheClearOutcome(
      bytes: (data['bytes'] as num?)?.toInt() ?? 0,
      failures: (data['failures'] as num?)?.toInt() ?? 0,
    );
  }

  Future<CacheStartOutcome> start(Iterable<String> packages) async {
    final data = await bridge.call('startCacheAutomation', {
      'packages': packages.toList(),
    });
    return CacheStartOutcome(
      started: data['started'] == true,
      message: _text(data['message']),
    );
  }

  Future<void> stop() async => bridge.call('stopCacheAutomation');
  Future<void> openAccessibilitySettings() async =>
      bridge.call('openCacheAccessibilitySettings');

  List<Object?> _list(Object? value) => value is List ? value : const [];
  String? _text(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}
