// /////Block One/////////////////////////////////////////////////////////////
import 'package:cosmic_chores/models/chore_list.dart';
import 'package:cosmic_chores/models/daily_plan.dart';
import 'package:cosmic_chores/services/cosmic_copy.dart';
import 'package:cosmic_chores/services/starter_week.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CosmicCopy', () {
    test('leaves normal-mode copy unchanged', () {
      const original = 'People can edit every chore with the app developer.';
      expect(CosmicCopy.forMode(original, cosmic: false), original);
    });

    test('changes vocabulary while preserving capitalization and title', () {
      expect(
        CosmicCopy.forMode(
          'Cosmic Chores helps People assign chores to each person. The developer is the owner.',
          cosmic: true,
        ),
        'Cosmic Chores helps Crewmembers assign missions to each crewmember. The captain is the captain.',
      );
      expect(
        CosmicCopy.forMode('COSMIC CHORES — CHORE', cosmic: true),
        'COSMIC CHORES — MISSION',
      );
    });
  });

  group('mode-aware messages', () {
    final list = ChoreList(
      id: 'list',
      title: 'Our List',
      template: ChoreTemplate.week,
      monthDays: 31,
      people: const <ChorePerson>[ChorePerson(name: 'Alex', id: 'alex')],
      assignments: <int, List<List<String>>>{
        for (var day = 0; day < 7; day++)
          day: <List<String>>[
            if (day == 0) <String>['Dishes'] else <String>[],
          ],
      },
      sendHour: 6,
      sendMinute: 0,
      remindersEnabled: false,
      createdAt: DateTime(2026, 10, 11),
    );

    test('prepared messages use mission wording only in cosmic mode', () {
      final plan = DailyPlan.forList(
        mainList: list,
        allLists: <ChoreList>[list],
        date: DateTime(2026, 10, 12),
      );
      expect(plan.message, contains('No chores today'));
      expect(
        plan.messageForMode(cosmicMode: true),
        contains('No missions today'),
      );
      expect(plan.messageForMode(cosmicMode: true), contains('Cosmic Chores'));
    });

    test('reminder opt-in persists and legacy data remains enabled', () {
      final json = list.toJson();
      expect(ChoreList.fromJson(json).remindersEnabled, isFalse);
      json.remove('remindersEnabled');
      expect(ChoreList.fromJson(json).remindersEnabled, isTrue);
    });

    test('Quick Start does not silently enable reminders', () {
      final starter = StarterWeek.create(
        names: const <String>['Alex'],
        rotationMode: RotationMode.daily,
      );
      expect(starter.remindersEnabled, isFalse);
      expect(starter.sendHour, 6);
      expect(starter.sendMinute, 0);
    });
  });
}
