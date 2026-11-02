import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/services/third_party_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'generated third-party notices appear in Flutter license registry',
    () async {
      registerBundledThirdPartyLicenses();
      // Calling twice must not create duplicate license entries.
      registerBundledThirdPartyLicenses();

      const packageName = 'Frog File Viewer — bundled third-party notices';
      final entries = <LicenseEntry>[];
      await for (final entry in LicenseRegistry.licenses) {
        if (entry.packages.contains(packageName)) entries.add(entry);
      }
      expect(entries, hasLength(1));
      final text = entries.single.paragraphs
          .map((part) => part.text)
          .join('\n');
      expect(text, contains('FROG FILE VIEWER'));
      expect(text, contains('THIRD-PARTY NOTICES'));
      expect(text, contains('ANDROID RUNTIME COMPONENT INVENTORY'));
      expect(text, contains('AndroidX Media3 / ExoPlayer'));
      expect(text, contains('Kotlin standard library'));
      expect(text, contains('Flutter Android embedding and engine'));
      expect(text, contains('Apache-2.0'));
      expect(text, contains('BSD-3-Clause'));
    },
  );

  test('every declared Android runtime component is in the bundle', () {
    final inventory = (jsonDecode(
      File('tool/android_third_party_components.json').readAsStringSync(),
    ) as List<Object?>).cast<Map<String, Object?>>();
    final notices = File('assets/THIRD_PARTY_NOTICES.txt').readAsStringSync();

    expect(inventory, isNotEmpty);
    for (final component in inventory) {
      final name = component['name']! as String;
      final version = component['version']! as String;
      final license = component['license']! as String;
      final source = component['source']! as String;
      final artifacts = (component['artifacts']! as List<Object?>)
          .cast<String>();

      expect(notices, contains('COMPONENT: $name'));
      expect(notices, contains('VERSION: $version'));
      expect(notices, contains('LICENSE: $license'));
      expect(notices, contains('SOURCE: $source'));
      expect(artifacts, isNotEmpty);
      for (final artifact in artifacts) {
        expect(notices, contains(artifact));
      }
    }
  });

  test('application delegates notice registration to one service', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final serviceSource = File('lib/services/third_party_licenses.dart')
        .readAsStringSync();

    expect(
      'registerBundledThirdPartyLicenses()'.allMatches(mainSource),
      hasLength(1),
    );
    expect(mainSource, isNot(contains('LicenseRegistry.addLicense')));
    expect(
      'LicenseRegistry.addLicense'.allMatches(serviceSource),
      hasLength(1),
    );
  });
}
