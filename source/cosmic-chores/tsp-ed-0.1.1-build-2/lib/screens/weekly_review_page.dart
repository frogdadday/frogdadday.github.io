// /////Block One/////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import '../models/chore_list.dart';
import '../models/daily_plan.dart';
import '../services/chore_store.dart';
import '../services/cosmic_copy.dart';
import '../services/local_calendar.dart';
import '../widgets/responsive_list_view.dart';

/// A read-only, date-accurate view of what each person will actually do.
class WeeklyReviewPage extends StatefulWidget {
  const WeeklyReviewPage({super.key, required this.store});

  final ChoreStore store;

  @override
  State<WeeklyReviewPage> createState() => _WeeklyReviewPageState();
}

class _WeeklyReviewPageState extends State<WeeklyReviewPage>
    with LocalDateObserver {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfWeek(localNow);
  }

  DateTime _startOfWeek(DateTime date) =>
      DateTime(date.year, date.month, date.day - date.weekday % 7);

  void _moveWeek(int days) => setState(() {
    _weekStart = DateTime(
      _weekStart.year,
      _weekStart.month,
      _weekStart.day + days,
    );
  });

  @override
  void onLocalDateChanged(DateTime previous, DateTime current) {
    if (LocalCalendar.key(_weekStart) ==
        LocalCalendar.key(_startOfWeek(previous))) {
      _weekStart = _startOfWeek(current);
    }
  }

  // /////Block Two///////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    final mainPlans = widget.store.lists
        .where((list) => list.isMainPlan)
        .toList();
    final dateText = MaterialLocalizations.of(context)
        .formatMediumDate(_weekStart);
    return ResponsiveListView(
      children: <Widget>[
        Text(
          'This week',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          context.cosmicCopy(
            'This is the real schedule: fixed chore lanes, with people shown in the position they actually hold on each date.',
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Previous week',
                  onPressed: () => _moveWeek(-7),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    'Week of $dateText',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Next week',
                  onPressed: () => _moveWeek(7),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        ),
        if (mainPlans.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: _EmptyWeeklyReview(),
          ),
        for (final list in mainPlans) ...<Widget>[
          const SizedBox(height: 16),
          _PlanWeek(
            list: list,
            allLists: widget.store.lists,
            weekStart: _weekStart,
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

// /////Block Three///////////////////////////////////////////////////////////
class _PlanWeek extends StatelessWidget {
  const _PlanWeek({
    required this.list,
    required this.allLists,
    required this.weekStart,
  });

  final ChoreList list;
  final Iterable<ChoreList> allLists;
  final DateTime weekStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.cosmicCopy(list.title),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text('Rotation: ${list.rotationMode.label}'),
            const SizedBox(height: 12),
            for (var offset = 0; offset < 7; offset++) ...<Widget>[
              _DayReview(
                list: list,
                allLists: allLists,
                date: DateTime(
                  weekStart.year,
                  weekStart.month,
                  weekStart.day + offset,
                ),
              ),
              if (offset < 6) const Divider(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayReview extends StatelessWidget {
  const _DayReview({
    required this.list,
    required this.allLists,
    required this.date,
  });

  final ChoreList list;
  final Iterable<ChoreList> allLists;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final plan = DailyPlan.forList(
      mainList: list,
      allLists: allLists,
      date: date,
    );
    final localizations = MaterialLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final heading = localizations.formatFullDate(date);
    if (plan.assignments.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(heading, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            context.cosmicCopy('No chores in this plan today.'),
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(heading, style: const TextStyle(fontWeight: FontWeight.w800)),
        if (plan.extraListTitles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Includes: ${plan.extraListTitles.join(', ')}',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final assignment in plan.assignments)
                SizedBox(
                  width: 170,
                  child: Card(
                    margin: const EdgeInsets.only(right: 8),
                    color: colors.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            assignment.person.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          if (assignment.chores.isEmpty)
                            Text(
                              context.cosmicCopy('No chores'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          for (final chore in assignment.chores)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${chore.isExtraProject ? '✦ ' : '• '}${chore.title}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: chore.isExtraProject
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyWeeklyReview extends StatelessWidget {
  const _EmptyWeeklyReview();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: <Widget>[
          const Icon(Icons.calendar_month_outlined, size: 42),
          const SizedBox(height: 8),
          Text(
            'Make a weekly or work-week plan to see it here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    ),
  );
}
