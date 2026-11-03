// /////Block One/////////////////////////////////////////////////////////////
import '../services/local_calendar.dart';
import '../services/cosmic_copy.dart';

enum ChoreTemplate { month, week, workWeek }

enum RotationMode { none, daily, everyOtherDay, weekly }

// /////Block One A///////////////////////////////////////////////////////////
/// The one source of truth for how people move between fixed chore lanes.
///
/// Rotation starts on the local calendar date of [anchor]. Dates before the
/// anchor deliberately use step zero: a newly created list never appears to
/// have rotated before it exists. LocalCalendar uses calendar days, rather
/// than 24-hour durations, so daylight-saving changes cannot skip a turn.
class ChoreRotation {
  const ChoreRotation._();

  static int stepForDate({
    required RotationMode mode,
    required DateTime anchor,
    required DateTime date,
  }) {
    final elapsed = LocalCalendar.daysBetween(anchor, date);
    return mode.rotationStep(elapsed < 0 ? 0 : elapsed);
  }

  static int personIndexForLane({
    required int laneIndex,
    required int peopleCount,
    required int rotationStep,
  }) {
    if (peopleCount <= 0) return 0;
    final raw = (laneIndex - rotationStep) % peopleCount;
    return raw < 0 ? raw + peopleCount : raw;
  }

  /// Returns the fixed lane occupied by a person at [personIndex].
  static int laneForPerson({
    required int personIndex,
    required int peopleCount,
    required int rotationStep,
  }) {
    if (peopleCount <= 0) return 0;
    return (personIndex + rotationStep) % peopleCount;
  }
}

extension RotationModeDetails on RotationMode {
  String get label => switch (this) {
    RotationMode.none => 'No daily changes',
    RotationMode.daily => 'Daily rotate',
    RotationMode.everyOtherDay => 'Every other day',
    RotationMode.weekly => 'Weekly rotate',
  };

  String get description => switch (this) {
    RotationMode.none => 'Everyone stays with the same chore position.',
    RotationMode.daily => 'Names move one position to the right every day.',
    RotationMode.everyOtherDay =>
      'Each person keeps a position for two days, then moves right.',
    RotationMode.weekly =>
      'Everyone keeps a position for seven days, then moves right.',
  };

  int rotationStep(int elapsedDays) => switch (this) {
    RotationMode.none => 0,
    RotationMode.daily => elapsedDays,
    RotationMode.everyOtherDay => elapsedDays ~/ 2,
    RotationMode.weekly => elapsedDays ~/ 7,
  };
}

extension ChoreTemplateDetails on ChoreTemplate {
  String get label => switch (this) {
    ChoreTemplate.month => 'Special & deep cleaning',
    ChoreTemplate.week => 'Full week',
    ChoreTemplate.workWeek => 'Work week',
  };

  String get description => switch (this) {
    ChoreTemplate.month => 'Dated extra chores that join a weekly plan',
    ChoreTemplate.week => 'Sunday through Saturday',
    ChoreTemplate.workWeek => 'Monday through Friday',
  };
}

class ChorePerson {
  const ChorePerson({
    required this.name,
    this.phone,
    this.id = '',
    this.isDeviceOwner = false,
  });

  final String name;
  final String? phone;
  final String id;
  final bool isDeviceOwner;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'phone': phone,
    'id': id,
    'isDeviceOwner': isDeviceOwner,
  };

  factory ChorePerson.fromJson(Map<String, Object?> json) => ChorePerson(
    name: json['name']! as String,
    phone: json['phone'] as String?,
    id: json['id'] as String? ?? '',
    // Lists made before this setting existed used “Me” as the clear owner
    // label. Preserve that older list behavior once, then save the explicit
    // flag from now on.
    isDeviceOwner:
        json['isDeviceOwner'] as bool? ??
        (json['name']! as String).trim().toLowerCase() == 'me',
  );
}

// /////Block Two/////////////////////////////////////////////////////////////
class ChoreList {
  ChoreList({
    required this.id,
    required this.title,
    required this.template,
    required this.monthDays,
    required this.people,
    required this.assignments,
    required this.sendHour,
    required this.sendMinute,
    required this.createdAt,
    this.remindersEnabled = true,
    this.rotationMode = RotationMode.daily,
    DateTime? rotationAnchor,
    Map<int, List<List<String>>>? choreIds,
    this.addToListId,
  }) : rotationAnchor = LocalCalendar.date(rotationAnchor ?? createdAt),
       choreIds =
           choreIds ??
           assignments.map(
             (day, slots) => MapEntry(
               day,
               List.generate(
                 slots.length,
                 (slot) => List.generate(
                   slots[slot].length,
                   (index) => '$id/$day/$slot/$index',
                 ),
               ),
             ),
           );

  final String id;
  final String title;
  final ChoreTemplate template;
  final int monthDays;
  final List<ChorePerson> people;
  final Map<int, List<List<String>>> assignments;
  final Map<int, List<List<String>>> choreIds;

  /// When set, this list contributes scheduled chores to another list's day.
  final String? addToListId;

  /// Special & deep-cleaning lists are calendar-dated projects, never their
  /// own daily plan. Keeping this distinction on the model avoids accidentally
  /// scheduling an orphaned project as a second chore list.
  bool get isSpecialProject => template == ChoreTemplate.month;

  bool get isMainPlan => !isSpecialProject && addToListId == null;

  String completionKey(DateTime date, int slot, int chore) {
    final day = dayIndexForDate(date)!;
    final person = personForSlot(
      slot,
      day,
      rotationStep: rotationForDate(date),
    );
    final personId = person.id.isEmpty
        ? 'legacy-person-${people.indexOf(person)}'
        : person.id;
    return '$id|${LocalCalendar.key(date)}|$personId|${choreIds[day]![slot][chore]}';
  }

  final int sendHour;
  final int sendMinute;
  final bool remindersEnabled;
  final DateTime createdAt;
  final RotationMode rotationMode;
  final DateTime rotationAnchor;

  /// Phone numbers for the people who should receive the prepared message.
  /// The saved device owner is excluded, so a two-person household opens a
  /// regular one-to-one Android Messages conversation instead of a group.
  List<String> get messageRecipients => people
      .where((person) => !person.isDeviceOwner)
      .map((person) => person.phone)
      .whereType<String>()
      .where((phone) => phone.isNotEmpty)
      .toSet()
      .toList();

  ChoreList withAddToListId(String? value) => ChoreList(
    id: id,
    title: title,
    template: template,
    monthDays: monthDays,
    people: people,
    assignments: assignments,
    choreIds: choreIds,
    sendHour: sendHour,
    sendMinute: sendMinute,
    remindersEnabled: remindersEnabled,
    createdAt: createdAt,
    rotationMode: rotationMode,
    rotationAnchor: rotationAnchor,
    addToListId: value,
  );

  int get dayCount => switch (template) {
    ChoreTemplate.month => LocalCalendar.daysInMonth(LocalCalendar.now()),
    ChoreTemplate.week => 7,
    ChoreTemplate.workWeek => 5,
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
  };

  String get formattedTime {
    final suffix = sendHour >= 12 ? 'p.m.' : 'a.m.';
    final hour = sendHour % 12 == 0 ? 12 : sendHour % 12;
    return '$hour:${sendMinute.toString().padLeft(2, '0')} $suffix';
  }

  // /////Block Three/////////////////////////////////////////////////////////
  int get storageDayCount => template == ChoreTemplate.month ? 31 : dayCount;

  int? dayIndexForDate(DateTime date) => switch (template) {
    ChoreTemplate.month => date.day - 1,
    ChoreTemplate.week => date.weekday % 7,
    ChoreTemplate.workWeek => date.weekday <= 5 ? date.weekday - 1 : null,
  };

  int rotationForDate(DateTime date) => ChoreRotation.stepForDate(
    mode: rotationMode,
    anchor: rotationAnchor,
    date: date,
  );

  DateTime dateForDay(int day, DateTime reference) => switch (template) {
    ChoreTemplate.month => DateTime(reference.year, reference.month, day + 1),
    ChoreTemplate.week => DateTime(
      reference.year,
      reference.month,
      reference.day - reference.weekday % 7 + day,
    ),
    ChoreTemplate.workWeek => DateTime(
      reference.year,
      reference.month,
      reference.day - reference.weekday + 1 + day,
    ),
  };

  String labelForDay(int day) =>
      template == ChoreTemplate.month ? 'Day ${day + 1}' : dayLabels[day];

  String messageForDate(DateTime date, {bool cosmicMode = false}) {
    final day = dayIndexForDate(date);
    if (day == null) {
      return CosmicCopy.forMode(
        '$title — No chores scheduled today.',
        cosmic: cosmicMode,
      );
    }
    return messageForDay(
      day,
      rotationStep: rotationForDate(date),
      cosmicMode: cosmicMode,
    );
  }

  ChorePerson personForSlot(int slotIndex, int dayIndex, {int? rotationStep}) {
    final step = rotationStep ?? rotationMode.rotationStep(dayIndex);
    return people[ChoreRotation.personIndexForLane(
      laneIndex: slotIndex,
      peopleCount: people.length,
      rotationStep: step,
    )];
  }

  List<({ChorePerson person, List<String> chores})> assignmentsForDay(
    int dayIndex, {
    int? rotationStep,
  }) {
    final slots = assignments[dayIndex] ?? const <List<String>>[];
    return List.generate(people.length, (slotIndex) {
      final chores = slotIndex < slots.length
          ? List<String>.unmodifiable(slots[slotIndex])
          : const <String>[];
      return (
        person: personForSlot(slotIndex, dayIndex, rotationStep: rotationStep),
        chores: chores,
      );
    });
  }

  String messageForDay(
    int dayIndex, {
    int? rotationStep,
    bool cosmicMode = false,
  }) {
    final safeDay = dayIndex.clamp(0, storageDayCount - 1);
    final buffer = StringBuffer()
      ..writeln('Cosmic Chores — ${labelForDay(safeDay)}')
      ..writeln();
    for (final assignment in assignmentsForDay(
      safeDay,
      rotationStep: rotationStep,
    )) {
      final chores = assignment.chores.isEmpty
          ? 'No chores today'
          : assignment.chores.join(', ');
      buffer.writeln(
        '${assignment.person.name}: ${CosmicCopy.forMode(chores, cosmic: cosmicMode)}',
      );
    }
    buffer
      ..writeln()
      ..write('Sent from Cosmic Chores 🐸');
    return buffer.toString();
  }

  // /////Block Four//////////////////////////////////////////////////////////
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'template': template.name,
    'monthDays': monthDays,
    'people': people.map((person) => person.toJson()).toList(),
    'assignments': assignments.map(
      (key, value) => MapEntry(key.toString(), value),
    ),
    'choreIds': choreIds.map((key, value) => MapEntry(key.toString(), value)),
    'addToListId': addToListId,
    'sendHour': sendHour,
    'sendMinute': sendMinute,
    'remindersEnabled': remindersEnabled,
    'createdAt': createdAt.toIso8601String(),
    'rotationMode': rotationMode.name,
    'rotationAnchor': rotationAnchor.toIso8601String(),
  };

  factory ChoreList.fromJson(Map<String, Object?> json) {
    final rawAssignments = json['assignments']! as Map<String, Object?>;
    final list = ChoreList(
      id: json['id']! as String,
      title: json['title']! as String,
      template: ChoreTemplate.values.byName(json['template']! as String),
      monthDays: json['monthDays']! as int,
      people: _peopleFromJson(json['people']! as List<Object?>),
      assignments: rawAssignments.map(
        (key, value) => MapEntry(
          int.parse(key),
          (value! as List<Object?>)
              .map((slot) => (slot! as List<Object?>).cast<String>().toList())
              .toList(),
        ),
      ),
      choreIds: (json['choreIds'] as Map<String, Object?>?)?.map(
        (key, value) => MapEntry(
          int.parse(key),
          (value! as List)
              .map((slot) => (slot as List).cast<String>().toList())
              .toList(),
        ),
      ),
      addToListId: json['addToListId'] as String?,
      sendHour: json['sendHour']! as int,
      sendMinute: json['sendMinute']! as int,
      remindersEnabled: json['remindersEnabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt']! as String),
      rotationMode: RotationMode.values.byName(
        json['rotationMode'] as String? ?? RotationMode.daily.name,
      ),
      rotationAnchor: DateTime.parse(
        json['rotationAnchor'] as String? ?? json['createdAt']! as String,
      ),
    );
    if (list.id.isEmpty ||
        list.title.trim().isEmpty ||
        list.people.isEmpty ||
        list.people.any((person) => person.name.trim().isEmpty) ||
        list.sendHour < 0 ||
        list.sendHour > 23 ||
        list.sendMinute < 0 ||
        list.sendMinute > 59 ||
        list.assignments.keys.any((day) => day < 0 || day > 30)) {
      throw const FormatException('Invalid chore list');
    }
    for (final entry in list.assignments.entries) {
      final ids = list.choreIds[entry.key];
      if (entry.value.length > list.people.length ||
          ids == null ||
          ids.length != entry.value.length) {
        throw const FormatException('Invalid chore positions');
      }
      for (var slot = 0; slot < ids.length; slot++) {
        if (ids[slot].length != entry.value[slot].length) {
          throw const FormatException('Invalid chore identifiers');
        }
      }
    }
    return list;
  }

  /// Older versions did not require person ids. Keep every imported person
  /// addressable even when an old backup contains blank or duplicate ids.
  static List<ChorePerson> _peopleFromJson(List<Object?> rawPeople) {
    final usedIds = <String>{};
    return rawPeople.asMap().entries.map((entry) {
      final person = ChorePerson.fromJson(
        Map<String, Object?>.from(entry.value! as Map),
      );
      var id = person.id.trim();
      if (id.isEmpty || usedIds.contains(id)) {
        var suffix = entry.key;
        id = 'legacy-person-$suffix';
        while (usedIds.contains(id)) {
          suffix++;
          id = 'legacy-person-$suffix';
        }
      }
      usedIds.add(id);
      return ChorePerson(
        name: person.name,
        phone: person.phone,
        id: id,
        isDeviceOwner: person.isDeviceOwner,
      );
    }).toList();
  }
}
