// /////Block One/////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import '../models/chore_list.dart';
import '../services/cosmic_copy.dart';

/// One editable date card. Its supplied people already reflect rotation.
class BaseScheduleDayCard extends StatelessWidget {
  const BaseScheduleDayCard({
    super.key,
    required this.label,
    required this.people,
    required this.choresByLane,
    required this.choreIdsByLane,
    required this.isSelected,
    required this.isProjectQueue,
    required this.onSelect,
    required this.onEditChore,
    required this.onAddChore,
    required this.onClearDay,
  });

  final String label;
  final List<ChorePerson> people;
  final List<List<String>> choresByLane;
  final List<List<String>> choreIdsByLane;
  final bool isSelected;
  final bool isProjectQueue;
  final VoidCallback onSelect;
  final void Function(int lane, int chore) onEditChore;
  final ValueChanged<int> onAddChore;
  final VoidCallback onClearDay;

  // /////Block Two///////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: isSelected ? colors.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onSelect,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: <Widget>[
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      context.cosmicCopy(
                        isProjectQueue
                            ? 'Calendar date'
                            : 'People rotate by date',
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (var lane = 0; lane < people.length; lane++) ...<Widget>[
              _LaneEditor(
                key: ValueKey<String>('lane-$lane'),
                person: people[lane],
                chores: choresByLane[lane],
                choreIds: choreIdsByLane[lane],
                isProjectQueue: isProjectQueue,
                onSelect: onSelect,
                onEdit: (chore) => onEditChore(lane, chore),
                onAdd: () => onAddChore(lane),
              ),
              const SizedBox(height: 8),
            ],
            TextButton.icon(
              onPressed: onClearDay,
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text('Clear day'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaneEditor extends StatelessWidget {
  const _LaneEditor({
    super.key,
    required this.person,
    required this.chores,
    required this.choreIds,
    required this.isProjectQueue,
    required this.onSelect,
    required this.onEdit,
    required this.onAdd,
  });

  final ChorePerson person;
  final List<String> chores;
  final List<String> choreIds;
  final bool isProjectQueue;
  final VoidCallback onSelect;
  final ValueChanged<int> onEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 12,
                child: Text(person.name.characters.first.toUpperCase()),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isProjectQueue
                      ? context.cosmicCopy('Project chores')
                      : person.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (chores.isEmpty)
            Text(
              context.cosmicCopy('No chores yet'),
              style: const TextStyle(fontSize: 12),
            ),
          for (var chore = 0; chore < chores.length; chore++)
            Semantics(
              key: ValueKey<String>(
                chore < choreIds.length
                    ? 'chore-${choreIds[chore]}'
                    : 'chore-$chore-${chores[chore]}',
              ),
              button: true,
              label: context.cosmicCopy('Edit chore ${chores[chore]}'),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  onEdit(chore);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.check_box_outline_blank_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Expanded(child: Text(chores[chore])),
                    ],
                  ),
                ),
              ),
            ),
          TextButton.icon(
            onPressed: () {
              onAdd();
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(context.cosmicCopy('Add chore')),
          ),
        ],
      ),
    );
  }
}
