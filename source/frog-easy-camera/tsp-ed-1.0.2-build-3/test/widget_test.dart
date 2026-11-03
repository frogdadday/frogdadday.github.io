import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frog_easy_camera/camera_page.dart';
import 'package:frog_easy_camera/main.dart';

///// Block 1: Shared camera bridge setup //////////////////////////////////////

const bridge = MethodChannel('com.frogdadday.easy_camera/tools');

class FakeCameraPlatform extends CameraPlatform {
  FakeCameraPlatform({this.hasCamera = false});

  final bool hasCamera;
  int disposeCount = 0;
  int pictureCount = 0;
  int availableCameraCalls = 0;
  final _errors = StreamController<CameraErrorEvent>.broadcast();

  @override
  Future<List<CameraDescription>> availableCameras() async {
    availableCameraCalls++;
    return hasCamera
        ? const [
            CameraDescription(
              name: 'fake-camera',
              lensDirection: CameraLensDirection.back,
              sensorOrientation: 90,
            ),
          ]
        : const [];
  }

  @override
  Future<int> createCamera(
    CameraDescription cameraDescription,
    ResolutionPreset? resolutionPreset, {
    bool enableAudio = false,
  }) async => 7;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(
          cameraId,
          1280,
          720,
          ExposureMode.auto,
          true,
          FocusMode.auto,
          true,
        ),
      );

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _errors.stream;

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}

  @override
  Future<double> getMinZoomLevel(int cameraId) async => 1;

  @override
  Future<double> getMaxZoomLevel(int cameraId) async => 8;

  @override
  Future<void> setZoomLevel(int cameraId, double zoom) async {}

  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {}

  @override
  Future<XFile> takePicture(int cameraId) async {
    pictureCount++;
    return XFile('fake-picture-$pictureCount.jpg');
  }

  @override
  Widget buildPreview(int cameraId) => const ColoredBox(color: Colors.black);

  @override
  Future<void> pausePreview(int cameraId) async {}

  @override
  Future<void> resumePreview(int cameraId) async {}

  @override
  Future<void> dispose(int cameraId) async {
    disposeCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CameraPlatform originalCameraPlatform;
  late FakeCameraPlatform fakeCamera;

  setUpAll(() {
    originalCameraPlatform = CameraPlatform.instance;
  });

  setUp(() {
    fakeCamera = FakeCameraPlatform();
    CameraPlatform.instance = fakeCamera;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          if (call.method == 'needsPhotoStoragePermission') return false;
          if (call.method == 'preparePhotoStorage') return true;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, null);
  });

  tearDownAll(() {
    CameraPlatform.instance = originalCameraPlatform;
  });

  ///// Block 2: Standalone app behavior ///////////////////////////////////////

  testWidgets('opens directly to Frog Easy Camera', (tester) async {
    await tester.pumpWidget(const FrogEasyCameraApp());
    await tester.pumpAndSettle();

    expect(find.text('Frog Easy Camera'), findsOneWidget);
    expect(find.text('Try camera again'), findsOneWidget);
    expect(find.text('Use my phone’s camera instead'), findsOneWidget);
    expect(find.byKey(const Key('privacy-policy-button')), findsOneWidget);
    expect(find.byKey(const Key('frog-heart-button')), findsOneWidget);
  });

  testWidgets('does not ask for photo storage before capture', (tester) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          calls.add(call.method);
          return null;
        });

    await tester.pumpWidget(const FrogEasyCameraApp());
    await tester.pumpAndSettle();

    expect(calls, isNot(contains('needsPhotoStoragePermission')));
    expect(calls, isNot(contains('preparePhotoStorage')));
  });

  testWidgets('title buttons open the policy and optional support links', (
    tester,
  ) async {
    final opened = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          if (call.method == 'preparePhotoStorage') return false;
          opened.add(call.method);
          return true;
        });

    await tester.pumpWidget(const FrogEasyCameraApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('privacy-policy-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('frog-heart-button')));
    await tester.pump();

    expect(opened, containsAllInOrder(['openPrivacyPolicy', 'openSupport']));
  });

  testWidgets('recovery controls fit a small screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2.8)),
          child: EasyCameraPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Use my phone’s camera instead'),
      250,
    );
    expect(find.text('Use my phone’s camera instead'), findsOneWidget);
  });

  testWidgets('recovery actions are immediately visible on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FrogEasyCameraApp());
    await tester.pumpAndSettle();

    expect(find.text('Try camera again').hitTestable(), findsOneWidget);
    expect(
      find.text('Use my phone’s camera instead').hitTestable(),
      findsOneWidget,
    );
  });

  ///// Block 3: Permission, capture, sessions, and lifecycle //////////////////

  testWidgets('legacy storage access is explained and requested on capture', (
    tester,
  ) async {
    fakeCamera = FakeCameraPlatform(hasCamera: true);
    CameraPlatform.instance = fakeCamera;
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          calls.add(call.method);
          return switch (call.method) {
            'needsPhotoStoragePermission' => true,
            'preparePhotoStorage' => true,
            'savePhoto' => <String, Object?>{
              'name': 'FEC_test.jpg',
              'uri': 'content://test/photo',
            },
            _ => null,
          };
        });

    await tester.pumpWidget(const FrogEasyCameraApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take picture'));
    await tester.pumpAndSettle();

    expect(find.text('Allow saving this picture?'), findsOneWidget);
    expect(find.text(legacyPhotoStorageExplanation), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      calls,
      containsAllInOrder([
        'needsPhotoStoragePermission',
        'preparePhotoStorage',
        'savePhoto',
      ]),
    );
    expect(
      find.text('Saved FEC_test.jpg in the Frog Easy Camera album.'),
      findsOneWidget,
    );
  });

  testWidgets('interval Stop releases the keep-awake setting', (tester) async {
    fakeCamera = FakeCameraPlatform(hasCamera: true);
    CameraPlatform.instance = fakeCamera;
    final keepAwake = <bool>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          if (call.method == 'needsPhotoStoragePermission') return false;
          if (call.method == 'preparePhotoStorage') return true;
          if (call.method == 'setKeepScreenAwake') {
            keepAwake.add(
              (call.arguments as Map<Object?, Object?>)['keepAwake']! as bool,
            );
          }
          return null;
        });

    await tester.pumpWidget(const FrogEasyCameraApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interval'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 photos every 10 sec'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump();

    expect(keepAwake, contains(true));
    expect(find.text('Stop'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(keepAwake.last, isFalse);
  });

  testWidgets('camera controller is disposed and restored across lifecycle', (
    tester,
  ) async {
    fakeCamera = FakeCameraPlatform(hasCamera: true);
    CameraPlatform.instance = fakeCamera;

    await tester.pumpWidget(const FrogEasyCameraApp());
    await tester.pumpAndSettle();
    expect(find.text('Camera ready.'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(fakeCamera.disposeCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Camera ready.'), findsOneWidget);
    expect(fakeCamera.availableCameraCalls, greaterThanOrEqualTo(2));
  });

  ///// Block 4: Pure camera, permission, and storage rules ////////////////////

  test('pinch zoom scales and respects each camera limit', () {
    expect(
      zoomForPinch(zoomAtStart: 1, scale: 2.5, minimum: 1, maximum: 8),
      2.5,
    );
    expect(zoomForPinch(zoomAtStart: 4, scale: 3, minimum: 1, maximum: 8), 8);
    expect(zoomForPinch(zoomAtStart: 2, scale: 0.1, minimum: 1, maximum: 8), 1);
  });

  test('camera switching cycles through every reported camera', () {
    expect(nextCameraIndex(current: 0, cameraCount: 2), 1);
    expect(nextCameraIndex(current: 1, cameraCount: 2), 0);
    expect(nextCameraIndex(current: 2, cameraCount: 3), 0);
  });

  test('storage failures distinguish full, denied, and general errors', () {
    expect(photoSaveFailureMessage('storage_full'), contains('out of storage'));
    expect(photoSaveFailureMessage('storage_denied'), contains('not allowed'));
    expect(
      photoSaveFailureMessage('storage_failed'),
      contains('storage error'),
    );
    expect(
      photoSaveFailureMessage('storage_failed'),
      isNot(contains('out of storage')),
    );
  });
}
