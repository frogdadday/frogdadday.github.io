import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'frog_heart_button.dart';

///// Block 1: Native bridge and saved-photo model /////////////////////////////

const _cameraBridge = MethodChannel('com.frogdadday.easy_camera/tools');

double zoomForPinch({
  required double zoomAtStart,
  required double scale,
  required double minimum,
  required double maximum,
}) => (zoomAtStart * scale).clamp(minimum, maximum).toDouble();

int nextCameraIndex({required int current, required int cameraCount}) =>
    cameraCount <= 0 ? 0 : (current + 1) % cameraCount;

const legacyPhotoStorageExplanation =
    'On Android 9 and earlier, Android requires photo storage access before an app can save a new picture. Frog Easy Camera uses this access only to save pictures you take here. It does not browse, collect, or change your other files.';

String photoSaveFailureMessage(String code) => switch (code) {
  'storage_full' =>
    'Your phone is out of storage space. The last picture was not saved.',
  'storage_denied' =>
    'Photo storage access was not allowed, so the picture was not saved. Your other files were not read or changed.',
  _ =>
    'The picture could not be saved because the phone reported a storage error. Please try again.',
};

class SavedCameraPhoto {
  final String name;
  final String uri;

  const SavedCameraPhoto({required this.name, required this.uri});
}

class EasyCameraPage extends StatefulWidget {
  const EasyCameraPage({super.key});

  @override
  State<EasyCameraPage> createState() => _EasyCameraPageState();
}

///// Block 2: Camera lifecycle, lens selection, and zoom //////////////////////

class _EasyCameraPageState extends State<EasyCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _selectedCameraIndex = 0;
  bool _initializing = false;
  bool _switchingCamera = false;
  bool _takingPicture = false;
  bool _changingFlash = false;
  bool _preparingStorage = false;
  bool _flashOn = false;
  bool _sessionActive = false;
  bool _intervalActive = false;
  bool _cameraPageActive = true;
  int _sessionToken = 0;
  int _cameraInitToken = 0;
  int? _keepAwakeOwner;
  int? _countdown;
  int _picturesSaved = 0;
  int _intervalTotal = 0;
  double _minimumZoom = 1;
  double _maximumZoom = 1;
  double _currentZoom = 1;
  double _zoomAtGestureStart = 1;
  final List<SavedCameraPhoto> _sessionPhotos = [];
  String _status = 'Starting the camera…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraPageActive = false;
    _cameraInitToken++;
    _sessionToken++;
    unawaited(_setKeepScreenAwake(false));
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _cameraPageActive = false;
      _cameraInitToken++;
      if (_sessionActive) {
        _stopSession(
          'The camera was interrupted. $_picturesSaved ${_picturesSaved == 1 ? 'picture was' : 'pictures were'} saved.',
        );
      }
      final controller = _controller;
      _controller = null;
      if (controller != null) unawaited(controller.dispose());
      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      _cameraPageActive = true;
      if (_controller == null) {
        unawaited(_initializeCamera(cameraIndex: _selectedCameraIndex));
      }
    }
  }

  Future<void> _initializeCamera({int? cameraIndex}) async {
    if (_controller != null || _initializing || !_cameraPageActive) return;
    final initToken = ++_cameraInitToken;
    CameraController? controller;
    var controllerAttached = false;
    if (mounted) {
      setState(() {
        _initializing = true;
        _status = 'Starting the camera…';
      });
    }
    try {
      final cameras = await availableCameras();
      if (!_cameraInitializationIsCurrent(initToken)) return;
      if (cameras.isEmpty) {
        throw CameraException(
          'NoCamera',
          'This phone did not report an available camera.',
        );
      }
      _cameras = cameras;
      final requestedIndex = cameraIndex;
      final selectedIndex =
          requestedIndex != null &&
              requestedIndex >= 0 &&
              requestedIndex < cameras.length
          ? requestedIndex
          : cameras.indexWhere(
              (camera) => camera.lensDirection == CameraLensDirection.back,
            );
      _selectedCameraIndex = selectedIndex < 0 ? 0 : selectedIndex;
      final description = cameras[_selectedCameraIndex];
      controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!_cameraInitializationIsCurrent(initToken)) return;
      final minimumZoom = await controller.getMinZoomLevel();
      final maximumZoom = await controller.getMaxZoomLevel();
      final initialZoom = 1.0.clamp(minimumZoom, maximumZoom).toDouble();
      await controller.setZoomLevel(initialZoom);
      if (!_cameraInitializationIsCurrent(initToken)) return;
      try {
        await controller.setFlashMode(
          _flashOn ? FlashMode.always : FlashMode.off,
        );
      } on CameraException {
        _flashOn = false;
      }
      if (!_cameraInitializationIsCurrent(initToken)) return;
      setState(() {
        _controller = controller;
        _minimumZoom = minimumZoom;
        _maximumZoom = maximumZoom;
        _currentZoom = initialZoom;
        _zoomAtGestureStart = initialZoom;
        _status = 'Camera ready.';
      });
      controllerAttached = true;
    } on CameraException catch (error) {
      if (mounted && initToken == _cameraInitToken) {
        setState(() {
          _status = _cameraMessage(error.code);
        });
      }
    } on PlatformException catch (error) {
      if (mounted && initToken == _cameraInitToken) {
        setState(() {
          _status = _cameraMessage(error.code);
        });
      }
    } catch (_) {
      if (mounted && initToken == _cameraInitToken) {
        setState(() {
          _status = 'This phone could not start the camera. Please try again.';
        });
      }
    } finally {
      if (!controllerAttached) await controller?.dispose();
      if (mounted && initToken == _cameraInitToken) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  bool _cameraInitializationIsCurrent(int token) =>
      mounted && _cameraPageActive && token == _cameraInitToken;

  String _cameraMessage(String code) => switch (code) {
    'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' =>
      'Camera access was not allowed. Allow Camera permission in Android Settings, then return here and try again. Frog Easy Camera only uses it while the app is open.',
    'CameraAccessRestricted' =>
      'This phone has blocked camera access. A family or work setting may control it.',
    'StorageAccessDenied' =>
      'To save pictures on this older phone, allow photo storage access. Nothing else will be read or changed.',
    'NoCamera' =>
      'This phone did not report an available camera. Try your phone’s Camera app instead.',
    _ =>
      'The camera could not start on this phone. Try again, or use your phone’s Camera app instead.',
  };

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 ||
        _switchingCamera ||
        _takingPicture ||
        _sessionActive) {
      return;
    }
    setState(() {
      _switchingCamera = true;
      _status = 'Switching camera…';
    });
    final oldController = _controller;
    _controller = null;
    _cameraInitToken++;
    try {
      await oldController?.dispose();
      if (!mounted || !_cameraPageActive) return;
      final nextIndex = nextCameraIndex(
        current: _selectedCameraIndex,
        cameraCount: _cameras.length,
      );
      setState(() {
        _flashOn = false;
      });
      await _initializeCamera(cameraIndex: nextIndex);
    } on CameraException {
      if (mounted) {
        setState(() {
          _status = 'The camera could not switch lenses. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _switchingCamera = false;
        });
      }
    }
  }

  void _beginZoom(ScaleStartDetails _) {
    _zoomAtGestureStart = _currentZoom;
  }

  Future<void> _changeZoom(ScaleUpdateDetails details) async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        details.pointerCount < 2 ||
        _maximumZoom <= _minimumZoom) {
      return;
    }
    final zoom = zoomForPinch(
      zoomAtStart: _zoomAtGestureStart,
      scale: details.scale,
      minimum: _minimumZoom,
      maximum: _maximumZoom,
    );
    if ((zoom - _currentZoom).abs() < 0.01) return;
    setState(() => _currentZoom = zoom);
    try {
      await controller.setZoomLevel(zoom);
    } on CameraException {
      if (!mounted || !identical(_controller, controller)) return;
      setState(() {
        _status = 'This camera could not change zoom.';
      });
    }
  }

  Future<void> _setKeepScreenAwake(bool keepAwake) async {
    try {
      await _cameraBridge.invokeMethod<void>('setKeepScreenAwake', {
        'keepAwake': keepAwake,
      });
    } on PlatformException {
      // The photo session remains safe if a phone refuses this convenience.
    } on MissingPluginException {
      // Keeps previews and widget tests usable away from Android.
    }
  }

  Future<bool> _ensurePhotoStorageAccess() async {
    if (_preparingStorage) return false;
    setState(() {
      _preparingStorage = true;
    });
    try {
      final needsPermission =
          await _cameraBridge.invokeMethod<bool>(
            'needsPhotoStoragePermission',
          ) ??
          false;
      if (!mounted) return false;
      if (needsPermission) {
        final continueCapture = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Allow saving this picture?'),
            content: const Text(legacyPhotoStorageExplanation),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        if (continueCapture != true || !mounted) {
          if (mounted) {
            setState(() {
              _status =
                  'No picture was taken. Photo storage access is requested only when you choose to save a picture.';
            });
          }
          return false;
        }
      }
      final ready =
          await _cameraBridge.invokeMethod<bool>('preparePhotoStorage') ??
          false;
      if (!ready && mounted) {
        setState(() {
          _status = photoSaveFailureMessage('storage_denied');
        });
      }
      return ready;
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _status = photoSaveFailureMessage(error.code);
        });
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _preparingStorage = false;
        });
      }
    }
  }

  Future<bool> _prepareForCapture() async {
    if (!await _ensurePhotoStorageAccess()) return false;
    for (var attempt = 0; attempt < 100 && mounted; attempt++) {
      final controller = _controller;
      if (controller?.value.isInitialized == true) return true;
      if (_cameraPageActive && controller == null && !_initializing) {
        unawaited(_initializeCamera(cameraIndex: _selectedCameraIndex));
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (mounted) {
      setState(() {
        _status =
            'Photo storage is ready, but the camera did not restart. Tap Try camera again.';
      });
    }
    return false;
  }

  Future<void> _acquireKeepScreenAwake(int token) async {
    _keepAwakeOwner = token;
    await _setKeepScreenAwake(true);
  }

  Future<void> _releaseKeepScreenAwake(int token) async {
    if (_keepAwakeOwner != token) return;
    _keepAwakeOwner = null;
    await _setKeepScreenAwake(false);
  }

  Future<void> _openPhoneCamera() async {
    try {
      await _cameraBridge.invokeMethod<String>('perform', {'id': 'camera'});
    } on PlatformException {
      if (mounted) {
        setState(() {
          _status =
              'Your phone could not open its other camera app either. No picture was taken.';
        });
      }
    }
  }

  Future<void> _openPrivacyPolicy() async {
    try {
      await _cameraBridge.invokeMethod<void>('openPrivacyPolicy');
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _status = 'The privacy policy could not be opened. Please try again.';
      });
    }
  }

  Future<void> _openSupport() async {
    try {
      await _cameraBridge.invokeMethod<void>('openSupport');
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _status = 'The optional support page could not be opened.';
      });
    }
  }

  ///// Block 3: Flash, capture, timers, and interval sessions /////////////////

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _changingFlash) {
      return;
    }
    final turnOn = !_flashOn;
    setState(() {
      _changingFlash = true;
    });
    try {
      await controller.setFlashMode(turnOn ? FlashMode.always : FlashMode.off);
      if (mounted) {
        setState(() {
          _flashOn = turnOn;
          _status = turnOn
              ? 'Flash is on. It will flash when a picture is taken.'
              : 'Flash is off.';
        });
      }
    } on CameraException {
      if (mounted) {
        setState(() {
          _flashOn = false;
          _status = 'This camera does not offer a picture flash.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _changingFlash = false;
        });
      }
    }
  }

  Future<void> _openReview() async {
    if (_sessionPhotos.isEmpty) return;
    final controller = _controller;
    try {
      await controller?.pausePreview();
    } on CameraException {
      // The saved pictures can still be reviewed.
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PhotoReviewPage(photos: List.of(_sessionPhotos)),
      ),
    );
    if (!mounted || controller == null || !controller.value.isInitialized) {
      return;
    }
    try {
      await controller.resumePreview();
    } on CameraException {
      await controller.dispose();
      if (!mounted || !identical(_controller, controller)) return;
      setState(() {
        _controller = null;
        _status = 'The camera preview paused. Tap Try camera again if needed.';
      });
    }
  }

  Future<bool> _takeAndSavePicture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _takingPicture) {
      if (mounted) {
        setState(() {
          _status =
              'The camera is not ready to take a picture. Tap Try camera again.';
        });
      }
      return false;
    }
    if (mounted) {
      setState(() {
        _takingPicture = true;
        _status = 'Taking picture…';
      });
    }
    try {
      final picture = await controller.takePicture();
      final saved = await _cameraBridge.invokeMapMethod<String, Object?>(
        'savePhoto',
        {'path': picture.path},
      );
      final savedName = saved?['name'] as String?;
      final savedUri = saved?['uri'] as String?;
      if (savedName == null || savedUri == null) {
        throw PlatformException(code: 'storage_failed');
      }
      _picturesSaved++;
      if (mounted) {
        setState(() {
          _sessionPhotos.add(SavedCameraPhoto(name: savedName, uri: savedUri));
          _status = 'Saved $savedName in the Frog Easy Camera album.';
        });
      }
      return true;
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _status = error.code == 'captureAlreadyActive'
              ? 'The camera is still saving the last picture. Please wait.'
              : 'The camera could not take that picture. No unfinished picture was saved.';
        });
      }
      return false;
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _status = photoSaveFailureMessage(error.code);
        });
      }
      return false;
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'The picture could not be saved. Please try again.';
        });
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _takingPicture = false;
        });
      }
    }
  }

  Future<bool> _countDown(int seconds, int token, String label) async {
    for (var remaining = seconds; remaining > 0; remaining--) {
      if (!mounted || token != _sessionToken) return false;
      setState(() {
        _countdown = remaining;
        _status = '$label $remaining';
      });
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted || token != _sessionToken) return false;
    setState(() {
      _countdown = null;
    });
    return true;
  }

  Future<void> _takeOnePicture() async {
    if (!await _prepareForCapture()) return;
    _picturesSaved = 0;
    _sessionPhotos.clear();
    await _takeAndSavePicture();
  }

  Future<void> _startTimer(int seconds) async {
    if (_sessionActive || _takingPicture) return;
    if (!await _prepareForCapture()) return;
    final token = ++_sessionToken;
    setState(() {
      _sessionActive = true;
      _intervalActive = false;
      _picturesSaved = 0;
      _sessionPhotos.clear();
    });
    await _acquireKeepScreenAwake(token);
    try {
      if (await _countDown(seconds, token, 'Picture in')) {
        await _takeAndSavePicture();
      }
    } finally {
      if (mounted && token == _sessionToken) {
        setState(() {
          _sessionActive = false;
          _countdown = null;
        });
      }
      await _releaseKeepScreenAwake(token);
    }
  }

  Future<void> _startInterval(int total, int secondsBetween) async {
    if (_sessionActive || _takingPicture) return;
    if (!await _prepareForCapture()) return;
    final token = ++_sessionToken;
    setState(() {
      _sessionActive = true;
      _intervalActive = true;
      _picturesSaved = 0;
      _intervalTotal = total;
      _sessionPhotos.clear();
    });
    await _acquireKeepScreenAwake(token);
    String? failureMessage;
    try {
      if (!await _countDown(3, token, 'First picture in')) return;
      for (
        var pictureNumber = 1;
        pictureNumber <= total && token == _sessionToken;
        pictureNumber++
      ) {
        if (mounted) {
          setState(() {
            _status = 'Taking picture $pictureNumber of $total…';
          });
        }
        final saved = await _takeAndSavePicture();
        if (!saved || token != _sessionToken) {
          failureMessage = _status;
          break;
        }
        if (pictureNumber < total &&
            !await _countDown(secondsBetween, token, 'Next picture in')) {
          break;
        }
      }
      if (mounted && token == _sessionToken) {
        setState(() {
          _status = _picturesSaved == total
              ? 'All $total pictures were saved in the Frog Easy Camera album.'
              : failureMessage == null
              ? 'The interval stopped. $_picturesSaved of $total pictures were saved.'
              : '$failureMessage $_picturesSaved of $total pictures were saved.';
        });
      }
    } finally {
      if (mounted && token == _sessionToken) {
        setState(() {
          _sessionActive = false;
          _intervalActive = false;
          _countdown = null;
        });
      }
      await _releaseKeepScreenAwake(token);
    }
  }

  void _stopSession([String? message]) {
    if (!_sessionActive) return;
    final stoppedToken = _sessionToken;
    _sessionToken++;
    if (mounted) {
      setState(() {
        _sessionActive = false;
        _intervalActive = false;
        _countdown = null;
        _status =
            message ??
            'Stopped. $_picturesSaved ${_picturesSaved == 1 ? 'picture was' : 'pictures were'} saved.';
      });
    }
    unawaited(_releaseKeepScreenAwake(stoppedToken));
  }

  Future<void> _chooseTimer() async {
    final seconds = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('When should it take the picture?'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 5),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('In 5 seconds'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 10),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('In 10 seconds'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (seconds != null && mounted) unawaited(_startTimer(seconds));
  }

  Future<int?> _chooseNumber({
    required String question,
    required int initial,
    required int minimum,
    required int maximum,
    required List<int> commonChoices,
  }) => showDialog<int>(
    context: context,
    builder: (dialogContext) {
      var value = initial;
      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(question),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      iconSize: 36,
                      tooltip: 'Less',
                      onPressed: value <= minimum
                          ? null
                          : () => setDialogState(() => value--),
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        '$value',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                    IconButton.filledTonal(
                      iconSize: 36,
                      tooltip: 'More',
                      onPressed: value >= maximum
                          ? null
                          : () => setDialogState(() => value++),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final choice in commonChoices)
                      ChoiceChip(
                        label: Text('$choice'),
                        selected: value == choice,
                        onSelected: (_) => setDialogState(() => value = choice),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, value),
              child: const Text('Next'),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _setUpInterval() async {
    final setupChoice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('What are interval pictures?'),
        content: const Text(
          'Interval pictures let the camera take several pictures for you. '
          'You choose how many pictures it takes and how long it waits between them. '
          'Set your phone where you want it, press Start, and the camera does the rest.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, 'preset'),
            child: const Text('5 photos every 10 sec'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'custom'),
            child: const Text('Set it up'),
          ),
        ],
      ),
    );
    if (setupChoice == null || !mounted) return;
    if (setupChoice == 'preset') {
      final start = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ready to start?'),
          content: const Text(
            'The camera will take 5 pictures, 10 seconds apart. The first picture starts after a 3-second get-ready countdown. The screen stays on until it finishes or you press Stop.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Start'),
            ),
          ],
        ),
      );
      if (start == true && mounted) unawaited(_startInterval(5, 10));
      return;
    }
    final total = await _chooseNumber(
      question: 'How many pictures should it take in total?',
      initial: 5,
      minimum: 2,
      maximum: 50,
      commonChoices: const [2, 5, 10, 20, 50],
    );
    if (total == null || !mounted) return;
    final secondsBetween = await _chooseNumber(
      question:
          'How many seconds between each of your chosen number of pictures?',
      initial: 5,
      minimum: 1,
      maximum: 300,
      commonChoices: const [2, 5, 10, 30, 60],
    );
    if (secondsBetween == null || !mounted) return;
    final start = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ready to start?'),
        content: Text(
          'The camera will take $total pictures, with $secondsBetween ${secondsBetween == 1 ? 'second' : 'seconds'} between each picture. '
          'The first picture starts after a 3-second get-ready countdown. The screen will stay on until it finishes or you press Stop.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    if (start == true && mounted) {
      unawaited(_startInterval(total, secondsBetween));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller?.value.isInitialized == true;
    return PopScope(
      canPop: !_sessionActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _sessionActive) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press Stop before leaving the camera.'),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Frog Easy Camera',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              key: const Key('privacy-policy-button'),
              tooltip: 'Privacy Policy',
              onPressed: _openPrivacyPolicy,
              icon: const Icon(Icons.privacy_tip_outlined),
            ),
            FrogHeartButton(onPressed: _openSupport),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: (constraints.maxHeight * 0.52).clamp(220.0, 520.0),
                    child: Container(
                      width: double.infinity,
                      color: Colors.black,
                      child: !ready
                          ? Center(
                              child: _initializing
                                  ? const CircularProgressIndicator()
                                  : const Icon(
                                      Icons.no_photography_outlined,
                                      color: Colors.white,
                                      size: 72,
                                    ),
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                Semantics(
                                  label:
                                      'Camera preview. Pinch with two fingers to zoom.',
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onScaleStart: _beginZoom,
                                    onScaleUpdate: _changeZoom,
                                    child: Center(
                                      child: CameraPreview(controller!),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 12,
                                  top: 12,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      child: Text(
                                        '${_currentZoom.toStringAsFixed(1)}×  Pinch to zoom',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_countdown != null)
                                  ColoredBox(
                                    color: Colors.black45,
                                    child: Center(
                                      child: Semantics(
                                        liveRegion: true,
                                        label: '$_countdown',
                                        child: Text(
                                          '$_countdown',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 96,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _intervalActive
                                ? '$_status  $_picturesSaved of $_intervalTotal saved.'
                                : _status,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_sessionActive)
                          FilledButton.icon(
                            onPressed: _stopSession,
                            icon: const Icon(
                              Icons.stop_circle_outlined,
                              size: 32,
                            ),
                            label: const Text('Stop'),
                          )
                        else if (!ready && !_initializing) ...[
                          OutlinedButton(
                            onPressed: _initializeCamera,
                            child: const Text('Try camera again'),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: _openPhoneCamera,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Use my phone’s camera instead'),
                          ),
                        ] else if (ready) ...[
                          FilledButton.icon(
                            onPressed: !_takingPicture && !_preparingStorage
                                ? _takeOnePicture
                                : null,
                            icon: const Icon(Icons.camera_alt, size: 32),
                            label: const Text('Take picture'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: !_takingPicture && !_preparingStorage
                                ? _chooseTimer
                                : null,
                            icon: const Icon(Icons.timer_outlined, size: 30),
                            label: const Text('Timer'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: !_takingPicture && !_preparingStorage
                                ? _setUpInterval
                                : null,
                            icon: const Icon(
                              Icons.photo_library_outlined,
                              size: 30,
                            ),
                            label: const Text('Interval'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed:
                                !_takingPicture &&
                                    !_preparingStorage &&
                                    !_changingFlash
                                ? _toggleFlash
                                : null,
                            icon: Icon(
                              _flashOn ? Icons.flash_on : Icons.flash_off,
                              size: 30,
                            ),
                            label: Text(_flashOn ? 'Flash: On' : 'Flash: Off'),
                          ),
                          if (_cameras.length > 1) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed:
                                  !_takingPicture &&
                                      !_preparingStorage &&
                                      !_switchingCamera
                                  ? _switchCamera
                                  : null,
                              icon: const Icon(
                                Icons.cameraswitch_outlined,
                                size: 30,
                              ),
                              label: const Text('Switch camera'),
                            ),
                          ],
                          if (_sessionPhotos.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            FilledButton.tonalIcon(
                              onPressed: ready && !_takingPicture
                                  ? _openReview
                                  : null,
                              icon: const Icon(Icons.photo_outlined, size: 30),
                              label: Text(
                                _sessionPhotos.length == 1
                                    ? 'Review picture'
                                    : 'Review pictures',
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

///// Block 4: Saved-photo review and wallpaper actions ////////////////////////

class PhotoReviewPage extends StatefulWidget {
  final List<SavedCameraPhoto> photos;

  const PhotoReviewPage({super.key, required this.photos});

  @override
  State<PhotoReviewPage> createState() => _PhotoReviewPageState();
}

class _PhotoReviewPageState extends State<PhotoReviewPage> {
  int _index = 0;
  int _loadToken = 0;
  Uint8List? _preview;
  bool _loading = true;
  bool _applying = false;
  String? _message;

  SavedCameraPhoto get _photo => widget.photos[_index];

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreview());
  }

  Future<void> _loadPreview() async {
    final token = ++_loadToken;
    setState(() {
      _loading = true;
      _preview = null;
      _message = null;
    });
    try {
      final bytes = await _cameraBridge.invokeMethod<Uint8List>(
        'loadPhotoPreview',
        {'uri': _photo.uri},
      );
      if (!mounted || token != _loadToken) return;
      setState(() {
        _preview = bytes;
        _loading = false;
        if (bytes == null || bytes.isEmpty) {
          _message = 'This picture could not be opened for review.';
        }
      });
    } on PlatformException {
      if (mounted && token == _loadToken) {
        setState(() {
          _loading = false;
          _message = 'This picture could not be opened for review.';
        });
      }
    }
  }

  void _move(int change) {
    final next = (_index + change).clamp(0, widget.photos.length - 1);
    if (next == _index) return;
    setState(() {
      _index = next;
    });
    unawaited(_loadPreview());
  }

  Future<void> _chooseWallpaperTarget() async {
    final target = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Where should this background go?'),
        content: const Text(
          'Android may crop a little from the edges so the picture fits your screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'home'),
            child: const Text('Home screen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'lock'),
            child: const Text('Lock screen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'both'),
            child: const Text('Both screens'),
          ),
        ],
      ),
    );
    if (target == null || !mounted) return;
    setState(() {
      _applying = true;
      _message = 'Changing your background…';
    });
    try {
      await _cameraBridge.invokeMethod<void>('applyWallpaper', {
        'uri': _photo.uri,
        'target': target,
      });
      if (mounted) {
        setState(() {
          _message = switch (target) {
            'home' => 'This picture is now your Home screen background.',
            'lock' => 'This picture is now your Lock screen background.',
            _ => 'This picture is now the background on both screens.',
          };
        });
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _message = switch (error.code) {
            'wallpaper_not_allowed' =>
              'Your phone did not allow this app to change the background. The picture is still safely saved.',
            'wallpaper_partially_applied' =>
              'Your Home screen background was changed, but this phone did not allow the Lock screen change. The picture is still safely saved.',
            _ =>
              'Your phone could not use this picture as the background. The picture is still safely saved.',
          };
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _applying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review picture')),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: (constraints.maxHeight * 0.52).clamp(220.0, 520.0),
                child: Container(
                  width: double.infinity,
                  color: Colors.black,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _preview == null
                      ? const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white,
                            size: 72,
                          ),
                        )
                      : InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Center(
                            child: Image.memory(_preview!, fit: BoxFit.contain),
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.photos.length == 1
                          ? _photo.name
                          : 'Picture ${_index + 1} of ${widget.photos.length}',
                      textAlign: TextAlign.center,
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Text(_message!, textAlign: TextAlign.center),
                      ),
                    ],
                    if (widget.photos.length > 1) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _index > 0 && !_applying
                            ? () => _move(-1)
                            : null,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Previous'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed:
                            _index < widget.photos.length - 1 && !_applying
                            ? () => _move(1)
                            : null,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next'),
                      ),
                    ],
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _preview != null && !_applying
                          ? _chooseWallpaperTarget
                          : null,
                      icon: const Icon(Icons.wallpaper, size: 30),
                      label: const Text('Make this my background'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _applying
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Back to camera'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
