import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'camera_page.dart';
import 'timer_duration_dialog.dart';
import 'cosmic_mode.dart';
import 'frog_heart_button.dart';
import 'toolkit_frog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await toolkitStopwatch.restore();
  runApp(const ToolkitApp());
}

const bridge = MethodChannel('com.frogdadday.android_toolkit/tools');

class Tool {
  final String id, title, help, group;
  final IconData icon;
  const Tool(this.id, this.title, this.help, this.group, this.icon);
}

const tools = <Tool>[
  Tool(
    'messages',
    'Messages',
    'Read or write a message in your phone’s messaging app.',
    'Everyday tools',
    Icons.chat_bubble_outline,
  ),
  Tool(
    'volume',
    'Volume',
    'Move the volume sliders to make sounds louder or quieter. Calls, alarms, and music can have separate sliders.',
    'Everyday tools',
    Icons.volume_up,
  ),
  Tool(
    'power',
    'Power off',
    'Android does not give this app direct access to the power menu. These steps help you turn off your phone using its own controls.',
    'Everyday tools',
    Icons.power_settings_new,
  ),
  Tool(
    'flashlight',
    'Flashlight',
    'Turn your phone’s light on or off. The light turns off when you leave Cosmic Easy Phone.',
    'Everyday tools',
    Icons.flashlight_on_outlined,
  ),
  Tool(
    'camera',
    'Take a picture',
    'Use a simple camera to take one picture, use a 5- or 10-second timer, or take interval pictures automatically. Pictures save in the Cosmic Easy Phone album on this phone.',
    'Everyday tools',
    Icons.photo_camera_outlined,
  ),
  Tool(
    'contacts',
    'My contacts',
    'Open your phone’s contact list directly to find, call, add, or update a person.',
    'Everyday tools',
    Icons.contacts_outlined,
  ),
  Tool(
    'sound',
    'Ring, vibrate or silent',
    'Choose how your phone sounds for calls. Look for Sound mode or Ring volume. Alarm and media volume are separate.',
    'Sound & quiet',
    Icons.volume_up_outlined,
  ),
  Tool(
    'dnd',
    'Do Not Disturb',
    'Choose which calls and alerts can interrupt you. Look for Do Not Disturb or Modes. Other schedules may keep quiet mode on.',
    'Sound & quiet',
    Icons.do_not_disturb_on_outlined,
  ),
  Tool(
    'ringtone',
    'Choose my ringtone',
    'Listen to your phone’s ringtones and choose the sound used for incoming calls. The first time, Android may ask you to allow Cosmic Easy Phone to change system settings so it can apply your choice.',
    'Sound & quiet',
    Icons.music_note_outlined,
  ),
  Tool(
    'text',
    'Make text bigger',
    'Look for Font size. You can return to the same setting to make words smaller again.',
    'Make things easier to see',
    Icons.text_fields,
  ),
  Tool(
    'display',
    'Make everything bigger',
    'Look for Display size or Screen zoom to make buttons and words larger.',
    'Make things easier to see',
    Icons.zoom_in,
  ),
  Tool(
    'icons',
    'Make icons bigger',
    'On your home screen, touch and hold an empty area. Look for Home settings, Wallpaper & style, Icon size or Grid. Some launchers do not offer this option.',
    'Make things easier to see',
    Icons.apps,
  ),
  Tool(
    'brightness',
    'Screen brightness',
    'Look for Brightness. Adaptive brightness lets your phone adjust it for you.',
    'Make things easier to see',
    Icons.brightness_6_outlined,
  ),
  Tool(
    'timeout',
    'When my screen turns off',
    'Look for Screen timeout or Sleep. Choose how long the screen stays on when you are not using it.',
    'Make things easier to see',
    Icons.screen_lock_portrait_outlined,
  ),
  Tool(
    'rotate',
    'Turn screen with my phone',
    'Look for Auto-rotate screen. Turn it off to keep your screen upright.',
    'Make things easier to see',
    Icons.screen_rotation,
  ),
  Tool(
    'stopwatch',
    'Stopwatch',
    'Measure how long something takes.',
    'Alarms & timers',
    Icons.timer_outlined,
  ),
  Tool(
    'timer',
    'Set a timer',
    'A timer counts down and alerts you. Choose a duration, then review it in your Clock app.',
    'Alarms & timers',
    Icons.hourglass_bottom,
  ),
  Tool(
    'alarm',
    'Set an alarm',
    'Choose a time, then review and save it in your Clock app.',
    'Alarms & timers',
    Icons.alarm,
  ),
  Tool(
    'apps',
    'Remove an app',
    'Choose an app, then look for Uninstall. Your phone will ask before removing it. Some built-in apps cannot be removed.',
    'Manage my phone',
    Icons.apps_outage_outlined,
  ),
  Tool(
    'wallpaper',
    'Change wallpaper',
    'Choose a picture in your phone’s wallpaper tool, then choose where to use it. Review your choice before applying it.',
    'Manage my phone',
    Icons.wallpaper,
  ),
  Tool(
    'keyboard',
    'Change my keyboard',
    'Open keyboard settings to choose your on-screen or default keyboard.',
    'Manage my phone',
    Icons.keyboard_outlined,
  ),
  Tool(
    'storage',
    'Understand my storage',
    'See what is taking up space. Review files before deleting anything. Cosmic Easy Phone does not delete files for you.',
    'Manage my phone',
    Icons.storage_outlined,
  ),
  Tool(
    'battery',
    'Make my battery last longer',
    'Look for Battery Saver or Power saving. It may limit background activity. You can turn it off in the same place.',
    'Manage my phone',
    Icons.battery_saver_outlined,
  ),
];

List<Tool> toolsInGroup(String group) {
  final groupTools = tools.where((tool) => tool.group == group).toList();
  groupTools.sort(
    (first, second) =>
        first.title.toLowerCase().compareTo(second.title.toLowerCase()),
  );
  return groupTools;
}

class LargerTextScaler extends TextScaler {
  const LargerTextScaler(this.system);
  final TextScaler system;
  @override
  double scale(double fontSize) => system.scale(fontSize) * 1.4;
  @override
  double get textScaleFactor => system.scale(1) * 1.4;
}

double titleHeight(BuildContext context, String title, double width) {
  final painter = TextPainter(
    text: TextSpan(text: title, style: Theme.of(context).textTheme.titleLarge),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: width.clamp(40.0, double.infinity));
  final height = painter.height + 24;
  painter.dispose();
  return height < kToolbarHeight ? kToolbarHeight : height;
}

class ToolkitApp extends StatelessWidget {
  const ToolkitApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cosmic Easy Phone',
    debugShowCheckedModeBanner: false,
    builder: (context, child) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(textScaler: LargerTextScaler(media.textScaler)),
        child: child ?? const SizedBox.shrink(),
      );
    },
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff4b3020))
          .copyWith(
            primary: const Color(0xff4b3020),
            onSurface: const Color(0xff4b3020),
            onSurfaceVariant: const Color(0xff4b3020),
            outline: const Color(0xff4b3020),
          ),
      scaffoldBackgroundColor: const Color(0xfff7f8f3),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          foregroundColor: const Color(0xff4b3020),
          backgroundColor: const Color(0xfff0e6dc),
          side: const BorderSide(color: Color(0xff4b3020)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xff4b3020),
          side: const BorderSide(color: Color(0xff4b3020)),
        ),
      ),
      cardTheme: const CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Color(0xff4b3020)),
        ),
      ),
      textTheme: ThemeData.light().textTheme
          .copyWith(bodyLarge: const TextStyle(fontSize: 18, height: 1.5))
          .apply(
            bodyColor: const Color(0xff4b3020),
            displayColor: const Color(0xff4b3020),
          ),
    ),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool cosmicMode = false;

  Future<void> _openPrivacyPolicy() async {
    try {
      await bridge.invokeMethod<void>('openPrivacyPolicy');
    } on PlatformException {
      await _showPrivacyOpenError();
    } on MissingPluginException {
      await _showPrivacyOpenError();
    }
  }

  Future<void> _openSupport() async {
    try {
      await bridge.invokeMethod<void>('openSupport');
    } on PlatformException {
      await _showSupportOpenError();
    } on MissingPluginException {
      await _showSupportOpenError();
    }
  }

  Future<void> _showPrivacyOpenError() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.privacy_tip_outlined, size: 40),
        title: const Text('Privacy Policy'),
        content: const Text(
          'Your phone could not open the privacy policy in a browser. '
          'Nothing was changed. Please check that a browser is available and try again.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSupportOpenError() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.favorite_outline, size: 40),
        title: const Text('Buy Me a Coffee'),
        content: const Text(
          'Your phone could not open the support page in a browser. Nothing was changed. Please check that a browser is available and try again.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rootTheme = Theme.of(context);
    final modeTheme = cosmicMode
        ? rootTheme.copyWith(
            textTheme: rootTheme.textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 56),
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xff9d0c62),
                side: const BorderSide(color: Color(0xffff8fc8)),
              ),
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xffff4eaa),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: Colors.transparent,
            cardTheme: const CardThemeData(
              color: Color(0xdd260024),
              surfaceTintColor: Colors.transparent,
            ),
          )
        : rootTheme;
    return Theme(
      data: modeTheme,
      child: Scaffold(
        extendBodyBehindAppBar: cosmicMode,
        backgroundColor: cosmicMode ? Colors.transparent : null,
        appBar: AppBar(
          backgroundColor: cosmicMode ? Colors.transparent : null,
          toolbarHeight: titleHeight(
            context,
            'Cosmic Easy Phone',
            MediaQuery.sizeOf(context).width - 40,
          ),
          elevation: 0,
          title: cosmicMode
              ? const FlowingBlobTitle(text: 'Cosmic Easy Phone')
              : const Text('Cosmic Easy Phone'),
        ),
        body: Stack(
          children: [
            if (cosmicMode) const Positioned.fill(child: CosmicBackdrop()),
            ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                cosmicMode
                    ? titleHeight(
                            context,
                            'Cosmic Easy Phone',
                            MediaQuery.sizeOf(context).width - 40,
                          ) +
                          MediaQuery.paddingOf(context).top +
                          20
                    : 20,
                20,
                20,
              ),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'What would you like to do?',
                        style: modeTheme.textTheme.headlineMedium,
                      ),
                    ),
                    Semantics(
                      label: cosmicMode
                          ? 'Friendly deep pink frog mascot with heart eyes'
                          : 'Friendly brown frog mascot',
                      image: true,
                      child: SizedBox(
                        width: 96,
                        height: 96,
                        child: ToolkitFrog(cosmicMode: cosmicMode),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Free. Simple. Respectful. No ads or accounts.'),
                const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 50),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            visualDensity: VisualDensity.compact,
                            foregroundColor: cosmicMode
                                ? Colors.white
                                : const Color(0xff4b3020),
                            backgroundColor: cosmicMode
                                ? const Color(0xff9d0c62)
                                : const Color(0xfff0e6dc),
                            side: BorderSide(
                              color: cosmicMode
                                  ? const Color(0xffff8fc8)
                                  : const Color(0xff4b3020),
                            ),
                          ),
                          onPressed: () =>
                              setState(() => cosmicMode = !cosmicMode),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                cosmicMode
                                    ? Icons.auto_awesome
                                    : Icons.auto_awesome_outlined,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              const Flexible(
                                child: Text(
                                  'Cosmic Mode',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 50),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            visualDensity: VisualDensity.compact,
                            foregroundColor: cosmicMode
                                ? Colors.white
                                : const Color(0xff4b3020),
                            side: BorderSide(
                              color: cosmicMode
                                  ? const Color(0xffff8fc8)
                                  : const Color(0xff4b3020),
                            ),
                          ),
                          onPressed: _openPrivacyPolicy,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.privacy_tip_outlined, size: 20),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Privacy Policy',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Cosmic Mode changes the colors and animation for fun. It does not change your phone settings.',
                  ),
                ),
                const SizedBox(height: 24),
                for (final group in tools.map((t) => t.group).toSet()) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      group,
                      style: modeTheme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.underline,
                        decorationThickness: 2,
                      ),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 14.0;
                      final tileWidth = (constraints.maxWidth - spacing) / 2;
                      final groupTools = toolsInGroup(group);
                      var tileHeight = tileWidth;
                      for (final tool in groupTools) {
                        final painter = TextPainter(
                          text: TextSpan(
                            text: tool.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.12,
                                ),
                          ),
                          textDirection: Directionality.of(context),
                          textScaler: MediaQuery.textScalerOf(context),
                        )..layout(maxWidth: tileWidth - 24);
                        final needed = painter.height + 144;
                        if (needed > tileHeight) tileHeight = needed;
                        painter.dispose();
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          mainAxisExtent: tileHeight,
                        ),
                        itemCount: groupTools.length,
                        itemBuilder: (context, index) {
                          final tool = groupTools[index];
                          return ToolTile(
                            tool: tool,
                            cosmicMode: cosmicMode,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ToolPage(tool: tool),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
                const Text(
                  'Made to be useful. Your phone stays in your control.',
                ),
                const SizedBox(height: 16),
                FrogHeartButton(
                  cosmicMode: cosmicMode,
                  onPressed: _openSupport,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Optional support only. Every feature stays free for everyone.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ToolTile extends StatelessWidget {
  const ToolTile({
    super.key,
    required this.tool,
    required this.cosmicMode,
    required this.onTap,
  });

  final Tool tool;
  final bool cosmicMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = cosmicMode
        ? const Color(0xffff8fc8)
        : const Color(0xff4b3020);
    final pictureBackground = cosmicMode
        ? const Color(0xff72094e)
        : const Color(0xffeee1d5);
    return Semantics(
      button: true,
      label: tool.title,
      hint: 'Open this tool',
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accent, width: 2.5),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: pictureBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accent, width: 2),
                      ),
                      child: Icon(tool.icon, size: 46, color: accent),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tool.title,
                  textAlign: TextAlign.center,

                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(Icons.touch_app_outlined, size: 22, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ToolPage extends StatefulWidget {
  final Tool tool;
  const ToolPage({super.key, required this.tool});
  @override
  State<ToolPage> createState() => _ToolPageState();
}

class PersistentStopwatch {
  PersistentStopwatch({Duration Function()? clock}) : _clock = clock ?? _uptime;

  static const _maximumMilliseconds = 3153600000000;
  static final Stopwatch _processUptime = Stopwatch()..start();
  static Duration _uptime() => _processUptime.elapsed;
  final Duration Function() _clock;
  Duration _accumulated = Duration.zero;
  Duration? _startedAt;

  bool get isRunning => _startedAt != null;

  Duration get elapsed {
    final startedAt = _startedAt;
    if (startedAt == null) return _accumulated;
    final added = _clock() - startedAt;
    if (added.isNegative) return _accumulated;
    final milliseconds = (_accumulated.inMilliseconds + added.inMilliseconds)
        .clamp(0, _maximumMilliseconds);
    return Duration(milliseconds: milliseconds);
  }

  void start() {
    _startedAt ??= _clock();
  }

  void stop() {
    if (_startedAt == null) return;
    _accumulated = elapsed;
    _startedAt = null;
  }

  void reset() {
    _accumulated = Duration.zero;
    if (isRunning) _startedAt = _clock();
  }

  Future<void> restore() async {
    try {
      final saved = await bridge.invokeMapMethod<String, Object?>(
        'loadStopwatch',
      );
      if (saved == null) return;
      final storedMilliseconds =
          ((saved['elapsedMillis'] as num?)?.toInt() ?? 0).clamp(
            0,
            _maximumMilliseconds,
          );
      final wasRunning = saved['running'] == true;
      // Android recovers paused-process time from its monotonic clock before
      // returning this value. Wall-clock changes must never alter a timer.
      _accumulated = Duration(milliseconds: storedMilliseconds);
      _startedAt = wasRunning ? _clock() : null;
    } on PlatformException {
      // Recovery is helpful, but the stopwatch remains usable without it.
    } on MissingPluginException {
      // Allows widget tests and non-Android previews to use the stopwatch.
    }
  }

  Future<void> persist() async {
    try {
      await bridge.invokeMethod<void>('saveStopwatch', {
        'elapsedMillis': elapsed.inMilliseconds,
        'running': isRunning,
      });
    } on PlatformException {
      // The current in-memory measurement remains available.
    } on MissingPluginException {
      // Allows widget tests and non-Android previews to use the stopwatch.
    }
  }
}

// Shared across routes and persisted so Android process interruption does not
// discard an active or stopped measurement.
final toolkitStopwatch = PersistentStopwatch();

class _ToolPageState extends State<ToolPage> with WidgetsBindingObserver {
  final watch = toolkitStopwatch;
  Timer? ticker;
  bool busy = false;
  String? message;
  bool fallback = false;
  TimeOfDay alarm = const TimeOfDay(hour: 7, minute: 0);
  int minutes = 5;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.tool.id == 'stopwatch') {
      ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted && watch.isRunning) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(watch.persist());
    }
  }

  Future<void> act(String id, [Map<String, Object> args = const {}]) async {
    setState(() {
      busy = true;
      message = null;
      fallback = false;
    });
    try {
      final result = await bridge.invokeMethod<String>('perform', {
        'id': id,
        ...args,
      });
      if (mounted) {
        setState(() {
          message = result;
        });
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          message = id == 'messages'
              ? 'Your phone could not open a messaging app. Please open Messages from your phone’s home screen.'
              : switch (error.code) {
                  'denied' =>
                    'Your phone didn’t allow that action. You can try opening Settings instead.',
                  'unavailable' =>
                    'We couldn’t open that tool on your phone. You can try the main Settings screen instead.',
                  'unsupported' =>
                    'This phone doesn’t have an available flashlight.',
                  'camera_busy' =>
                    'The flashlight is busy. Close the Camera app and try again.',
                  'busy' =>
                    'That tool is already open. Finish or close it, then try again.',
                  'ringtone_unavailable' =>
                    'Your phone could not open its ringtone picker or Sound settings. No ringtone was changed.',
                  'ringtone_failed' =>
                    'Your phone could not apply that ringtone. No ringtone was changed. Try choosing it from Sound settings.',
                  'cancelled' => 'No ringtone was changed.',
                  _ =>
                    'That didn’t work this time. You can try again or open Settings.',
                };
          fallback =
              id != 'settings' && id != 'messages' && error.code != 'cancelled';
        });
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          message =
              'These phone controls work on Android. You can still explore the tools here.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          message =
              'That didn’t finish this time. Check the phone setting before trying again.';
          fallback = id != 'settings' && id != 'messages';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    final elapsed = watch.elapsed;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: titleHeight(
          context,
          tool.title,
          MediaQuery.sizeOf(context).width - 90,
        ),
        title: Text(tool.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Icon(tool.icon, size: 48),
          ),
          const SizedBox(height: 24),
          Text(tool.help, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 28),
          if (tool.id == 'power') ...[
            const Icon(Icons.swipe_down, size: 64),
            const Text('1. Swipe down from the very top of the screen twice.'),
            const SizedBox(height: 20),
            const Icon(Icons.power_settings_new, size: 64),
            const Text('2. If you see the power symbol, tap it.'),
            const SizedBox(height: 20),
            const Text('3. Tap Power off. Confirm if your phone asks.'),
            const SizedBox(height: 24),
            const Text(
              'No power symbol? On many phones, briefly hold the side Power button until the menu appears, then release it. Some newer phones use Power and Volume up together instead.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Button shortcuts vary by phone. Release the buttons once the menu appears.',
            ),
          ] else if (tool.id == 'stopwatch') ...[
            Semantics(
              liveRegion: false,
              child: Text(
                '${elapsed.inHours.toString().padLeft(2, '0')}:${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => setState(() {
                if (watch.isRunning) {
                  watch.stop();
                } else {
                  watch.start();
                }
                unawaited(watch.persist());
              }),
              child: Text(watch.isRunning ? 'Stop' : 'Start'),
            ),
            TextButton(
              onPressed: watch.isRunning
                  ? null
                  : () => setState(() {
                      watch.reset();
                      unawaited(watch.persist());
                    }),
              child: const Text('Reset'),
            ),
            const Text(
              'You can use other tools while this runs. Stop before resetting. If Android closes the app, your measurement will be restored when you return.',
            ),
          ] else if (tool.id == 'flashlight') ...[
            FilledButton(
              onPressed: busy ? null : () => act('torchOn'),
              child: const Text('Turn light on'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: busy ? null : () => act('torchOff'),
              child: const Text('Turn light off'),
            ),
          ] else if (tool.id == 'icons') ...[
            FilledButton(
              onPressed: busy ? null : () => act('home'),
              child: const Text('Open icon settings'),
            ),
          ] else ...[
            if (tool.id == 'timer') ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in [1, 5, 10, 15, 30, 60])
                    ChoiceChip(
                      label: Text('$n min'),
                      selected: minutes == n,
                      onSelected: (_) => setState(() {
                        minutes = n;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        final value = await showDialog<int>(
                          context: context,
                          builder: (_) =>
                              TimerDurationDialog(initialMinutes: minutes),
                        );
                        if (value != null && mounted) {
                          setState(() {
                            minutes = value;
                          });
                        }
                      },
                child: const Text('Custom duration'),
              ),
              Text('Selected: $minutes ${minutes == 1 ? 'minute' : 'minutes'}'),
              const SizedBox(height: 16),
            ],
            if (tool.id == 'alarm') ...[
              OutlinedButton(
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: alarm,
                  );
                  if (time != null && mounted) {
                    setState(() {
                      alarm = time;
                    });
                  }
                },
                child: Text('Choose time: ${alarm.format(context)}'),
              ),
              const SizedBox(height: 16),
            ],
            FilledButton(
              onPressed: busy
                  ? null
                  : tool.id == 'camera'
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const EasyCameraPage(),
                      ),
                    )
                  : () => act(tool.id, {
                      'minutes': minutes,
                      'hour': alarm.hour,
                      'minute': alarm.minute,
                    }),
              child: Text(switch (tool.id) {
                'camera' => 'Open easy camera',
                'contacts' => 'Open my contacts',
                'messages' => 'Open Messages',
                'volume' => 'Open volume controls',
                'wallpaper' => 'Choose wallpaper',
                'timer' || 'alarm' => 'Continue in Clock',
                'sound' => 'Open sound controls',
                'dnd' => 'Open Do Not Disturb',
                'ringtone' => 'Choose a ringtone',
                'text' => 'Open text size',
                'display' => 'Open screen size',
                'brightness' => 'Open brightness',
                'timeout' => 'Open screen timeout',
                'rotate' => 'Open auto-rotate',
                'keyboard' => 'Open keyboard settings',
                'apps' => 'Choose an app',
                'storage' => 'Open storage',
                'battery' => 'Open Battery Saver',
                _ => 'Open',
              }),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your phone will open the requested control directly when it allows apps to do so. Use Back or recent apps to return.',
            ),
          ],
          if (busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  message!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          if (fallback)
            OutlinedButton(
              onPressed: busy ? null : () => act('settings'),
              child: const Text('Open main settings'),
            ),
        ],
      ),
    );
  }
}
