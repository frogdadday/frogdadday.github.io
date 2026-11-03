// /////Block One/////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import '../models/chore_list.dart';
import '../services/cosmic_copy.dart';
import 'base_schedule_day_card.dart';

typedef ChoreEditCallback = void Function(int day, int lane, int chore);
typedef ChoreAddCallback = void Function(int day, int lane);

class ChoreScheduleBoard extends StatelessWidget {
  const ChoreScheduleBoard({
    super.key,
    required this.template,
    required this.dayLabels,
    required this.dates,
    required this.cycleStart,
    required this.peopleByDay,
    required this.assignments,
    required this.choreIds,
    required this.selectedDay,
    required this.onSelectDay,
    required this.onEditChore,
    required this.onAddChore,
    required this.onClearDay,
    required this.onClearSchedule,
    required this.rotationPreview,
  });

  final ChoreTemplate template;
  final List<String> dayLabels;
  final List<DateTime> dates;
  final DateTime cycleStart;
  final List<List<ChorePerson>> peopleByDay;
  final Map<int, List<List<String>>> assignments;
  final Map<int, List<List<String>>> choreIds;
  final int selectedDay;
  final ValueChanged<int> onSelectDay;
  final ChoreEditCallback onEditChore;
  final ChoreAddCallback onAddChore;
  final ValueChanged<int> onClearDay;
  final VoidCallback onClearSchedule;
  final Widget? rotationPreview;

  // /////Block Two///////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    final cycleText = template == ChoreTemplate.month
        ? null
        : MaterialLocalizations.of(context).formatMediumDate(cycleStart);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                template == ChoreTemplate.month
                    ? 'Your dated project queue'
                    : 'Your visual schedule grid',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                context.cosmicCopy(
                  template == ChoreTemplate.month
                      ? 'Each date is an extra project. On that date, it joins the main plan and goes to the person first in that plan’s real rotation.'
                      : 'Showing the upcoming full schedule week, starting $cycleText. Each day already shows the people in their real rotation. Add chores directly under the person who will do them that day.',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onClearSchedule,
                  icon: const Icon(Icons.clear_all_rounded),
                  label: Text(context.cosmicCopy('Clear all chores')),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (var day = 0; day < dates.length; day++) ...<Widget>[
                    SizedBox(
                      width: 248,
                      child: BaseScheduleDayCard(
                        label:
                            '${dayLabels[day]}\n${MaterialLocalizations.of(context).formatMediumDate(dates[day])}',
                        people: peopleByDay[day],
                        choresByLane: assignments[day]!,
                        choreIdsByLane: choreIds[day]!,
                        isSelected: day == selectedDay,
                        isProjectQueue: template == ChoreTemplate.month,
                        onSelect: () => onSelectDay(day),
                        onEditChore: (lane, chore) =>
                            onEditChore(day, lane, chore),
                        onAddChore: (lane) => onAddChore(day, lane),
                        onClearDay: () => onClearDay(day),
                      ),
                    ),
                    if (day < dates.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 58),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (rotationPreview != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: rotationPreview!,
              ),
          ],
        ),
      ),
    );
  }
}
