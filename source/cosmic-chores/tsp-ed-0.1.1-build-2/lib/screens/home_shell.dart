// /////Block One/////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import '../services/chore_store.dart';
import '../services/native_bridge.dart';
import '../widgets/frog_heart_button.dart';
import '../widgets/frog_spaceship.dart';
import '../widgets/constellation_title.dart';
import '../widgets/orange_frog.dart';
import 'cosmic_mission_control_page.dart';
import 'create_chore_list_page.dart';
import 'saved_lists_page.dart';
import 'weekly_review_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.store,
    required this.cosmicMode,
    required this.onCosmicModeChanged,
  });

  final ChoreStore store;
  final bool cosmicMode;
  final ValueChanged<bool> onCosmicModeChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final GlobalKey _contentKey = GlobalKey();

  Future<void> _openPrivacyPolicy() async {
    final opened = await NativeBridge.openPrivacyPolicy();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No browser was available to open the privacy policy.'),
        ),
      );
    }
  }

  // /////Block Two///////////////////////////////////////////////////////////
  Widget _mainContent() {
    final pages = <Widget>[
      CosmicMissionControlPage(store: widget.store),
      WeeklyReviewPage(store: widget.store),
      CreateChoreListPage(
        store: widget.store,
        onSaved: () => setState(() => _index = 3),
      ),
      SavedListsPage(store: widget.store),
    ];
    return Column(
      key: _contentKey,
      children: <Widget>[
        Expanded(
          child: ListenableBuilder(
            listenable: widget.store,
            builder: (context, _) {
              // A damaged local file must always lead to the recovery screen,
              // rather than looking like an empty brand-new app on Home.
              if (widget.store.loaded && widget.store.loadError != null) {
                return SavedListsPage(store: widget.store);
              }
              return IndexedStack(index: _index, children: pages);
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 2,
              children: <Widget>[
                const FrogHeartButton(),
                TextButton.icon(
                  onPressed: () {
                    widget.onCosmicModeChanged(!widget.cosmicMode);
                  },
                  icon: Icon(
                    widget.cosmicMode
                        ? Icons.light_mode_outlined
                        : Icons.auto_awesome_rounded,
                  ),
                  label: Text(
                    widget.cosmicMode ? 'Normal Mode' : 'Cosmic Mode',
                  ),
                ),
                TextButton.icon(
                  onPressed: _openPrivacyPolicy,
                  icon: const Icon(Icons.privacy_tip_outlined),
                  label: const Text('Privacy'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // /////Block Three/////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    final expanded = MediaQuery.sizeOf(context).width >= 840;
    final railDestinations = widget.cosmicMode
        ? const <NavigationRailDestination>[
            NavigationRailDestination(
              icon: Icon(Icons.rocket_launch_outlined),
              selectedIcon: Icon(Icons.rocket_launch_rounded),
              label: Text('Missions'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.calendar_view_week_outlined),
              selectedIcon: Icon(Icons.calendar_view_week_rounded),
              label: Text('Orbit week'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.playlist_add_rounded),
              label: Text('Create new'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.folder_copy_outlined),
              selectedIcon: Icon(Icons.folder_copy_rounded),
              label: Text('Saved lists'),
            ),
          ]
        : const <NavigationRailDestination>[
            NavigationRailDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today_rounded),
              label: Text('Today'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.calendar_view_week_outlined),
              selectedIcon: Icon(Icons.calendar_view_week_rounded),
              label: Text('This week'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.playlist_add_rounded),
              label: Text('Make list'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.folder_copy_outlined),
              selectedIcon: Icon(Icons.folder_copy_rounded),
              label: Text('My lists'),
            ),
          ];
    final barDestinations = widget.cosmicMode
        ? const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.rocket_launch_outlined),
              selectedIcon: Icon(Icons.rocket_launch_rounded),
              label: 'Missions',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_view_week_outlined),
              selectedIcon: Icon(Icons.calendar_view_week_rounded),
              label: 'Orbit week',
            ),
            NavigationDestination(
              icon: Icon(Icons.playlist_add_rounded),
              label: 'Create new',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_copy_outlined),
              selectedIcon: Icon(Icons.folder_copy_rounded),
              label: 'Saved lists',
            ),
          ]
        : const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today_rounded),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_view_week_outlined),
              selectedIcon: Icon(Icons.calendar_view_week_rounded),
              label: 'This week',
            ),
            NavigationDestination(
              icon: Icon(Icons.playlist_add_rounded),
              label: 'Make list',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_copy_outlined),
              selectedIcon: Icon(Icons.folder_copy_rounded),
              label: 'My lists',
            ),
          ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        toolbarHeight: widget.cosmicMode ? 72 : kToolbarHeight,
        titleSpacing: widget.cosmicMode ? 8 : 16,
        title: widget.cosmicMode
            ? const Row(
                children: <Widget>[
                  FrogSpaceship(width: 70),
                  SizedBox(width: 4),
                  Expanded(child: ConstellationTitle(height: 38)),
                ],
              )
            : const Row(
                children: <Widget>[
                  OrangeFrog(size: 48),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cosmic Chores',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
      ),
      body: expanded
          ? Row(
              children: <Widget>[
                NavigationRail(
                  selectedIndex: _index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (value) =>
                      setState(() => _index = value),
                  destinations: railDestinations,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _mainContent()),
              ],
            )
          : _mainContent(),
      bottomNavigationBar: expanded
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: barDestinations,
            ),
    );
  }
}
