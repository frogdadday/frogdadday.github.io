import 'dart:convert';

import 'package:make_my_phone_cosmically_easy/toolkit_frog_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_my_phone_cosmically_easy/camera_page.dart';
import 'package:make_my_phone_cosmically_easy/frog_heart_button.dart';
import 'package:make_my_phone_cosmically_easy/main.dart';
import 'package:make_my_phone_cosmically_easy/cosmic_mode.dart';
import 'package:make_my_phone_cosmically_easy/toolkit_frog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Running stopwatch resumes from Android recovered elapsed time',
    () async {
      var now = Duration.zero;
      final watch = PersistentStopwatch(clock: () => now);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge, (call) async {
            expect(call.method, 'loadStopwatch');
            return <String, Object>{'elapsedMillis': 5000, 'running': true};
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(bridge, null),
      );
      await watch.restore();
      expect(watch.isRunning, isTrue);
      expect(watch.elapsed, const Duration(seconds: 5));
      now = const Duration(seconds: 2);
      expect(watch.elapsed, const Duration(seconds: 7));
    },
  );

  test('Stopwatch only uses its monotonic clock', () {
    var elapsedClock = const Duration(minutes: 2);
    final watch = PersistentStopwatch(clock: () => elapsedClock);

    watch.start();
    elapsedClock = const Duration(minutes: 2, seconds: 5);
    expect(watch.elapsed, const Duration(seconds: 5));

    // Changing the wall clock cannot change this measurement because no wall
    // clock is used by PersistentStopwatch.
    elapsedClock = const Duration(minutes: 2, seconds: 9);
    expect(watch.elapsed, const Duration(seconds: 9));
  });

  testWidgets('Privacy Policy button opens the published policy', (
    tester,
  ) async {
    MethodCall? sent;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          sent = call;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge, null),
    );
    await tester.pumpWidget(const ToolkitApp());
    expect(find.text('Privacy Policy'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Privacy Policy'));
    await tester.pump();
    expect(sent?.method, 'openPrivacyPolicy');
  });

  testWidgets('Buy Me a Coffee heart link opens optional support', (
    tester,
  ) async {
    MethodCall? sent;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          sent = call;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FrogHeartButton(
            cosmicMode: false,
            onPressed: () => bridge.invokeMethod<void>('openSupport'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('frog-heart-button')));
    await tester.pump();
    expect(sent?.method, 'openSupport');
  });

  testWidgets(
    'Camera tool opens the easy camera with a phone-camera fallback',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge, (call) async {
            if (call.method == 'preparePhotoStorage') return false;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(bridge, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ToolPage(tool: tools.firstWhere((tool) => tool.id == 'camera')),
        ),
      );
      await tester.tap(find.text('Open easy camera'));
      await tester.pumpAndSettle();
      expect(find.byType(EasyCameraPage), findsOneWidget);
      expect(find.text('Before the camera opens'), findsOneWidget);
      expect(find.textContaining('Audio is always off'), findsOneWidget);
      expect(
        find.textContaining('does not read your other pictures'),
        findsOneWidget,
      );
      await tester.tap(find.text('Start easy camera'));
      await tester.pumpAndSettle();
      expect(find.text('Use my phone’s camera instead'), findsOneWidget);
    },
  );

  testWidgets('Camera recovery controls fit a small screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          if (call.method == 'preparePhotoStorage') return false;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge, null),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2.8)),
          child: EasyCameraPage(),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Start easy camera'), 250);
    await tester.tap(find.text('Start easy camera'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Use my phone’s camera instead'),
      250,
    );
    expect(find.text('Use my phone’s camera instead'), findsOneWidget);
  });

  testWidgets('Reviewed camera picture can become the Home background', (
    tester,
  ) async {
    Map<Object?, Object?>? wallpaperRequest;
    final onePixelPng = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          if (call.method == 'loadPhotoPreview') return onePixelPng;
          if (call.method == 'applyWallpaper') {
            wallpaperRequest = (call.arguments as Map).cast<Object?, Object?>();
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge, null),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: PhotoReviewPage(
          photos: [
            SavedCameraPhoto(name: 'CEP_test.jpg', uri: 'content://pictures/1'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make this my background'));
    await tester.pumpAndSettle();
    expect(find.text('Home screen'), findsOneWidget);
    expect(find.text('Lock screen'), findsOneWidget);
    expect(find.text('Both screens'), findsOneWidget);
    await tester.tap(find.text('Home screen'));
    await tester.pumpAndSettle();
    expect(wallpaperRequest?['target'], 'home');
    expect(
      find.text('This picture is now your Home screen background.'),
      findsOneWidget,
    );
  });

  testWidgets('Empty camera preview stays safe and disables wallpaper', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          if (call.method == 'loadPhotoPreview') return Uint8List(0);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge, null),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: PhotoReviewPage(
          photos: [
            SavedCameraPhoto(
              name: 'empty.jpg',
              uri: 'content://pictures/empty',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(
      find.text('This picture could not be opened for review.'),
      findsOneWidget,
    );
    final wallpaperButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Make this my background'),
    );
    expect(wallpaperButton.onPressed, isNull);
  });

  testWidgets('Review explains a partial two-screen wallpaper change', (
    tester,
  ) async {
    final onePixelPng = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          if (call.method == 'loadPhotoPreview') return onePixelPng;
          if (call.method == 'applyWallpaper') {
            throw PlatformException(code: 'wallpaper_partially_applied');
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge, null),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: PhotoReviewPage(
          photos: [
            SavedCameraPhoto(name: 'CEP_test.jpg', uri: 'content://pictures/1'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make this my background'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Both screens'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Home screen background was changed'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Frog keeps breathing and blinking after switching to Cosmic Mode',
    (tester) async {
      await tester.pumpWidget(const ToolkitApp());
      ToolkitFrogPainter frog() => tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(ToolkitFrog),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((w) => w.painter)
          .whereType<ToolkitFrogPainter>()
          .single;
      await tester.pump(const Duration(milliseconds: 900));
      final normal = frog();
      await tester.tap(find.widgetWithText(FilledButton, 'Cosmic Mode'));
      await tester.pump();
      expect(frog().cosmicMode, isTrue);
      expect(frog().shimmerValue, closeTo(normal.shimmerValue, 0.01));
      final before = frog();
      await tester.pump(const Duration(milliseconds: 600));
      expect(frog().headTilt, isNot(before.headTilt));
      expect(frog().squishY, isNot(before.squishY));
      await tester.pump(const Duration(milliseconds: 2580));
      expect(frog().slowBlink, greaterThan(0.8));
      await tester.pump(const Duration(milliseconds: 600));
      expect(frog().slowBlink, 0);
    },
  );

  testWidgets('Reduced motion keeps the cosmic frog still', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SizedBox(
            width: 96,
            height: 96,
            child: ToolkitFrog(cosmicMode: true),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<ToolkitFrogPainter>()
        .single;
    expect(painter.headTilt, 0);
    expect(painter.squishY, 1);
    expect(painter.slowBlink, 0);
  });
  testWidgets('Large text fits every tool on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const ToolkitApp());
    expect(tester.takeException(), isNull);
    final context = tester.element(find.byType(HomePage));
    for (final tool in tools) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => ToolPage(tool: tool)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: tool.id);
      Navigator.of(context).pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
  });

  tearDown(() {
    toolkitStopwatch.stop();
    toolkitStopwatch.reset();
  });

  testWidgets('Custom timer validates input and sends the chosen duration', (
    tester,
  ) async {
    MethodCall? sent;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          sent = call;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ToolPage(tool: tools.firstWhere((t) => t.id == 'timer')),
      ),
    );
    await tester.tap(find.text('Custom duration'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('Use this time'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number from 1 to 1,440.'), findsOneWidget);
    expect(sent, isNull);
    await tester.enterText(find.byType(TextFormField), '42');
    await tester.tap(find.text('Use this time'));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 42 minutes'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue in Clock'));
    await tester.tap(find.text('Continue in Clock'));
    await tester.pumpAndSettle();
    expect(sent!.arguments['minutes'], 42);
  });

  testWidgets('Custom timer limits oversized pasted input', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ToolPage(tool: tools.firstWhere((tool) => tool.id == 'timer')),
      ),
    );
    await tester.tap(find.text('Custom duration'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '999999999999999999');
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      '9999',
    );
    await tester.tap(find.text('Use this time'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number from 1 to 1,440.'), findsOneWidget);
  });

  testWidgets('Stopwatch survives leaving and reopening the tool', (
    tester,
  ) async {
    final tool = tools.firstWhere((t) => t.id == 'stopwatch');
    await tester.pumpWidget(MaterialApp(home: ToolPage(tool: tool)));
    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(toolkitStopwatch.isRunning, isTrue);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Reset'))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpWidget(MaterialApp(home: ToolPage(tool: tool)));
    expect(find.text('Stop'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(toolkitStopwatch.isRunning, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  test('All twenty-three launch commitments have unique entries', () {
    expect(tools.length, 23);
    expect(tools.map((t) => t.id).toSet().length, 23);
  });

  test('Requested tools are in the intended groups', () {
    String group(String id) => tools.firstWhere((tool) => tool.id == id).group;
    expect(group('contacts'), 'Everyday tools');
    expect(group('flashlight'), 'Everyday tools');
    expect(group('camera'), 'Everyday tools');
    expect(group('wallpaper'), 'Manage my phone');
    expect(group('keyboard'), 'Manage my phone');
    expect(group('ringtone'), 'Sound & quiet');
  });

  test('Tiles are alphabetized within their existing categories', () {
    for (final group in tools.map((tool) => tool.group).toSet()) {
      final titles = toolsInGroup(group).map((tool) => tool.title).toList();
      final alphabetizedTitles = List<String>.from(titles)
        ..sort(
          (first, second) =>
              first.toLowerCase().compareTo(second.toLowerCase()),
        );

      expect(titles, alphabetizedTitles, reason: group);
    }
  });

  testWidgets('Denied control explains and offers main settings', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          throw PlatformException(code: 'denied');
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ToolPage(tool: tools.firstWhere((t) => t.id == 'sound')),
      ),
    );
    await tester.tap(find.text('Open sound controls'));
    await tester.pumpAndSettle();
    expect(find.textContaining('didn’t allow'), findsOneWidget);
    expect(find.text('Open main settings'), findsOneWidget);
  });
  testWidgets(
    'Interrupted ringtone picker reports no change without a detour',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge, (call) async {
            throw PlatformException(code: 'cancelled');
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(bridge, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ToolPage(tool: tools.firstWhere((t) => t.id == 'ringtone')),
        ),
      );
      await tester.tap(find.text('Choose a ringtone'));
      await tester.pumpAndSettle();
      expect(find.text('No ringtone was changed.'), findsOneWidget);
      expect(find.text('Open main settings'), findsNothing);
    },
  );
  testWidgets('Failed ringtone application explains the safe fallback', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          throw PlatformException(code: 'ringtone_failed');
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ToolPage(tool: tools.firstWhere((t) => t.id == 'ringtone')),
      ),
    );
    await tester.tap(find.text('Choose a ringtone'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('could not apply that ringtone'),
      findsOneWidget,
    );
    expect(find.text('Open main settings'), findsOneWidget);
  });
  testWidgets('Successful handoff never claims the setting changed', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ToolPage(tool: tools.firstWhere((t) => t.id == 'sound')),
      ),
    );
    await tester.tap(find.text('Open sound controls'));
    await tester.pumpAndSettle();
    expect(find.text('Open main settings'), findsNothing);
    expect(find.textContaining('changed successfully'), findsNothing);
  });
  testWidgets('Home supports large text without layout errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: const HomePage(),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home shows the accessible animated frog mascot', (tester) async {
    await tester.pumpWidget(const ToolkitApp());
    expect(find.byType(ToolkitFrog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cosmic Mode changes the background, title, and mascot', (
    tester,
  ) async {
    await tester.pumpWidget(const ToolkitApp());
    await tester.tap(find.widgetWithText(FilledButton, 'Cosmic Mode'));
    await tester.pump();
    expect(find.byType(CosmicBackdrop), findsOneWidget);
    expect(find.byType(FlowingBlobTitle), findsOneWidget);
    expect(
      tester.widget<ToolkitFrog>(find.byType(ToolkitFrog)).cosmicMode,
      isTrue,
    );
  });
}
