import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('user documents are excluded from Android backup and transfers', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml')
        .readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    for (final section in ['cloud-backup', 'device-transfer']) {
      final start = rules.indexOf('<$section>');
      final end = rules.indexOf('</$section>');
      expect(start, greaterThanOrEqualTo(0), reason: '$section missing');
      expect(end, greaterThan(start), reason: '$section is not closed');
      final sectionRules = rules.substring(start, end);
      for (final domain in [
        'root',
        'file',
        'database',
        'sharedpref',
        'device_root',
        'device_file',
        'device_database',
        'device_sharedpref',
        'external',
      ]) {
        expect(
          sectionRules,
          contains('<exclude domain="$domain" path="." />'),
          reason: '$section must exclude the $domain data domain',
        );
      }
    }
  });

  test('release overlay removes dependency network permissions', () {
    final release = File('android/app/src/release/AndroidManifest.xml')
        .readAsStringSync();
    final debug = File('android/app/src/debug/AndroidManifest.xml')
        .readAsStringSync();

    for (final permission in const [
      'android.permission.INTERNET',
      'android.permission.ACCESS_NETWORK_STATE',
    ]) {
      expect(
        release,
        contains('android:name="$permission"'),
        reason: '$permission must be named in the release removal contract.',
      );
    }
    expect(
      RegExp(r'tools:node\s*=\s*"remove"').allMatches(release),
      hasLength(2),
    );
    expect(debug, contains('android.permission.INTERNET'));
    expect(debug, isNot(contains('android.permission.ACCESS_NETWORK_STATE')));
  });

  test('scanner removes unnecessary audio and broad storage permissions', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    for (final permission in [
      'android.permission.RECORD_AUDIO',
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.WRITE_EXTERNAL_STORAGE',
    ]) {
      expect(
        manifest,
        matches(RegExp('${RegExp.escape(permission)}"\\s+tools:node="remove"')),
      );
    }
    expect(manifest, contains('android.hardware.camera.any'));
    expect(manifest, contains('android:required="false"'));
  });

  test('application source has no in-process network client', () {
    final dartSource = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    expect(dartSource, isNot(contains("import 'package:http/")));
    expect(dartSource, isNot(contains('HttpClient(')));
    expect(dartSource, isNot(contains('WebSocket.connect')));
    expect(dartSource, isNot(contains('Socket.connect')));

    final native = File(
      'android/app/src/main/kotlin/com/frogdadday/frog_file_viewer/MainActivity.kt',
    ).readAsStringSync();
    expect(native, isNot(contains('WebView')));
    expect(native, isNot(contains('URLConnection')));
    expect(native, matches(RegExp(r'Intent\s*\(\s*Intent\.ACTION_VIEW')));
    expect(native, contains('openPrivacyPolicy'));
    expect(native, contains('openSupport'));
  });

  test(
    'permanent identity and fail-closed release signing remain enforced',
    () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('com.frogdadday.frog_file_viewer'));
      expect(gradle, contains('targetSdk = 36'));
      expect(gradle, contains('check(signingReady)'));
      expect(gradle, contains('frog-file-viewer-upload'));
      expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    },
  );
}
