// /////Block One/////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import '../models/chore_list.dart';
import '../services/cosmic_copy.dart';

class ChorePeopleEditorCard extends StatelessWidget {
  const ChorePeopleEditorCard({
    super.key,
    required this.people,
    required this.onMoveEarlier,
    required this.onMoveLater,
    required this.onEdit,
    required this.onRemove,
    required this.onAdd,
    required this.onDeviceOwnerChanged,
  });

  final List<ChorePerson> people;
  final ValueChanged<int> onMoveEarlier;
  final ValueChanged<int> onMoveLater;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onRemove;
  final VoidCallback onAdd;
  final ValueChanged<int> onDeviceOwnerChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.cosmicCopy('People'),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (
              var personIndex = 0;
              personIndex < people.length;
              personIndex++
            )
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(
                    people[personIndex].name.characters.first.toUpperCase(),
                  ),
                ),
                title: Text(people[personIndex].name),
                subtitle: people[personIndex].phone == null
                    ? null
                    : Text(people[personIndex].phone!),
                trailing: Wrap(
                  spacing: 0,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Move ${people[personIndex].name} earlier',
                      onPressed: personIndex == 0
                          ? null
                          : () => onMoveEarlier(personIndex),
                      icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    ),
                    IconButton(
                      tooltip: 'Move ${people[personIndex].name} later',
                      onPressed: personIndex == people.length - 1
                          ? null
                          : () => onMoveLater(personIndex),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                    IconButton(
                      tooltip: context.cosmicCopy('Edit person'),
                      onPressed: () => onEdit(personIndex),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: context.cosmicCopy('Remove person'),
                      onPressed: () => onRemove(personIndex),
                      icon: const Icon(Icons.person_remove_outlined),
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt_rounded),
              label: Text(context.cosmicCopy('Add or search for a person')),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                context.cosmicCopy(
                  'Use the arrows to change the starting order. The chore lanes stay put, so this changes future rotation without moving chores.',
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            DeviceOwnerPicker(people: people, onChanged: onDeviceOwnerChanged),
          ],
        ),
      ),
    );
  }
}

// /////Block Two/////////////////////////////////////////////////////////////
class DeviceOwnerPicker extends StatelessWidget {
  const DeviceOwnerPicker({
    super.key,
    required this.people,
    required this.onChanged,
  });

  final List<ChorePerson> people;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    if (people.length < 2) return const SizedBox.shrink();
    final ownerIndex = people.indexWhere((person) => person.isDeviceOwner);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: DropdownButtonFormField<int>(
        key: ValueKey<String>('device-owner-$ownerIndex-${people.length}'),
        initialValue: ownerIndex < 0 ? null : ownerIndex,
        decoration: InputDecoration(
          labelText: 'Who uses this phone?',
          helperText: context.cosmicCopy(
            'They are not included as a recipient. Their chores still appear in the message, and this keeps a two-person list as a normal text.',
          ),
          prefixIcon: const Icon(Icons.phone_android_rounded),
        ),
        hint: Text(context.cosmicCopy('Choose a person')),
        items: List<DropdownMenuItem<int>>.generate(
          people.length,
          (index) => DropdownMenuItem<int>(
            value: index,
            child: Text(people[index].name),
          ),
        ),
        onChanged: (owner) {
          if (owner != null) onChanged(owner);
        },
      ),
    );
  }
}
