// /////Block One/////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import '../models/chore_list.dart';
import '../services/chore_store.dart';
import '../services/cosmic_copy.dart';
import '../services/native_bridge.dart';
import '../services/starter_week.dart';
import '../widgets/responsive_list_view.dart';
import 'create_chore_list_page.dart';

class QuickStartPage extends StatefulWidget {
  const QuickStartPage({super.key, required this.store, required this.onSaved});

  final ChoreStore store;
  final VoidCallback onSaved;

  @override
  State<QuickStartPage> createState() => _QuickStartPageState();
}

class _QuickStartPageState extends State<QuickStartPage> {
  final _count = TextEditingController(text: '2');
  final _names = <TextEditingController>[];
  RotationMode _rotation = RotationMode.daily;
  bool _remindersEnabled = false;
  TimeOfDay _sendTime = const TimeOfDay(hour: 6, minute: 0);
  ChoreList? _draft;
  bool _saving = false;

  @override
  void dispose() {
    _count.dispose();
    for (final controller in _names) {
      controller.dispose();
    }
    super.dispose();
  }

  void _makeDraft() {
    final count = int.tryParse(_count.text.trim());
    if (count == null || count < 1 || count > 20) {
      _message('Enter a number from 1 to 20.');
      return;
    }
    setState(() {
      while (_names.length < count) {
        _names.add(TextEditingController());
      }
      while (_names.length > count) {
        _names.removeLast().dispose();
      }
    });
  }

  void _review() {
    if (_names.isEmpty) {
      _makeDraft();
      return;
    }
    final names = _names.map((item) => item.text.trim()).toList();
    if (names.any((name) => name.isEmpty)) {
      _message('Add a name for everyone first.');
      return;
    }
    setState(
      () => _draft = StarterWeek.create(
        names: names,
        rotationMode: _rotation,
        remindersEnabled: _remindersEnabled,
        sendHour: _sendTime.hour,
        sendMinute: _sendTime.minute,
      ),
    );
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.cosmicCopy(text))));

  Future<void> _pickReminderTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _sendTime,
    );
    if (selected != null && mounted) setState(() => _sendTime = selected);
  }

  Future<void> _showReminderIssue({required bool permissionDenied}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Plan saved'),
        content: Text(
          permissionDenied
              ? 'Notifications are off, so the daily reminder will stay quiet. Your plan is saved and still works normally.'
              : 'The plan was saved, but its reminder could not be scheduled. You can still use the plan normally.',
        ),
        actions: <Widget>[
          if (permissionDenied)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                NativeBridge.openNotificationSettings();
              },
              child: const Text('Notification settings'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _startUsing() async {
    final draft = _draft;
    if (draft == null || _saving || !widget.store.writable) return;
    setState(() => _saving = true);
    try {
      await widget.store.save(draft);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _message('The starter plan could not be saved. Please try again.');
      }
      return;
    }
    if (draft.remindersEnabled) {
      try {
        final scheduled = await NativeBridge.scheduleReminder(draft);
        if (!scheduled) {
          await _showReminderIssue(permissionDenied: true);
        }
      } catch (_) {
        await _showReminderIssue(permissionDenied: false);
      }
    }
    if (mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }

  void _customize() {
    final draft = _draft;
    if (draft == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Customize plan')),
          body: CreateChoreListPage(
            store: widget.store,
            initialList: draft,
            onSaved: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              widget.onSaved();
            },
          ),
        ),
      ),
    );
  }

  // /////Block Two///////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) => ResponsiveListView(
    children: [
      Text(
        context.cosmicCopy(
          _draft == null ? 'Quick Start' : 'Your starter week',
        ),
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      if (_draft == null) ...[
        Text(
          context.cosmicCopy(
            'Make a useful first draft in about a minute. Everything stays editable.',
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _count,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: context.cosmicCopy('How many people?'),
            prefixIcon: const Icon(Icons.groups_rounded),
          ),
          onSubmitted: (_) => _makeDraft(),
        ),
        const SizedBox(height: 10),
        FilledButton(onPressed: _makeDraft, child: const Text('Add names')),
        if (_names.isNotEmpty) ...[
          const SizedBox(height: 18),
          for (var index = 0; index < _names.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _names[index],
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: context.cosmicCopy('Person ${index + 1}'),
                ),
              ),
            ),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.contacts_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.cosmicCopy(
                        'Want the daily message ready to send? After this quick setup, choose “Customize my plan” and use Contacts to add each person’s phone number. Your starter chores will stay in place.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.cosmicCopy('How should chores rotate?'),
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<RotationMode>(
            initialValue: _rotation,
            decoration: const InputDecoration(labelText: 'Rotation choice'),
            items: RotationMode.values
                .map(
                  (mode) => DropdownMenuItem<RotationMode>(
                    value: mode,
                    child: Text(mode.label),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _rotation = value!),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Text(context.cosmicCopy(_rotation.description)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Daily reminder'),
            subtitle: Text(
              _remindersEnabled
                  ? 'On at ${_sendTime.format(context)}. Android may ask for notification permission when you save.'
                  : 'Off. No reminder or notification will be scheduled.',
            ),
            value: _remindersEnabled,
            onChanged: (value) => setState(() => _remindersEnabled = value),
          ),
          if (_remindersEnabled)
            OutlinedButton.icon(
              onPressed: _pickReminderTime,
              icon: const Icon(Icons.schedule_rounded),
              label: Text('Reminder time: ${_sendTime.format(context)}'),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _review,
            child: const Text('Show my starter week'),
          ),
        ],
      ] else ...[
        Text(
          context.cosmicCopy(
            'This is a sensible starting point, not a locked-in plan. You can change every chore, person, day, and rotation.',
          ),
        ),
        const SizedBox(height: 16),
        for (var day = 0; day < 7; day++)
          Card(
            child: ListTile(
              title: Text(_draft!.dayLabels[day]),
              subtitle: Text(
                _draft!
                    .assignmentsForDay(day)
                    .map(
                      (row) => '${row.person.name}: ${row.chores.join(', ')}',
                    )
                    .join('\n'),
              ),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _customize,
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Customize my plan'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _saving ? null : _startUsing,
          child: Text(_saving ? 'Saving…' : 'Start using this plan'),
        ),
      ],
    ],
  );
}
