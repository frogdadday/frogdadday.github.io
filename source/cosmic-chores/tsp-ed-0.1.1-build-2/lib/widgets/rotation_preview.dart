// /////Block One/////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import '../models/chore_list.dart';
import '../services/cosmic_copy.dart';

/// Read-only effective schedule preview, powered by the production list model.
class RotationPreview extends StatelessWidget {
  const RotationPreview({
    super.key,
    required this.draft,
    required this.startDate,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final ChoreList draft;
  final DateTime startDate;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final previewDays = switch (draft.rotationMode) {
      RotationMode.none || RotationMode.daily => 3,
      RotationMode.everyOtherDay => 4,
      RotationMode.weekly => 8,
    };
    return ExpansionTile(
      key: const PageStorageKey<String>('rotation-preview'),
      initiallyExpanded: expanded,
      onExpansionChanged: onExpandedChanged,
      tilePadding: EdgeInsets.zero,
      title: const Text(
        'See the rotation preview',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        'Shows who will actually do each fixed lane on real calendar dates.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var offset = 0; offset < previewDays; offset++)
                _RotationPreviewDay(
                  draft: draft,
                  date: DateTime(
                    startDate.year,
                    startDate.month,
                    startDate.day + offset,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// /////Block Two/////////////////////////////////////////////////////////////
class _RotationPreviewDay extends StatelessWidget {
  const _RotationPreviewDay({required this.draft, required this.date});

  final ChoreList draft;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final day = draft.dayIndexForDate(date);
    final colors = Theme.of(context).colorScheme;
    final dateLabel = MaterialLocalizations.of(context).formatMediumDate(date);
    final effective = day == null
        ? const <({ChorePerson person, List<String> chores})>[]
        : draft.assignmentsForDay(
            day,
            rotationStep: draft.rotationForDate(date),
          );
    return SizedBox(
      width: 184,
      child: Card(
        color: colors.surfaceContainerHighest,
        margin: const EdgeInsets.only(right: 8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                dateLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              if (effective.isEmpty)
                Text(
                  context.cosmicCopy('No chores in this plan'),
                  style: const TextStyle(fontSize: 12),
                ),
              for (final lane in effective) ...<Widget>[
                Text(
                  lane.person.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  lane.chores.isEmpty
                      ? context.cosmicCopy('No chores')
                      : lane.chores.join(', '),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 5),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
