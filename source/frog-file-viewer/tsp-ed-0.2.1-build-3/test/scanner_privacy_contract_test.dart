import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scanner stays separate from protected Cosmic Mode sources', () {
    final scanner = File('lib/viewers/document_scanner_page.dart')
        .readAsStringSync();
    expect(scanner, contains('CameraPreview('));
    expect(scanner, contains('Crop('));
    expect(scanner, contains('ReorderableListView.builder('));
    expect(scanner, contains('FilePicker.saveFile('));
    expect(scanner, contains("'frog_file_viewer/camera'"));
    expect(scanner, contains('invokeMethod<bool>'));
    expect(scanner, contains("'requestPermission'"));
    expect(scanner, contains('Camera permission was denied.'));
    expect(scanner, contains('|| _startingCamera'));
    expect(scanner, contains('_startingCamera = false;'));
    expect(scanner, contains('generation != _cameraGeneration'));
    expect(scanner, contains('Camera was interrupted.'));
    expect(scanner, isNot(contains('_restartCameraWhenReady')));
    expect(scanner, isNot(contains('state == AppLifecycleState.resumed')));
    expect(scanner, isNot(contains('http://')));
    expect(scanner, isNot(contains('https://')));
    expect(scanner, isNot(contains('mlkit')));
    expect(scanner, isNot(contains('ImageSource.camera')));
  });

  test('Android requests camera permission before CameraX initialization', () {
    final activity = File(
      'android/app/src/main/kotlin/com/frogdadday/frog_file_viewer/MainActivity.kt',
    ).readAsStringSync();
    expect(activity, contains('frog_file_viewer/camera'));
    expect(
      activity,
      contains('checkSelfPermission(Manifest.permission.CAMERA)'),
    );
    expect(activity, contains('requestPermissions('));
    expect(activity, contains('onRequestPermissionsResult('));
    expect(activity, contains('PackageManager.PERMISSION_GRANTED'));
  });

  test('camera permission does not add Internet or storage permission', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android.permission.CAMERA'));
    expect(manifest, isNot(contains('android.permission.INTERNET')));
    expect(
      manifest,
      matches(
        RegExp(r'android\.permission\.RECORD_AUDIO"\s+tools:node="remove"'),
      ),
    );
    expect(
      manifest,
      matches(
        RegExp(
          r'android\.permission\.READ_EXTERNAL_STORAGE"\s+tools:node="remove"',
        ),
      ),
    );
    expect(
      manifest,
      matches(
        RegExp(r'android\.hardware\.camera\.any"\s+android:required="false"'),
      ),
    );
    expect(manifest, isNot(contains('MANAGE_EXTERNAL_STORAGE')));
  });

  test('repository privacy summary explains optional local camera use', () {
    final policy = File('docs/PRIVACY_POLICY.md').readAsStringSync();
    expect(policy, contains('requests camera permission only'));
    expect(policy, contains('processed locally'));
    expect(policy, contains('temporary original is deleted'));
    expect(policy, contains('Denying camera permission'));
  });
}
