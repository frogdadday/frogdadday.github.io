// /////Block One/////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import '../models/chore_list.dart';
import '../services/cosmic_copy.dart';

class ChoreScheduleSelection {
  const ChoreScheduleSelection({required this.days, required this.starter});

  final List<int> days;
  final int starter;
}

class ChoreEditResult {
  const ChoreEditResult.save(this.text) : remove = false;
  const ChoreEditResult.remove() : text = null, remove = true;

  final String? text;
  final bool remove;
}

// /////Block Two/////////////////////////////////////////////////////////////
Future<ChoreScheduleSelection?> showChoreScheduleDialog({
  required BuildContext context,
  required String chore,
  required ChoreTemplate template,
  required int dayCount,
  required List<String> dayLabels,
  required List<ChorePerson> people,
}) {
  return showDialog<ChoreScheduleSelection>(
    context: context,
    builder: (dialogContext) {
      final chosenDays = <int>{};
      var starter = 0;
      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.cosmicCopy('Schedule $chore')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.cosmicCopy(
                    template == ChoreTemplate.month
                        ? 'Choose the calendar dates for this project. On each date, it goes to whoever is first in the main plan’s rotation.'
                        : 'Choose when it happens. The starter gets this chore on the first chosen day; rotation handles the days after that.',
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    ActionChip(
                      label: const Text('Every day'),
                      onPressed: () => setDialogState(() {
                        chosenDays
                          ..clear()
                          ..addAll(List<int>.generate(dayCount, (i) => i));
                      }),
                    ),
                    ActionChip(
                      label: const Text('Clear days'),
                      onPressed: () => setDialogState(chosenDays.clear),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List<Widget>.generate(
                    dayCount,
                    (day) => FilterChip(
                      label: Text(dayLabels[day]),
                      selected: chosenDays.contains(day),
                      onSelected: (selected) => setDialogState(() {
                        if (selected) {
                          chosenDays.add(day);
                        } else {
                          chosenDays.remove(day);
                        }
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (template != ChoreTemplate.month)
                  DropdownButtonFormField<int>(
                    initialValue: starter,
                    decoration: const InputDecoration(
                      labelText: 'Who starts with it?',
                      prefixIcon: Icon(Icons.person_pin_circle_outlined),
                    ),
                    items: List<DropdownMenuItem<int>>.generate(
                      people.length,
                      (index) => DropdownMenuItem<int>(
                        value: index,
                        child: Text(people[index].name),
                      ),
                    ),
                    onChanged: (value) =>
                        setDialogState(() => starter = value ?? starter),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: chosenDays.isEmpty
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      ChoreScheduleSelection(
                        days: chosenDays.toList()..sort(),
                        starter: starter,
                      ),
                    ),
              child: Text(context.cosmicCopy('Add chore')),
            ),
          ],
        ),
      );
    },
  );
}

// /////Block Three///////////////////////////////////////////////////////////
Future<ChoreEditResult?> showChoreEditDialog({
  required BuildContext context,
  required String initialText,
}) {
  var editedText = initialText;
  return showDialog<ChoreEditResult>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.cosmicCopy('Edit chore')),
      content: TextFormField(
        initialValue: editedText,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: context.cosmicCopy('Chore')),
        onChanged: (value) => editedText = value,
        onFieldSubmitted: (value) =>
            Navigator.pop(context, ChoreEditResult.save(value.trim())),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, const ChoreEditResult.remove()),
          child: Text(context.cosmicCopy('Remove chore')),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, ChoreEditResult.save(editedText.trim())),
          child: const Text('Save change'),
        ),
      ],
    ),
  );
}

Future<ChorePerson?> showPersonEditDialog({
  required BuildContext context,
  required ChorePerson person,
  required int personIndex,
}) async {
  final nameController = TextEditingController(text: person.name);
  final phoneController = TextEditingController(text: person.phone);
  final updated = await showDialog<ChorePerson>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.cosmicCopy('Edit person')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Mobile number (optional)',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            final phone = phoneController.text.trim();
            Navigator.pop(
              context,
              ChorePerson(
                name: name,
                phone: phone.isEmpty ? null : phone,
                id: person.id.isEmpty
                    ? 'legacy-person-$personIndex'
                    : person.id,
                isDeviceOwner: person.isDeviceOwner,
              ),
            );
          },
          child: const Text('Save change'),
        ),
      ],
    ),
  );
  nameController.dispose();
  phoneController.dispose();
  return updated;
}

// /////Block Four////////////////////////////////////////////////////////////
Future<RotationMode?> showRotationModeDialog({
  required BuildContext context,
  required RotationMode selectedMode,
}) {
  return showDialog<RotationMode>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('Rotate options'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final option in RotationMode.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  option == selectedMode
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                ),
                title: Text(
                  context.cosmicCopy(option.label),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(context.cosmicCopy(option.description)),
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}
