// /////Block One/////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import '../models/chore_list.dart';
import '../services/chore_store.dart';
import '../services/cosmic_copy.dart';
import '../services/local_calendar.dart';
import '../services/native_bridge.dart';
import '../widgets/chore_picker_dialog.dart';
import '../widgets/chore_people_editor.dart';
import '../widgets/chore_schedule_board.dart';
import '../widgets/create_chore_list_dialogs.dart';
import '../widgets/responsive_list_view.dart';
import '../widgets/rotation_preview.dart';
import 'quick_start_page.dart';

class CreateChoreListPage extends StatefulWidget {
  const CreateChoreListPage({
    super.key,
    required this.store,
    required this.onSaved,
    this.initialList,
    this.isCopy = false,
  });

  final ChoreStore store;
  final VoidCallback onSaved;
  final ChoreList? initialList;
  final bool isCopy;

  @override
  State<CreateChoreListPage> createState() => _CreateChoreListPageState();
}

class _CreateChoreListPageState extends State<CreateChoreListPage>
    with LocalDateObserver {
  bool _saving = false;
  bool _dirty = false;
  late DateTime _draftAnchor = widget.isCopy
      ? LocalCalendar.date(DateTime.now())
      : widget.initialList?.rotationAnchor ??
            LocalCalendar.date(DateTime.now());
  int step = 0;
  ChoreTemplate? template;
  int monthDays = 31;
  int targetPeople = 1;
  late final TextEditingController peopleCountController;
  late final TextEditingController personNameController;
  late final TextEditingController titleController;
  final List<ChorePerson> people = <ChorePerson>[];
  final Map<int, List<List<String>>> assignments = <int, List<List<String>>>{};
  final Map<int, List<List<String>>> choreIds = {};
  int _idSequence = 0;
  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_idSequence++}';
  List<ChorePerson> contactMatches = <ChorePerson>[];
  bool contactMode = false;
  bool contactSearching = false;
  int searchSequence = 0;
  int selectedDay = 0;
  TimeOfDay sendTime = const TimeOfDay(hour: 6, minute: 0);
  bool remindersEnabled = false;
  RotationMode rotationMode = RotationMode.daily;
  String? addToListId;
  bool _showRotationPreview = false;
  bool _hasFocusedPeopleCount = false;
  bool _usesDefaultTitle = false;
  bool _updatingDefaultTitle = false;

  bool get isEditing => widget.initialList != null && !widget.isCopy;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialList;
    peopleCountController = TextEditingController(
      text: (initial?.people.length ?? 1).toString(),
    );
    personNameController = TextEditingController();
    titleController = TextEditingController(
      text: widget.isCopy
          ? 'Copy of ${initial?.title ?? 'Our Chore List'}'
          : initial?.title ?? 'Our Chore List',
    );
    _usesDefaultTitle = initial == null;
    titleController.addListener(_onTitleChanged);
    if (initial != null) {
      step = 4;
      template = initial.template;
      monthDays = initial.monthDays;
      targetPeople = initial.people.length;
      people.addAll(
        initial.people.asMap().entries.map(
          (entry) => ChorePerson(
            name: entry.value.name,
            phone: entry.value.phone,
            id: entry.value.id.isEmpty
                ? 'legacy-person-${entry.key}'
                : entry.value.id,
            isDeviceOwner: entry.value.isDeviceOwner,
          ),
        ),
      );
      choreIds.addAll(
        initial.choreIds.map(
          (day, slots) => MapEntry(
            day,
            slots.map((ids) => List<String>.from(ids)).toList(),
          ),
        ),
      );
      assignments.addAll(
        initial.assignments.map(
          (day, slots) => MapEntry(
            day,
            slots.map((chores) => List<String>.from(chores)).toList(),
          ),
        ),
      );
      sendTime = TimeOfDay(hour: initial.sendHour, minute: initial.sendMinute);
      remindersEnabled = initial.remindersEnabled;
      rotationMode = initial.rotationMode;
      addToListId = initial.addToListId;
      _syncAssignments();
      if (initial.isSpecialProject) _normaliseSpecialProjectQueue();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_usesDefaultTitle || widget.initialList != null) return;
    final expected = context.isCosmicMode
        ? 'Our Mission List'
        : 'Our Chore List';
    if (titleController.text == expected) return;
    _updatingDefaultTitle = true;
    titleController.text = expected;
    _updatingDefaultTitle = false;
  }

  void _onTitleChanged() {
    if (_updatingDefaultTitle) return;
    _usesDefaultTitle = false;
    _markDirty();
  }

  @override
  void dispose() {
    peopleCountController.dispose();
    personNameController.dispose();
    titleController.dispose();
    super.dispose();
  }

  void _markDirty() => _dirty = true;

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: Text(
          context.cosmicCopy(
            'Your edits to this chore list have not been saved yet.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  // /////Block Two///////////////////////////////////////////////////////////
  @override
  void onLocalDateChanged(DateTime previous, DateTime current) {
    if (template != null) _syncAssignments();
  }

  int get dayCount => switch (template) {
    ChoreTemplate.month => LocalCalendar.daysInMonth(localNow),
    ChoreTemplate.week => 7,
    ChoreTemplate.workWeek => 5,
    null => 0,
  };

  List<String> get dayLabels => switch (template) {
    ChoreTemplate.month => List<String>.generate(
      dayCount,
      (index) => 'Day ${index + 1}',
    ),
    ChoreTemplate.week => const <String>[
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ],
    ChoreTemplate.workWeek => const <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
    ],
    null => const <String>[],
  };

  void _continueFromPeopleCount() {
    final parsed = int.tryParse(peopleCountController.text.trim());
    if (parsed == null || parsed < 1 || parsed > 20) {
      _showMessage('Enter a number from 1 to 20.');
      return;
    }
    setState(() {
      targetPeople = parsed;
      step = 2;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.cosmicCopy(message))));
  }

  void _addPerson(ChorePerson person) {
    final name = person.name.trim();
    if (name.isEmpty) return;
    final duplicate = people.any(
      (item) =>
          item.name.toLowerCase() == name.toLowerCase() &&
          item.phone == person.phone,
    );
    if (duplicate) {
      _showMessage('$name is already on this list.');
      return;
    }
    setState(() {
      _markDirty();
      people.add(ChorePerson(name: name, phone: person.phone, id: _newId()));
      _syncAssignments();
      personNameController.clear();
      contactMatches = <ChorePerson>[];
    });
  }

  void _addManualPerson() {
    _addPerson(ChorePerson(name: personNameController.text));
  }

  // /////Block Three/////////////////////////////////////////////////////////
  Future<void> _chooseContacts() async {
    var allowed = await NativeBridge.hasContactsPermission();
    if (!mounted) return;
    if (!allowed) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Search your contacts?'),
          content: const Text(
            'Cosmic Chores needs contact access only to find the names and phone numbers you search for. Nothing is uploaded, sold, or used for tracking. Android remembers your choice until you change it in Settings.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Allow contact search'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      allowed = await NativeBridge.requestContacts();
    }
    if (!mounted) return;
    if (!allowed) {
      _showMessage(
        'Contact access was not granted. You can still enter names manually.',
      );
      return;
    }
    setState(() {
      contactMode = true;
      personNameController.clear();
    });
  }

  Future<void> _searchContacts(String query) async {
    final sequence = ++searchSequence;
    if (query.trim().length < 2) {
      setState(() {
        contactMatches = <ChorePerson>[];
        contactSearching = false;
      });
      return;
    }
    setState(() => contactSearching = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || sequence != searchSequence || !contactMode) return;
    try {
      final matches = await NativeBridge.searchContacts(query);
      if (!mounted || sequence != searchSequence) return;
      setState(() {
        contactMatches = matches;
        contactSearching = false;
      });
    } catch (_) {
      if (!mounted || sequence != searchSequence) return;
      setState(() => contactSearching = false);
      _showMessage(
        'Contact search is unavailable. You can enter the name manually.',
      );
    }
  }

  // /////Block Four//////////////////////////////////////////////////////////
  void _beginChores() {
    _syncAssignments();
    setState(() {
      selectedDay = 0;
      step = 4;
    });
  }

  void _beginSpecialProject() {
    final parent = widget.store.mainPlans
        .where((list) => list.id == addToListId)
        .firstOrNull;
    if (parent == null) {
      _showMessage('Choose a weekly or work-week plan first.');
      return;
    }
    setState(() {
      _markDirty();
      people
        ..clear()
        ..add(ChorePerson(name: 'Project queue', id: 'project-queue'));
      targetPeople = 1;
      peopleCountController.text = '1';
      assignments.clear();
      choreIds.clear();
      rotationMode = parent.rotationMode;
      sendTime = TimeOfDay(hour: parent.sendHour, minute: parent.sendMinute);
      _syncAssignments();
      selectedDay = 0;
      step = 4;
    });
  }

  void _syncAssignments() {
    final storageDays = template == ChoreTemplate.month ? 31 : dayCount;
    for (var day = 0; day < storageDays; day++) {
      final slots = assignments.putIfAbsent(day, () => <List<String>>[]);
      final ids = choreIds.putIfAbsent(day, () => <List<String>>[]);
      while (slots.length < people.length) {
        slots.add(<String>[]);
      }
      if (slots.length > people.length) {
        slots.removeRange(people.length, slots.length);
      }
      while (ids.length < slots.length) {
        ids.add(<String>[]);
      }
      if (ids.length > slots.length) ids.removeRange(slots.length, ids.length);
      for (var slot = 0; slot < slots.length; slot++) {
        while (ids[slot].length < slots[slot].length) {
          ids[slot].add(_newId());
        }
      }
    }
    if (selectedDay >= dayCount) selectedDay = dayCount - 1;
  }

  /// Uses a whole upcoming template cycle, so a new list never labels a past
  /// Sunday or Monday with a pre-anchor (and therefore misleading) rotation.
  DateTime _scheduleCycleStart() {
    final reference = isEditing
        ? LocalCalendar.date(localNow)
        : LocalCalendar.date(_draftAnchor);
    return switch (template) {
      ChoreTemplate.week => DateTime(
        reference.year,
        reference.month,
        reference.day + (7 - reference.weekday) % 7,
      ),
      ChoreTemplate.workWeek => DateTime(
        reference.year,
        reference.month,
        reference.day + (8 - reference.weekday) % 7,
      ),
      ChoreTemplate.month || null => reference,
    };
  }

  DateTime _dateForScheduleDay(int day) => switch (template) {
    ChoreTemplate.month => DateTime(localNow.year, localNow.month, day + 1),
    ChoreTemplate.week || ChoreTemplate.workWeek => DateTime(
      _scheduleCycleStart().year,
      _scheduleCycleStart().month,
      _scheduleCycleStart().day + day,
    ),
    null => localNow,
  };

  int _rotationStepForDay(int day) => ChoreRotation.stepForDate(
    mode: rotationMode,
    anchor: _draftAnchor,
    date: _dateForScheduleDay(day),
  );

  void _normaliseSpecialProjectQueue() {
    final storageDays = template == ChoreTemplate.month ? 31 : dayCount;
    for (var day = 0; day < storageDays; day++) {
      final chores =
          assignments[day]?.expand((slot) => slot).toList() ?? <String>[];
      final ids = choreIds[day]?.expand((slot) => slot).toList() ?? <String>[];
      assignments[day] = <List<String>>[chores];
      choreIds[day] = <List<String>>[ids];
    }
    people
      ..clear()
      ..add(ChorePerson(name: 'Project queue', id: 'project-queue'));
    targetPeople = 1;
    peopleCountController.text = '1';
  }

  int _slotForPersonOnDay(int personIndex, int day) =>
      ChoreRotation.laneForPerson(
        personIndex: personIndex,
        peopleCount: people.length,
        rotationStep: _rotationStepForDay(day),
      );

  List<ChorePerson> _peopleForScheduleDay(int day) {
    if (template == ChoreTemplate.month) return people;
    return List<ChorePerson>.generate(
      people.length,
      (lane) =>
          people[ChoreRotation.personIndexForLane(
            laneIndex: lane,
            peopleCount: people.length,
            rotationStep: _rotationStepForDay(day),
          )],
    );
  }

  // /////Block Five/////////////////////////////////////////////////////////
  Future<void> _addScheduledChore() async {
    final chore = await showDialog<String>(
      context: context,
      builder: (context) => const ChorePickerDialog(),
    );
    if (!mounted || chore == null || chore.trim().isEmpty) return;
    final schedule = await showChoreScheduleDialog(
      context: context,
      chore: chore.trim(),
      template: template!,
      dayCount: dayCount,
      dayLabels: dayLabels,
      people: people,
    );
    if (!mounted || schedule == null) return;
    final lane = _slotForPersonOnDay(schedule.starter, schedule.days.first);
    setState(() {
      _markDirty();
      for (final day in schedule.days) {
        assignments[day]![lane].add(chore.trim());
        choreIds[day]![lane].add(_newId());
      }
    });
  }

  Future<void> _addChore(int day, int slot) async {
    final chore = await showDialog<String>(
      context: context,
      builder: (context) => const ChorePickerDialog(),
    );
    if (!mounted || chore == null || chore.trim().isEmpty) return;
    setState(() {
      _markDirty();
      selectedDay = day;
      assignments[day]![slot].add(chore.trim());
      choreIds[day]![slot].add(_newId());
    });
  }

  // /////Block Five B////////////////////////////////////////////////////////
  Future<void> _clearDay(int day) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear ${dayLabels[day]}?'),
        content: Text(
          context.cosmicCopy(
            'This removes the chores from this draft day only. Nothing changes in the saved list until you save.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.cosmicCopy('Keep chores')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear day'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _markDirty();
      for (final lane in assignments[day]!) {
        lane.clear();
      }
      for (final laneIds in choreIds[day]!) {
        laneIds.clear();
      }
      selectedDay = day;
    });
  }

  Future<void> _clearSchedule() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.cosmicCopy('Clear every chore?')),
        content: Text(
          context.cosmicCopy(
            'This keeps your people, dates, rotation, and message time. It removes all chore text from this draft until you add new chores and save.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.cosmicCopy('Keep chores')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _markDirty();
      for (final slots in assignments.values) {
        for (final lane in slots) {
          lane.clear();
        }
      }
      for (final slots in choreIds.values) {
        for (final laneIds in slots) {
          laneIds.clear();
        }
      }
    });
  }

  Future<void> _editChore(int day, int slot, int choreIndex) async {
    // Keep the edit value in the dialog result instead of manually disposing a
    // controller as the dialog starts its exit animation. The old controller
    // was disposed while Flutter still had dependents attached to its outgoing
    // text field on some physical Android devices.
    final outcome = await showChoreEditDialog(
      context: context,
      initialText: assignments[day]![slot][choreIndex],
    );
    if (!mounted || outcome == null) return;
    if (outcome.remove) {
      setState(() {
        _markDirty();
        selectedDay = day;
        assignments[day]![slot].removeAt(choreIndex);
        choreIds[day]![slot].removeAt(choreIndex);
      });
      return;
    }
    if (outcome.text == null || outcome.text!.isEmpty) return;
    setState(() {
      _markDirty();
      selectedDay = day;
      assignments[day]![slot][choreIndex] = outcome.text!;
    });
  }

  Future<void> _editPerson(int index) async {
    final updated = await showPersonEditDialog(
      context: context,
      person: people[index],
      personIndex: index,
    );
    if (!mounted || updated == null) return;
    setState(() {
      _markDirty();
      people[index] = updated;
    });
  }

  Future<void> _removePerson(int index) async {
    if (people.length == 1) {
      _showMessage('A chore list needs at least one person.');
      return;
    }
    final name = people[index].name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $name?'),
        content: Text(
          context.cosmicCopy(
            'This removes one starting chore lane from every day. Because people rotate through lanes, future assignments for everyone may change. Other chore lanes stay in place.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.cosmicCopy('Keep person')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.cosmicCopy('Remove person')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _markDirty();
      people.removeAt(index);
      for (final slots in assignments.values) {
        if (index < slots.length) slots.removeAt(index);
      }
      for (final slots in choreIds.values) {
        if (index < slots.length) slots.removeAt(index);
      }
      targetPeople = people.length;
      peopleCountController.text = targetPeople.toString();
    });
  }

  // /////Block Five A////////////////////////////////////////////////////////
  void _movePerson(int from, int to) {
    if (to < 0 || to >= people.length || from == to) return;
    setState(() {
      _markDirty();
      final person = people.removeAt(from);
      people.insert(to, person);
      // Chores stay in their fixed lanes. Only the starting person changes.
    });
    _showMessage('Starting order changed. Chore lanes stayed in place.');
  }

  Future<void> _changeTemplate(ChoreTemplate value) async {
    if (value == template) return;
    final oldTemplate = template;
    final oldAssignments = assignments.map(
      (day, slots) => MapEntry(
        day,
        slots.map((chores) => List<String>.from(chores)).toList(),
      ),
    );
    final oldIds = choreIds.map(
      (day, slots) =>
          MapEntry(day, slots.map((ids) => List<String>.from(ids)).toList()),
    );
    final oldDay = selectedDay;
    final monthConversion =
        template == ChoreTemplate.month || value == ChoreTemplate.month;
    final hasChores = assignments.values.any(
      (slots) => slots.any((chores) => chores.isNotEmpty),
    );
    if (hasChores && (monthConversion || value == ChoreTemplate.workWeek)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a different schedule?'),
          content: Text(
            context.cosmicCopy(
              monthConversion
                  ? 'Calendar dates and weekdays cannot be safely matched. This clears the draft’s chores but keeps your people. Your saved list stays unchanged until you save. You can undo this change.'
                  : 'Monday–Friday chores keep their weekdays. Weekend chores are removed from this draft. Your saved list stays unchanged until you save. You can undo this change.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep schedule'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Change schedule'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmed != true) {
        setState(() {});
        return;
      }
    }
    setState(() {
      _markDirty();
      template = value;
      assignments.clear();
      choreIds.clear();
      if (!monthConversion) {
        for (var day = 0; day < (value == ChoreTemplate.week ? 7 : 5); day++) {
          final sourceDay = value == ChoreTemplate.workWeek ? day + 1 : day - 1;
          if (sourceDay < 0 ||
              sourceDay >= (oldTemplate == ChoreTemplate.week ? 7 : 5)) {
            continue;
          }
          if (oldAssignments[sourceDay] != null) {
            assignments[day] = oldAssignments[sourceDay]!;
          }
          if (oldIds[sourceDay] != null) choreIds[day] = oldIds[sourceDay]!;
        }
      }
      selectedDay = 0;
      _syncAssignments();
      if (value == ChoreTemplate.month) {
        addToListId = null;
        _normaliseSpecialProjectQueue();
      }
    });
    if (hasChores) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Schedule changed. Check the day assignments before saving.',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (!mounted || _saving) return;
              setState(() {
                template = oldTemplate;
                assignments
                  ..clear()
                  ..addAll(oldAssignments);
                choreIds
                  ..clear()
                  ..addAll(oldIds);
                selectedDay = oldDay;
                _syncAssignments();
              });
            },
          ),
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: sendTime,
    );
    if (picked != null) {
      setState(() {
        _markDirty();
        sendTime = picked;
      });
    }
  }

  Future<void> _pickRotationMode() async {
    final selected = await showRotationModeDialog(
      context: context,
      selectedMode: rotationMode,
    );
    if (selected != null) {
      setState(() {
        _markDirty();
        rotationMode = selected;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!widget.store.writable) {
      _showMessage(
        'Saved data is unavailable. Open Saved lists and retry loading before saving.',
      );
      return;
    }
    final title = titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('Give this chore list a name.');
      return;
    }
    final phonePeople = people
        .where((person) => (person.phone ?? '').trim().isNotEmpty)
        .length;
    if (phonePeople == 2 && !people.any((person) => person.isDeviceOwner)) {
      _showMessage(
        'Choose who uses this phone. That lets two-person lists open a regular text instead of an unavailable group chat.',
      );
      return;
    }
    if (template == ChoreTemplate.month && addToListId == null) {
      _showMessage(
        'Choose the weekly or work-week plan this special chore should join.',
      );
      return;
    }
    final specialParent = template == ChoreTemplate.month
        ? widget.store.mainPlans
              .where((list) => list.id == addToListId)
              .firstOrNull
        : null;
    if (template == ChoreTemplate.month && specialParent == null) {
      _showMessage('Choose a saved weekly or work-week plan for this project.');
      return;
    }
    setState(() => _saving = true);
    final list = ChoreList(
      id: widget.isCopy
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : widget.initialList?.id ??
                DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      template: template!,
      monthDays: 31,
      people: template == ChoreTemplate.month
          ? <ChorePerson>[
              const ChorePerson(name: 'Project queue', id: 'project-queue'),
            ]
          : List<ChorePerson>.from(people),
      assignments: assignments.map(
        (key, value) => MapEntry(
          key,
          value.map((slot) => List<String>.from(slot)).toList(),
        ),
      ),
      choreIds: choreIds.map(
        (day, slots) =>
            MapEntry(day, slots.map((ids) => List<String>.from(ids)).toList()),
      ),
      sendHour: specialParent?.sendHour ?? sendTime.hour,
      sendMinute: specialParent?.sendMinute ?? sendTime.minute,
      remindersEnabled:
          specialParent?.remindersEnabled ??
          (template == ChoreTemplate.month ? false : remindersEnabled),
      createdAt: widget.isCopy
          ? DateTime.now()
          : widget.initialList?.createdAt ?? DateTime.now(),
      rotationMode: specialParent?.rotationMode ?? rotationMode,
      addToListId: addToListId,
      rotationAnchor: _draftAnchor,
    );
    try {
      await widget.store.save(list);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage(
          'The list could not be saved. Your draft is still here. Please try again.',
        );
      }
      return;
    }
    try {
      final parent = addToListId == null
          ? list
          : widget.store.lists
                .where((item) => item.id == addToListId)
                .firstOrNull;
      if (addToListId != null || parent?.remindersEnabled != true) {
        await NativeBridge.cancelReminder(list.id);
      }
      final reminderScheduled = parent?.remindersEnabled == true
          ? await NativeBridge.scheduleReminder(parent!)
          : true;
      if (parent?.remindersEnabled == true && !reminderScheduled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'List saved. Notifications are off, so the reminder will stay quiet until you turn them on.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => NativeBridge.openNotificationSettings(),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'List saved, but the reminder could not be scheduled. You can still prepare messages from Saved lists.',
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _dirty = false;
    });
    if (!isEditing) _reset();
    widget.onSaved();
  }

  void _reset() {
    setState(() {
      _draftAnchor = LocalCalendar.date(DateTime.now());
      step = 0;
      template = null;
      monthDays = 31;
      targetPeople = 3;
      peopleCountController.text = '3';
      people.clear();
      assignments.clear();
      choreIds.clear();
      selectedDay = 0;
      sendTime = const TimeOfDay(hour: 6, minute: 0);
      remindersEnabled = false;
      rotationMode = RotationMode.daily;
      addToListId = null;
      _updatingDefaultTitle = true;
      titleController.text = context.isCosmicMode
          ? 'Our Mission List'
          : 'Our Chore List';
      _updatingDefaultTitle = false;
      _usesDefaultTitle = true;
      contactMode = false;
      contactMatches = <ChorePerson>[];
      _dirty = false;
    });
  }

  // /////Block Six///////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    // Each setup screen owns form and theme dependencies. Replacing it
    // directly prevents Flutter from retaining an outgoing form subtree while
    // its dependent widgets are still active.
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !mounted) return;
        final discard = await _confirmDiscard();
        if (!mounted || !discard) return;
        _dirty = false;
        Navigator.of(this.context).pop();
      },
      child: switch (step) {
        0 => _templateStep(),
        1 => _peopleCountStep(),
        2 => _addPeopleStep(),
        3 => _reviewPeopleStep(),
        _ => _choresStep(),
      },
    );
  }

  Widget _page({required List<Widget> children}) {
    return ResponsiveListView(
      key: ValueKey<String>('create-step-$step'),
      children: children,
    );
  }

  Widget _heading(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.cosmicCopy(title),
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(context.cosmicCopy(description)),
        const SizedBox(height: 18),
      ],
    );
  }

  // /////Block Seven/////////////////////////////////////////////////////////
  Widget _templateStep() {
    return _page(
      children: <Widget>[
        _heading(
          'Make a new chore list',
          'Pick the kind of schedule, add at least one person, then give each day a few chores. The list keeps repeating automatically—week after week or month after month.',
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.rocket_launch_rounded),
            ),
            title: const Text(
              'Quick Start',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Make an editable starter week in about a minute.',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Quick Start')),
                  body: QuickStartPage(
                    store: widget.store,
                    onSaved: widget.onSaved,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Pick a template',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final option in ChoreTemplate.values)
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              onTap: () => setState(() {
                _markDirty();
                template = option;
                if (option != ChoreTemplate.month) addToListId = null;
              }),
              leading: Icon(
                template == option
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: template == option
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(
                context.cosmicCopy(option.label),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(context.cosmicCopy(option.description)),
            ),
          ),
        if (template == ChoreTemplate.month) _specialProjectStarter(),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: template == null
              ? null
              : template == ChoreTemplate.month && addToListId == null
              ? null
              : () {
                  if (template == ChoreTemplate.month) {
                    _beginSpecialProject();
                  } else {
                    setState(() => step = 1);
                  }
                },
          child: Text(
            context.cosmicCopy(
              template == ChoreTemplate.month
                  ? 'Next: Plan special chores'
                  : 'Next: How many people?',
            ),
          ),
        ),
      ],
    );
  }

  Widget _peopleCountStep() {
    return _page(
      children: <Widget>[
        _heading(
          'How many people are involved?',
          'You can always add another person before assigning chores.',
        ),
        TextField(
          controller: peopleCountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: context.cosmicCopy('Number of people'),
            prefixIcon: Icon(Icons.groups_rounded),
          ),
          onTap: () {
            if (_hasFocusedPeopleCount) return;
            _hasFocusedPeopleCount = true;
            peopleCountController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: peopleCountController.text.length,
            );
          },
          onSubmitted: (_) => _continueFromPeopleCount(),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _continueFromPeopleCount,
          child: const Text('Choose how to add them'),
        ),
        TextButton(
          onPressed: () => setState(() => step = 0),
          child: const Text('Back'),
        ),
      ],
    );
  }

  Widget _specialProjectStarter() {
    final candidates = widget.store.mainPlans;
    final selected = candidates.any((list) => list.id == addToListId)
        ? addToListId
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Attach this project',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              context.cosmicCopy(
                'Special & deep-cleaning chores always join one weekly or work-week plan. Whoever is first in that plan’s rotation gets the project that day.',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selected,
              decoration: const InputDecoration(labelText: 'Main plan'),
              hint: const Text('Choose a weekly or work-week plan'),
              items: candidates
                  .map(
                    (list) => DropdownMenuItem<String>(
                      value: list.id,
                      child: Text(list.title),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _markDirty();
                addToListId = value;
              }),
            ),
            if (candidates.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Save a Full week or Work week list first, then come back to add special projects.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  // /////Block Eight/////////////////////////////////////////////////////////
  Widget _addPeopleStep() {
    final enoughPeople = people.length >= targetPeople;
    return _page(
      children: <Widget>[
        _heading(
          'Add your people',
          people.isEmpty
              ? 'Add the $targetPeople ${targetPeople == 1 ? 'person' : 'people'} for this list. You can always add another later.'
              : '${people.length} of $targetPeople ${targetPeople == 1 ? 'person' : 'people'} added.',
        ),
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Want the daily message ready to send?',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  context.cosmicCopy(
                    'Use Contacts to add a person’s saved name and phone number. Nothing leaves your phone.',
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _chooseContacts,
                  icon: const Icon(Icons.contacts_rounded),
                  label: const Text('Use contacts'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (contactMode)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                contactMode = false;
                contactMatches = <ChorePerson>[];
              }),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Type a name manually instead'),
            ),
          ),
        TextField(
          controller: personNameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: context.cosmicCopy(
              contactMode ? 'Type a contact name' : 'Person’s name',
            ),
            prefixIcon: Icon(
              contactMode
                  ? Icons.search_rounded
                  : Icons.person_add_alt_1_rounded,
            ),
            suffixIcon: !contactMode
                ? IconButton(
                    tooltip: context.cosmicCopy('Add person'),
                    onPressed: _addManualPerson,
                    icon: const Icon(Icons.add_circle_rounded),
                  )
                : contactSearching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onChanged: contactMode ? _searchContacts : null,
          onSubmitted: contactMode ? null : (_) => _addManualPerson(),
        ),
        if (contactMode && contactMatches.isNotEmpty)
          Card(
            child: Column(
              children: <Widget>[
                for (final match in contactMatches)
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: Text(match.name),
                    subtitle: Text(match.phone ?? ''),
                    onTap: () => _addPerson(match),
                  ),
              ],
            ),
          ),
        if (contactMode &&
            personNameController.text.trim().isNotEmpty &&
            contactMatches.isEmpty &&
            !contactSearching)
          TextButton.icon(
            onPressed: _addManualPerson,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Use this typed name instead'),
          ),
        if (people.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (var index = 0; index < people.length; index++)
                InputChip(
                  label: Text(people[index].name),
                  onDeleted: () => _removePerson(index),
                ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: enoughPeople ? () => setState(() => step = 3) : null,
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(
            enoughPeople
                ? 'Review list'
                : 'Add ${targetPeople - people.length} more',
          ),
        ),
        TextButton(
          onPressed: () => setState(() => step = isEditing ? 4 : 0),
          child: const Text('Back'),
        ),
      ],
    );
  }

  // /////Block Nine//////////////////////////////////////////////////////////
  Widget _reviewPeopleStep() {
    return _page(
      children: <Widget>[
        _heading(
          'Everyone is here',
          'Check the group before the frog starts organizing chores.',
        ),
        Card(
          child: Column(
            children: <Widget>[
              for (var index = 0; index < people.length; index++)
                ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(people[index].name),
                  subtitle: people[index].phone == null
                      ? const Text('Entered manually')
                      : const Text('Selected from contacts'),
                  trailing: Wrap(
                    spacing: 2,
                    children: <Widget>[
                      IconButton(
                        tooltip: context.cosmicCopy('Edit person'),
                        onPressed: () => _editPerson(index),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: context.cosmicCopy('Remove person'),
                        onPressed: () => _removePerson(index),
                        icon: const Icon(Icons.person_remove_outlined),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        _deviceOwnerPicker(),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            targetPeople = people.length + 1;
            step = 2;
          }),
          icon: const Icon(Icons.person_add_alt_rounded),
          label: const Text('Oops, forgot someone'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _beginChores,
          icon: const Icon(Icons.cleaning_services_rounded),
          label: Text(context.cosmicCopy('Start making chores')),
        ),
      ],
    );
  }

  // /////Block Ten///////////////////////////////////////////////////////////
  Widget _deviceOwnerPicker() {
    return DeviceOwnerPicker(people: people, onChanged: _setDeviceOwner);
  }

  void _setDeviceOwner(int owner) {
    setState(() {
      _markDirty();
      for (var index = 0; index < people.length; index++) {
        final person = people[index];
        people[index] = ChorePerson(
          name: person.name,
          phone: person.phone,
          id: person.id,
          isDeviceOwner: index == owner,
        );
      }
    });
  }

  // /////Block Eleven////////////////////////////////////////////////////////
  Widget _visualScheduleBoard() {
    final cycleStart = _scheduleCycleStart();
    return ChoreScheduleBoard(
      template: template!,
      dayLabels: dayLabels,
      dates: List<DateTime>.generate(dayCount, _dateForScheduleDay),
      cycleStart: cycleStart,
      peopleByDay: List<List<ChorePerson>>.generate(
        dayCount,
        _peopleForScheduleDay,
      ),
      assignments: assignments,
      choreIds: choreIds,
      selectedDay: selectedDay,
      onSelectDay: (day) => setState(() => selectedDay = day),
      onEditChore: _editChore,
      onAddChore: _addChore,
      onClearDay: _clearDay,
      onClearSchedule: _clearSchedule,
      rotationPreview: template == ChoreTemplate.month
          ? null
          : _rotationPreview(),
    );
  }

  Widget _rotationPreview() {
    final draft = ChoreList(
      id: 'draft-preview',
      title: titleController.text.trim().isEmpty
          ? context.cosmicCopy('This chore list')
          : titleController.text.trim(),
      template: template!,
      monthDays: monthDays,
      people: List<ChorePerson>.unmodifiable(people),
      assignments: assignments.map(
        (day, slots) => MapEntry(
          day,
          slots.map((chores) => List<String>.unmodifiable(chores)).toList(),
        ),
      ),
      choreIds: choreIds,
      sendHour: sendTime.hour,
      sendMinute: sendTime.minute,
      remindersEnabled: remindersEnabled,
      createdAt: _draftAnchor,
      rotationMode: rotationMode,
      rotationAnchor: _draftAnchor,
    );
    return RotationPreview(
      draft: draft,
      startDate: _dateForScheduleDay(0),
      expanded: _showRotationPreview,
      onExpandedChanged: (value) =>
          setState(() => _showRotationPreview = value),
    );
  }

  // /////Block Twelve////////////////////////////////////////////////////////
  Widget _choresStep() {
    return _page(
      children: <Widget>[
        _heading(
          isEditing ? 'Edit the chore list' : 'Build the chore list',
          'Everything here can change. This schedule repeats forever: weekly lists carry into each new week, and monthly lists use the current month on the phone. Rotation follows local midnight, independently of reminder time.',
        ),
        TextField(
          controller: titleController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: context.cosmicCopy('Chore list name'),
            prefixIcon: Icon(Icons.drive_file_rename_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ChoreTemplate>(
          key: ValueKey<ChoreTemplate?>(template),
          initialValue: template,
          decoration: const InputDecoration(
            labelText: 'Schedule template',
            prefixIcon: Icon(Icons.calendar_view_week_rounded),
          ),
          items: ChoreTemplate.values
              .map(
                (option) => DropdownMenuItem<ChoreTemplate>(
                  value: option,
                  child: Text(context.cosmicCopy(option.label)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) _changeTemplate(value);
          },
        ),
        if (template == ChoreTemplate.month)
          Text(
            'Choose calendar dates for extra projects. They join the main weekly plan on that date; the rotating main plan decides who receives each project.',
          ),
        const SizedBox(height: 12),
        if (template == ChoreTemplate.month || addToListId != null) ...<Widget>[
          _dailyPlanPicker(),
          const SizedBox(height: 12),
        ],
        if (template == ChoreTemplate.month)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.cosmicCopy(
                    'This is a project queue, not a separate chore group. On each chosen date, its chores go to whoever is first in the selected main plan’s rotation.',
                  ),
                ),
              ),
            ),
          ),
        if (template != ChoreTemplate.month) ...<Widget>[
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Daily reminder'),
            subtitle: Text(
              remindersEnabled
                  ? 'On at ${sendTime.format(context)}. Android may ask for notification permission when you save.'
                  : 'Off. No reminder or notification will be scheduled.',
            ),
            value: remindersEnabled,
            onChanged: (value) => setState(() {
              remindersEnabled = value;
              _dirty = true;
            }),
          ),
          if (remindersEnabled)
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule_rounded),
              label: Text('Daily message time: ${sendTime.format(context)}'),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickRotationMode,
            icon: const Icon(Icons.sync_rounded),
            label: Text('Rotate options: ${rotationMode.label}'),
          ),
          const SizedBox(height: 12),
        ],
        if (template != ChoreTemplate.month)
          ChorePeopleEditorCard(
            people: people,
            onMoveEarlier: (index) => _movePerson(index, index - 1),
            onMoveLater: (index) => _movePerson(index, index + 1),
            onEdit: _editPerson,
            onRemove: _removePerson,
            onAdd: () => setState(() {
              targetPeople = people.length + 1;
              step = 2;
            }),
            onDeviceOwnerChanged: _setDeviceOwner,
          ),
        const SizedBox(height: 12),
        _visualScheduleBoard(),
        const SizedBox(height: 12),
        _plannedChoreCard(),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_rounded),
          label: Text(
            _saving
                ? 'Saving…'
                : isEditing
                ? 'Save changes'
                : context.cosmicCopy('Save chore list'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          remindersEnabled
              ? 'When you save, Android may ask once for notification permission. At the selected time, tap the private reminder to open the prepared message. Android may delay it slightly to protect battery life, and you always choose when to send.'
              : 'Reminders are off. You can still open this list and prepare a message whenever you choose.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _plannedChoreCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Quick add across several days',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            context.cosmicCopy(
              'The grid above is the easiest way to see each day. Use this helper when one chore repeats on several dates.',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _addScheduledChore,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(
              template == ChoreTemplate.month
                  ? 'Add a scheduled project'
                  : context.cosmicCopy('Add a planned chore'),
            ),
          ),
        ],
      ),
    ),
  );

  // /////Block Thirteen//////////////////////////////////////////////////////
  Widget _dailyPlanPicker() {
    final candidates = widget.store.lists
        .where((list) => list.id != widget.initialList?.id && list.isMainPlan)
        .toList();
    final selected = candidates.any((list) => list.id == addToListId)
        ? addToListId
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              template == ChoreTemplate.month
                  ? 'Add this to a main plan'
                  : 'Daily plan',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              context.cosmicCopy(
                template == ChoreTemplate.month
                    ? 'Special and deep-cleaning chores are calendar-dated extras. Pick the weekly or work-week plan they should join.'
                    : 'Keep this list on its own, or have its scheduled chores appear inside another list’s daily checklist and message.',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: ValueKey<String?>('daily-plan-$selected'),
              initialValue: selected,
              decoration: InputDecoration(
                labelText: context.cosmicCopy(
                  'Where should these chores appear?',
                ),
              ),
              hint: template == ChoreTemplate.month
                  ? const Text('Choose a main plan')
                  : null,
              items: <DropdownMenuItem<String?>>[
                if (template != ChoreTemplate.month)
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Its own daily plan'),
                  ),
                for (final candidate in candidates)
                  DropdownMenuItem<String?>(
                    value: candidate.id,
                    child: Text('Add to ${candidate.title}'),
                  ),
              ],
              onChanged: (value) => setState(() {
                _markDirty();
                addToListId = value;
              }),
            ),
            if (candidates.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Save a main weekly or work-week plan first, then return here to add special projects to it.',
                ),
              ),
            if (addToListId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.cosmicCopy(
                    'On each scheduled day, these chores go to whoever is first in that main list’s rotation. They will not create a separate daily message.',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
