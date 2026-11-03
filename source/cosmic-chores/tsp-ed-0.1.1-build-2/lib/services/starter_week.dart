// /////Block One/////////////////////////////////////////////////////////////
import '../models/chore_list.dart';
import 'local_calendar.dart';

/// Builds ordinary, editable weekly data for the optional Quick Start path.
class StarterWeek {
  const StarterWeek._();

  static ChoreList create({
    required List<String> names,
    required RotationMode rotationMode,
    bool remindersEnabled = false,
    int sendHour = 6,
    int sendMinute = 0,
  }) {
    final people = <ChorePerson>[
      for (var index = 0; index < names.length; index++)
        ChorePerson(name: names[index].trim(), id: 'quick-person-$index'),
    ];
    final chores = <String>[
      'Dishes',
      'Wipe kitchen counters',
      'Take out trash',
      'Sweep common areas',
      'Vacuum common areas',
      'Clean bathroom',
      'Pick up common areas',
      'Basic laundry task',
    ];
    final assignments = <int, List<List<String>>>{
      for (var day = 0; day < 7; day++)
        day: List<List<String>>.generate(
          people.length,
          (lane) => <String>[
            chores[(day * people.length + lane) % chores.length],
          ],
        ),
    };
    return ChoreList(
      id: 'quick-${DateTime.now().microsecondsSinceEpoch}',
      title: 'Our List',
      template: ChoreTemplate.week,
      monthDays: 31,
      people: people,
      assignments: assignments,
      sendHour: sendHour,
      sendMinute: sendMinute,
      remindersEnabled: remindersEnabled,
      createdAt: DateTime.now(),
      rotationMode: rotationMode,
      rotationAnchor: LocalCalendar.date(DateTime.now()),
    );
  }
}
