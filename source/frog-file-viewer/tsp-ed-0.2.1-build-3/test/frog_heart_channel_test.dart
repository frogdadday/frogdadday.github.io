import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/widgets/frog_heart_button.dart';
import 'package:frog_file_viewer/widgets/privacy_policy_button.dart';

void main() {
  const channel = MethodChannel('frog_file_viewer/link');

  test('Android and Flutter use the same heart-support channel', () {
    final native = File(
      'android/app/src/main/kotlin/com/frogdadday/frog_file_viewer/'
      'MainActivity.kt',
    ).readAsStringSync();
    expect(native, contains('"frog_file_viewer/link"'));
    expect(native, contains('"openSupport"'));
    expect(native, contains('"openPrivacyPolicy"'));
    expect(
      native,
      contains('https://frogdadday.com/Frog-File-Viewer-Privacy-Policy/'),
    );
  });

  testWidgets('frog heart invokes the registered openSupport method', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    String? invoked;
    messenger.setMockMethodCallHandler(channel, (call) async {
      invoked = call.method;
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FrogHeartButton())),
    );
    await tester.tap(find.byKey(const Key('frog-heart-button')));
    await tester.pumpAndSettle();

    expect(invoked, 'openSupport');
    expect(
      find.text('The frog-heart portal drifted away. Try again soon.'),
      findsNothing,
    );
  });

  testWidgets('privacy button invokes the external policy method', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    String? invoked;
    messenger.setMockMethodCallHandler(channel, (call) async {
      invoked = call.method;
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PrivacyPolicyButton())),
    );
    await tester.tap(find.byKey(const Key('privacy-policy-button')));
    await tester.pumpAndSettle();

    expect(invoked, 'openPrivacyPolicy');
    expect(
      find.text('The privacy policy could not be opened. Please try again.'),
      findsNothing,
    );
  });
}
