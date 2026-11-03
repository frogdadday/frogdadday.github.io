// /////Block One/////////////////////////////////////////////////////////////
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/chore_list.dart';
import '../models/daily_plan.dart';
import '../services/chore_store.dart';
import '../services/cosmic_copy.dart';
import '../services/local_calendar.dart';
import '../services/native_bridge.dart';
import '../widgets/responsive_list_view.dart';

class CosmicMissionControlPage extends StatefulWidget {
  const CosmicMissionControlPage({super.key, required this.store});

  final ChoreStore store;

  @override
  State<CosmicMissionControlPage> createState() =>
      _CosmicMissionControlPageState();
}

class _CosmicMissionControlPageState extends State<CosmicMissionControlPage>
    with LocalDateObserver {
  final Set<String> _completed = <String>{};
  bool _progressReady = false;
  Future<void> _progressWrites = Future<void>.value();

  @override
  void onLocalDateChanged(DateTime previous, DateTime current) {
    _completed.clear();
    _progressReady = false;
    _loadProgress();
  }

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  String get _todayKey {
    final now = localNow;
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadProgress() async {
    final requestedDate = _todayKey;
    try {
      final raw = await NativeBridge.readMissionProgress();
      if (raw == null || raw.isEmpty) return;
      final decoded = Map<String, Object?>.from(jsonDecode(raw) as Map);
      if (decoded['date'] != _todayKey ||
          requestedDate != _todayKey ||
          !mounted) {
        return;
      }
      setState(() {
        _completed.addAll(
          (decoded['completed'] as List<Object?>).cast<String>(),
        );
      });
    } catch (_) {
      // Checkboxes remain usable for the session if local storage is unavailable.
    } finally {
      if (mounted && requestedDate == _todayKey) {
        setState(() => _progressReady = true);
      }
    }
  }

  Future<void> _saveProgress() async {
    final snapshot = jsonEncode(<String, Object?>{
      'date': _todayKey,
      'completed': _completed.toList(),
    });
    try {
      final write = _progressWrites.then(
        (_) => NativeBridge.writeMissionProgress(snapshot),
      );
      _progressWrites = write.catchError((Object _) {});
      await write;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Checkmarks could not be saved. They remain visible for this session.',
            ),
          ),
        );
      }
    }
  }

  // /////Block Two///////////////////////////////////////////////////////////
  Future<void> _setCompleted(String key, bool value) async {
    final date = _todayKey;
    refreshLocalDate();
    if (date != _todayKey || !_progressReady) return;
    setState(() {
      if (value) {
        _completed.add(key);
      } else {
        _completed.remove(key);
      }
    });
    await _saveProgress();
  }

  Future<void> _launchMessage(ChoreList list) async {
    refreshLocalDate();
    final plan = DailyPlan.forList(
      mainList: list,
      allLists: widget.store.lists,
      date: localNow,
    );
    if (list.dayIndexForDate(localNow) == null) return;
    try {
      final opened = await NativeBridge.shareMessage(
        body: plan.messageForMode(cosmicMode: context.isCosmicMode),
        recipients: plan.mainList.messageRecipients,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No messaging app was available.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The message could not be opened. Please try again.'),
          ),
        );
      }
    }
  }

  // /////Block Three/////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        if (!widget.store.loaded) {
          return const Center(child: CircularProgressIndicator());
        }
        final mainLists = widget.store.lists
            .where((list) => list.isMainPlan)
            .toList();
        if (mainLists.isEmpty) {
          return const _EmptyMissionControl();
        }
        final now = localNow;
        return ResponsiveListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: <Widget>[
            Text(
              'Today’s checklist',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.cosmicCopy(
                'Check off today’s chores as they are finished.',
              ),
            ),
            const SizedBox(height: 14),
            for (final list in mainLists) _missionCard(list, now),
          ],
        );
      },
    );
  }

  Widget _missionCard(ChoreList list, DateTime now) {
    final plan = DailyPlan.forList(
      mainList: list,
      allLists: widget.store.lists,
      date: now,
    );
    final day = list.dayIndexForDate(now);
    if (day == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.nights_stay_rounded),
          title: Text(list.title),
          subtitle: const Text('The work-week crew is off duty today.'),
        ),
      );
    }
    final assignments = plan.assignments;
    final keys = <String>[];
    for (final assignment in assignments) {
      for (final chore in assignment.chores) {
        keys.add(plan.completionKey(assignment, chore));
      }
    }
    final completeCount = keys.where(_completed.contains).length;
    final allComplete = keys.isNotEmpty && completeCount == keys.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.rocket_launch_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        list.title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text('${list.labelForDay(day)} • ${list.formattedTime}'),
                    ],
                  ),
                ),
                Text('$completeCount/${keys.length}'),
              ],
            ),
            if (keys.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: completeCount / keys.length),
            ],
            if (plan.extraListTitles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Includes project: ${plan.extraListTitles.join(', ')}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            for (final assignment in assignments) ...<Widget>[
              Text(
                assignment.person.name,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              if (assignment.chores.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 4, 0, 10),
                  child: Text('No missions today'),
                )
              else
                for (final chore in assignment.chores)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(chore.title),
                    subtitle: chore.isExtraProject
                        ? const Text('Extra project')
                        : null,
                    value: _completed.contains(
                      plan.completionKey(assignment, chore),
                    ),
                    onChanged: !_progressReady
                        ? null
                        : (value) => _setCompleted(
                            plan.completionKey(assignment, chore),
                            value ?? false,
                          ),
                  ),
            ],
            if (allComplete)
              Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  '★ Mission accomplished! ★',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            FilledButton.icon(
              onPressed: () => _launchMessage(list),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Prepare today’s message'),
            ),
          ],
        ),
      ),
    );
  }
}

// /////Block Four////////////////////////////////////////////////////////////
class _EmptyMissionControl extends StatelessWidget {
  const _EmptyMissionControl();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.rocket_launch_rounded, size: 68),
            const SizedBox(height: 16),
            const Text(
              'Today’s checklist is ready',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              context.cosmicCopy(
                'Create a chore list and today’s chores will appear here for easy check-offs.',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
