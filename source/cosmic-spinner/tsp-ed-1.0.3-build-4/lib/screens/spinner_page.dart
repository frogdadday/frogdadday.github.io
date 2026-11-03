// ////Block One//////////////////////////////////////////////////////////////
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/spinner_model.dart';
import '../services/app_controller.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cosmic_scaffold.dart';
import '../widgets/spinner_wheel.dart';
import '../widgets/choices_sheet.dart';
import '../widgets/yellow_frog.dart';
import 'home_page.dart';

class SpinnerPage extends StatefulWidget {
  const SpinnerPage({
    super.key,
    required this.controller,
    required this.spinner,
  });

  final AppController controller;
  final SpinnerModel spinner;

  @override
  State<SpinnerPage> createState() => _SpinnerPageState();
}

class _SpinnerPageState extends State<SpinnerPage>
    with TickerProviderStateMixin {
  late final AnimationController spinController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..addListener(_spinChanged);
  late final AnimationController frogArrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..forward();
  late final AnimationController kickController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..addListener(_kickChanged);

  Animation<double>? rotationAnimation;
  double rotation = 0;
  bool spinning = false;
  bool hasSpun = false;
  bool allowPop = false;
  int selectedIndex = 0;
  int lastTick = 0;

  // The foot is the pointer at the upper-right (1:30) position.
  static const pointerAngle = -math.pi / 4;
  int _boundaryAt(double angle) =>
      ((angle - math.pi / 2 - pointerAngle) /
              (math.pi * 2 / widget.spinner.slices.length))
          .floor();

  @override
  void dispose() {
    spinController.dispose();
    frogArrival.dispose();
    kickController.dispose();
    super.dispose();
  }

  void _spinChanged() {
    final animation = rotationAnimation;
    if (animation == null) return;
    final next = animation.value;
    final tick = _boundaryAt(next);
    if (tick != lastTick) {
      lastTick = tick;
      SoundService.tick(enabled: widget.controller.soundOn);
    }
    setState(() => rotation = next);
  }

  void _kickChanged() {
    if (spinning && mounted) setState(() {});
  }

  ////Block Two////////////////////////////////////////////////////////////
  Future<void> _spin() async {
    if (spinning) return;
    selectedIndex = math.Random.secure().nextInt(widget.spinner.slices.length);
    final sweep = math.pi * 2 / widget.spinner.slices.length;
    final baseCenter = -math.pi / 2 + (selectedIndex + 0.5) * sweep;
    final normalizedTarget = (pointerAngle - baseCenter) % (math.pi * 2);
    final currentNormalized = rotation % (math.pi * 2);
    final correction = (normalizedTarget - currentNormalized) % (math.pi * 2);
    final end = rotation + math.pi * 2 * 7 + correction;
    rotationAnimation = Tween<double>(begin: rotation, end: end).animate(
      CurvedAnimation(parent: spinController, curve: Curves.easeOutQuart),
    );
    setState(() => spinning = true);
    lastTick = _boundaryAt(rotation);
    kickController.reset();
    SoundService.kick(enabled: widget.controller.soundOn);
    if (!MediaQuery.disableAnimationsOf(context)) {
      try {
        // Let the toe land on the wheel before the wheel can move.
        await kickController.forward(from: 0).orCancel;
      } on TickerCanceled {
        return;
      }
    } else {
      kickController.value = 1;
    }
    if (!mounted) return;
    spinController.reset();
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => rotation = end);
    } else {
      try {
        await spinController.forward().orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      spinning = false;
      hasSpun = true;
      rotation = end;
    });
    await SoundService.reveal(enabled: widget.controller.soundOn);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.auto_awesome_rounded,
          color: AppColors.frogYellow,
          size: 46,
        ),
        title: const Text('The cosmos has spoken'),
        scrollable: true,
        content: Text(
          widget.spinner.slices[selectedIndex].trim().isEmpty
              ? '(A gloriously blank slice)'
              : widget.spinner.slices[selectedIndex],
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: AppColors.frogYellow,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Receive the verdict'),
          ),
        ],
      ),
    );
  }

  Future<void> _finish() async {
    allowPop = true;
    await Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        builder: (_) => HomePage(controller: widget.controller),
      ),
      (route) => false,
    );
  }

  Future<void> _askToFinish() async {
    if (spinning) return;
    final finish = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Is fate finished?'),
        content: const Text(
          'Leave this spinner session and return the frog to the home stars?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep spinning'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fate Has Been Decided'),
          ),
        ],
      ),
    );
    if (finish == true && mounted) await _finish();
  }

  ////Block Three//////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _askToFinish();
      },
      child: CosmicScaffold(
        controller: widget.controller,
        showAppBarFrog: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final contentHeight = math.max(
              constraints.maxHeight,
              360.0 * MediaQuery.textScalerOf(context).scale(14) / 14,
            );
            return SingleChildScrollView(
              child: SizedBox(
                height: contentHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.spinner.title.trim().isEmpty
                                  ? '(Untitled Spinner)'
                                  : widget.spinner.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Flexible(
                            child: TextButton(
                              key: const Key('view-choices'),
                              onPressed: spinning
                                  ? null
                                  : () => showChoicesSheet(
                                      context,
                                      widget.spinner,
                                    ),
                              child: const Text(
                                'View choices',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, wheelConstraints) {
                            final stageSize = math.min(
                              wheelConstraints.maxWidth,
                              wheelConstraints.maxHeight,
                            );
                            final wheelSize = stageSize - 8;
                            final center = Offset(wheelSize / 2, wheelSize / 2);
                            final contact =
                                center +
                                Offset(
                                      math.cos(pointerAngle),
                                      math.sin(pointerAngle),
                                    ) *
                                    (wheelSize *
                                        SpinnerWheelPainter.radiusFraction);
                            // The extended toe lies at (-0.32, 0.72) in frog coordinates.
                            // Size and place the frog from that contact, keeping him on-screen.
                            final frogSize = math.min(
                              88.0,
                              (stageSize - contact.dx) / 1.32,
                            );
                            final frogOrigin =
                                contact -
                                YellowFrogPainter.extendedToe * frogSize;
                            return Center(
                              child: SizedBox.square(
                                dimension: stageSize,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: <Widget>[
                                    Positioned.fill(
                                      right: 8,
                                      bottom: 8,
                                      child: SpinnerWheel(
                                        spinner: widget.spinner,
                                        rotation: rotation,
                                        winningIndex: hasSpun && !spinning
                                            ? selectedIndex
                                            : null,
                                      ),
                                    ),
                                    Positioned(
                                      left: frogOrigin.dx,
                                      top: frogOrigin.dy,
                                      child: SlideTransition(
                                        position: reduceMotion
                                            ? const AlwaysStoppedAnimation<
                                                Offset
                                              >(Offset.zero)
                                            : Tween<Offset>(
                                                begin: const Offset(-0.9, -2.8),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: frogArrival,
                                                  curve: Curves.easeOutBack,
                                                ),
                                              ),
                                        child: AnimatedBuilder(
                                          animation: widget.controller,
                                          builder: (context, _) => YellowFrog(
                                            size: frogSize,
                                            cosmicMode:
                                                widget.controller.cosmicMode,
                                            hasLegs: true,
                                            kick: spinning
                                                ? Curves.easeOutCubic.transform(
                                                    kickController.value,
                                                  )
                                                : hasSpun
                                                ? 1
                                                : 0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (hasSpun && !spinning) ...[
                        const SizedBox(height: 8),
                        Container(
                          key: const Key('persistent-result'),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.frogYellow),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: math.max(
                                56,
                                math.min(140, constraints.maxHeight * 0.22),
                              ),
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'The winning choice',
                                    style: TextStyle(
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.spinner.slices[selectedIndex]
                                            .trim()
                                            .isEmpty
                                        ? '(A gloriously blank slice)'
                                        : widget.spinner.slices[selectedIndex],
                                    key: const Key('persistent-result-text'),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: AppColors.frogYellow,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (!hasSpun)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const Key('spin-button'),
                            onPressed: spinning ? null : _spin,
                            icon: spinning
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.public_rounded),
                            label: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                spinning
                                    ? 'The universe is deciding…'
                                    : 'Let the Universe Decide',
                              ),
                            ),
                          ),
                        )
                      else
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: FilledButton.icon(
                                key: const Key('spin-again-button'),
                                onPressed: spinning ? null : _spin,
                                icon: const Icon(Icons.replay_rounded),
                                label: const Text(
                                  'Let the Universe Decide Again',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const Key('finish-button'),
                                onPressed: spinning ? null : _finish,
                                icon: const Icon(Icons.done_all_rounded),
                                label: const Text('Fate Has Been Decided'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
