import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../widgets/tie_dye_frog.dart';
import 'cosmic_motion.dart';

typedef CosmicFrameBuilder = Widget Function(
  BuildContext context,
  CosmicFrame frame,
);

/// A rendering state shared by the app background and the *existing* title.
/// No separate Cosmic Mode screen is involved.
class CosmicFrame {
  const CosmicFrame({
    required this.motion,
    required this.repaint,
    this.shader,
    this.frogBody,
  });

  final CosmicMotion motion;
  final Listenable repaint;
  final ui.FragmentShader? shader;
  final ui.Image? frogBody;
}

/// Owns one animation clock and cached GPU resources for the entire app.
/// Its [builder] is the regular app Scaffold, so editing, viewing and saving
/// remain accessible with the effects enabled.
class CosmicInlineStage extends StatefulWidget {
  const CosmicInlineStage({
    super.key,
    required this.builder,
    this.reduceMotion = false,
  });

  final CosmicFrameBuilder builder;
  final bool reduceMotion;

  @override
  State<CosmicInlineStage> createState() => _CosmicInlineStageState();
}

class _CosmicInlineStageState extends State<CosmicInlineStage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final CosmicMotion _motion = CosmicMotion();
  final _FramePulse _pulse = _FramePulse();
  late final Ticker _ticker;

  ui.Image? _frogBody;
  ui.FragmentShader? _shader;
  bool _appResumed = true;
  bool _systemReduceMotion = false;
  int? _previousMicros;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_advance);
    unawaited(_prepareFrog());
    unawaited(_prepareShader());
  }

  Future<void> _prepareShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/cosmic_lava.frag',
      );
      final shader = program.fragmentShader();
      if (!mounted) {
        shader.dispose();
        return;
      }
      setState(() => _shader = shader);
    } catch (error) {
      debugPrint('Cosmic liquid shader unavailable; using calm fallback: $error');
    }
  }

  /// Cache the original tie-dye body **once without its eyes**. The true
  /// liquefaction clips away its lower mass; separate intact eyes can then
  /// fall with the last drops, blink twice in the puddle, and return.
  Future<void> _prepareFrog() async {
    const pixels = 320;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const TieDyeFrogPainter(
      cosmicMode: true,
      drawEyes: false,
    ).paint(canvas, const Size(320, 320));
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(pixels, pixels);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _frogBody = image);
    } catch (error) {
      debugPrint('Cosmic tie-dye body cache unavailable: $error');
    } finally {
      picture.dispose();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _systemReduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant CosmicInlineStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reduceMotion != widget.reduceMotion) _syncTicker();
  }

  void _syncTicker() {
    final animate =
        _appResumed && !widget.reduceMotion && !_systemReduceMotion;
    if (animate && !_ticker.isActive) {
      _previousMicros = null;
      _ticker.start();
    } else if (!animate && _ticker.isActive) {
      _ticker.stop();
      _previousMicros = null;
    }
  }

  void _advance(Duration elapsed) {
    final now = elapsed.inMicroseconds;
    final before = _previousMicros;
    if (before == null) {
      _previousMicros = now;
      return;
    }
    final delta = (now - before) / Duration.microsecondsPerSecond;
    if (delta < 1 / 30) return;
    _previousMicros = now;
    _motion.advance(math.min(delta, 0.12));
    _pulse.tick();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _syncTicker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _pulse.dispose();
    _frogBody?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    CosmicFrame(
      motion: _motion,
      repaint: _pulse,
      shader: _shader,
      frogBody: _frogBody,
    ),
  );
}

class _FramePulse extends ChangeNotifier {
  void tick() => notifyListeners();
}
