import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release manifest explicitly denies network permissions', () {
    final mainManifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final releaseManifest = File('android/app/src/release/AndroidManifest.xml')
        .readAsStringSync();

    expect(mainManifest, isNot(contains('android.permission.INTERNET')));
    expect(releaseManifest, contains('android.permission.INTERNET'));
    expect(
      releaseManifest,
      contains('android.permission.ACCESS_NETWORK_STATE'),
    );
    expect(
      RegExp(r'tools:node\s*=\s*"remove"').allMatches(releaseManifest).length,
      2,
    );
  });

  test('production Dart uses no network clients or remote media APIs', () {
    final source = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    final pubspec = File('pubspec.yaml').readAsStringSync();

    for (final dependency in [
      RegExp(r'^\s+http:', multiLine: true),
      RegExp(r'^\s+dio:', multiLine: true),
      RegExp(r'^\s+webview_flutter:', multiLine: true),
    ]) {
      expect(pubspec, isNot(matches(dependency)));
    }
    for (final api in [
      'HttpClient(',
      'WebSocket.connect(',
      'Socket.connect(',
      'Image.network(',
      'NetworkImage(',
      'VideoPlayerController.network',
      '.setUrl(',
    ]) {
      expect(source, isNot(contains(api)), reason: 'Network API found: $api');
    }

    final viewer = File('lib/viewers/file_preview_page.dart')
        .readAsStringSync();
    expect(viewer, contains('player.setFilePath('));
    expect(viewer, contains('VideoPlayerController.file('));
  });

  test('web addresses are handed only to an external browser', () {
    final native = File(
      'android/app/src/main/kotlin/com/frogdadday/frog_file_viewer/'
      'MainActivity.kt',
    ).readAsStringSync();
    final urls = RegExp(r'https://[^"\s)]+')
        .allMatches(native)
        .map((match) => match.group(0))
        .toList();

    expect(urls, [
      'https://buymeacoffee.com/frogdadday',
      'https://frogdadday.com/Frog-File-Viewer-Privacy-Policy/',
    ]);
    expect(native, contains('Intent.ACTION_VIEW'));
  });
}
