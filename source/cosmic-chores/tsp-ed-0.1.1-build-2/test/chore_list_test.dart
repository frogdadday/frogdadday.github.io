// /////Block One/////////////////////////////////////////////////////////////
import 'package:cosmic_chores/models/chore_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('people rotate right while chore slots stay fixed', () {
    final list = ChoreList(
      id: 'test',
      title: 'Family chores',
      template: ChoreTemplate.week,
      monthDays: 31,
      people: const <ChorePerson>[
        ChorePerson(name: 'Alex'),
        ChorePerson(name: 'Bailey'),
        ChorePerson(name: 'Casey'),
      ],
      assignments: <int, List<List<String>>>{
        0: <List<String>>[
          <String>['Dishes'],
          <String>['Trash'],
          <String>['Sweep'],
        ],
        1: <List<String>>[
          <String>['Dishes'],
          <String>['Trash'],
          <String>['Sweep'],
        ],
      },
      sendHour: 6,
      sendMinute: 0,
      createdAt: DateTime(2026),
    );

    expect(list.assignmentsForDay(0).map((item) => item.person.name), <String>[
      'Alex',
      'Bailey',
      'Casey',
    ]);
    expect(list.assignmentsForDay(1).map((item) => item.person.name), <String>[
      'Casey',
      'Alex',
      'Bailey',
    ]);
    expect(list.assignmentsForDay(1).first.chores, <String>['Dishes']);
  });

  test('saved chore lists round-trip through JSON data', () {
    final original = ChoreList(
      id: 'round-trip',
      title: 'Our Chores',
      template: ChoreTemplate.workWeek,
      monthDays: 31,
      people: const <ChorePerson>[
        ChorePerson(name: 'Alex', phone: '+15555550100'),
      ],
      assignments: <int, List<List<String>>>{
        0: <List<String>>[
          <String>['Feed pets'],
        ],
      },
      sendHour: 6,
      sendMinute: 15,
      createdAt: DateTime(2026, 10, 3),
    );
    final restored = ChoreList.fromJson(original.toJson());
    expect(restored.title, original.title);
    expect(restored.people.single.phone, '+15555550100');
    expect(restored.assignments[0]!.single, <String>['Feed pets']);
    expect(restored.formattedTime, '6:15 a.m.');
  });

  test('rotation modes provide stable, two-day, daily, and weekly choices', () {
    ChoreList listFor(RotationMode mode) => ChoreList(
      id: mode.name,
      title: 'Rotation test',
      template: ChoreTemplate.week,
      monthDays: 31,
      people: const <ChorePerson>[
        ChorePerson(name: 'Alex'),
        ChorePerson(name: 'Bailey'),
        ChorePerson(name: 'Casey'),
      ],
      assignments: const <int, List<List<String>>>{},
      sendHour: 6,
      sendMinute: 0,
      createdAt: DateTime(2026, 10, 3),
      rotationMode: mode,
    );

    expect(listFor(RotationMode.none).personForSlot(0, 20).name, 'Alex');
    expect(listFor(RotationMode.daily).personForSlot(0, 1).name, 'Casey');
    expect(
      listFor(RotationMode.everyOtherDay).personForSlot(0, 1).name,
      'Alex',
    );
    expect(
      listFor(RotationMode.everyOtherDay).personForSlot(0, 2).name,
      'Casey',
    );
    expect(listFor(RotationMode.weekly).personForSlot(0, 6).name, 'Alex');
    expect(listFor(RotationMode.weekly).personForSlot(0, 7).name, 'Casey');
  });

  test(
    'calendar rotation is stable across the anchor, DST, and year changes',
    () {
      final anchor = DateTime(2026, 3, 8, 23, 50);
      expect(
        ChoreRotation.stepForDate(
          mode: RotationMode.daily,
          anchor: anchor,
          date: DateTime(2026, 3, 7, 8),
        ),
        0,
      );
      expect(
        ChoreRotation.stepForDate(
          mode: RotationMode.daily,
          anchor: anchor,
          date: DateTime(2026, 3, 9, 0, 1),
        ),
        1,
      );
      expect(
        ChoreRotation.stepForDate(
          mode: RotationMode.everyOtherDay,
          anchor: anchor,
          date: DateTime(2026, 3, 12),
        ),
        2,
      );
      expect(
        ChoreRotation.stepForDate(
          mode: RotationMode.weekly,
          anchor: DateTime(2026, 12, 28),
          date: DateTime(2027, 1, 4),
        ),
        1,
      );
    },
  );

  test('rotation lane helpers are inverse operations', () {
    for (var lane = 0; lane < 4; lane++) {
      final person = ChoreRotation.personIndexForLane(
        laneIndex: lane,
        peopleCount: 4,
        rotationStep: 7,
      );
      expect(
        ChoreRotation.laneForPerson(
          personIndex: person,
          peopleCount: 4,
          rotationStep: 7,
        ),
        lane,
      );
    }
  });

  test('older saved lists default to daily rotation', () {
    final original =
        ChoreList(
            id: 'legacy',
            title: 'Older list',
            template: ChoreTemplate.week,
            monthDays: 31,
            people: const <ChorePerson>[ChorePerson(name: 'Alex')],
            assignments: const <int, List<List<String>>>{},
            sendHour: 6,
            sendMinute: 0,
            createdAt: DateTime(2026, 10, 3),
          ).toJson()
          ..remove('rotationMode')
          ..remove('rotationAnchor');

    final restored = ChoreList.fromJson(original);
    expect(restored.rotationMode, RotationMode.daily);
    expect(restored.rotationAnchor, DateTime(2026, 10, 3));
  });

  test('legacy duplicate person ids are made distinct on load', () {
    final source = ChoreList(
      id: 'dedupe',
      title: 'Chores',
      template: ChoreTemplate.week,
      monthDays: 31,
      people: const <ChorePerson>[
        ChorePerson(name: 'Alex', id: 'same'),
        ChorePerson(name: 'Bailey', id: 'same'),
      ],
      assignments: <int, List<List<String>>>{
        0: <List<String>>[<String>[], <String>[]],
      },
      sendHour: 6,
      sendMinute: 0,
      createdAt: DateTime(2026, 10, 3),
    ).toJson();

    final restored = ChoreList.fromJson(source);
    expect(restored.people.map((person) => person.id).toSet().length, 2);
    expect(restored.people.first.id, 'same');
  });
}
