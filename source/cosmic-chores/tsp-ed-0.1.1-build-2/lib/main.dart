// /////Block One/////////////////////////////////////////////////////////////
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_shell.dart';
import 'screens/saved_lists_page.dart';
import 'services/chore_store.dart';
import 'services/native_bridge.dart';
import 'theme/app_theme.dart';
import 'widgets/cosmic_star_field.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const CosmicChoresApp());
}

// /////Block Two/////////////////////////////////////////////////////////////
class CosmicChoresApp extends StatefulWidget {
  const CosmicChoresApp({super.key});

  @override
  State<CosmicChoresApp> createState() => _CosmicChoresAppState();
}

class _CosmicChoresAppState extends State<CosmicChoresApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<void> _reminderSubscription;
  bool _openingReminder = false;
  final ChoreStore store = ChoreStore();
  bool cosmicMode = false;
  bool _cosmicModeChangedByUser = false;

  @override
  void initState() {
    super.initState();
    NativeBridge.listenForReminderEvents();
    _reminderSubscription = NativeBridge.reminderOpened.listen(
      (_) => _openReminder(),
    );
    store.load().then((_) => _openReminder());
    _lifecycle = AppLifecycleListener(onResume: _openReminder);
    _loadCosmicMode();
  }

  Future<void> _openReminder() async {
    if (!store.loaded || _openingReminder || !mounted) return;
    _openingReminder = true;
    try {
      final reminder = await NativeBridge.takeReminder();
      if (!mounted || reminder == null) return;
      final matches = store.lists.where((list) => list.id == reminder.id);
      if (matches.isNotEmpty) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => SavedListDetailPage(
              list: matches.first,
              store: store,
              initialDate: reminder.date,
            ),
          ),
        );
      }
    } catch (_) {
      /* No pending reminder on unsupported platforms. */
    } finally {
      _openingReminder = false;
    }
  }

  Future<void> _loadCosmicMode() async {
    try {
      final savedMode = await NativeBridge.readCosmicMode();
      if (mounted && !_cosmicModeChangedByUser) {
        setState(() => cosmicMode = savedMode);
      }
    } catch (_) {
      // Cosmic Mode remains available even when native settings are unavailable.
    }
  }

  Future<void> _setCosmicMode(bool enabled) async {
    setState(() {
      _cosmicModeChangedByUser = true;
      cosmicMode = enabled;
    });
    try {
      await NativeBridge.writeCosmicMode(enabled);
    } catch (_) {
      // The visual mode still changes for this session if saving fails.
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _reminderSubscription.cancel();
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Cosmic Chores',
      debugShowCheckedModeBanner: false,
      theme: cosmicMode ? buildCosmicTheme() : buildAppTheme(),
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: cosmicMode
                    ? const CosmicStarField()
                    : ColoredBox(
                        color: buildAppTheme().scaffoldBackgroundColor,
                      ),
              ),
            ),
            child ?? const SizedBox.shrink(),
          ],
        );
      },
      home: HomeShell(
        store: store,
        cosmicMode: cosmicMode,
        onCosmicModeChanged: _setCosmicMode,
      ),
    );
  }
}
