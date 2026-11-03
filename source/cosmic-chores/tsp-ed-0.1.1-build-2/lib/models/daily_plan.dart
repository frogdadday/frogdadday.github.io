// /////Block One/////////////////////////////////////////////////////////////
import 'chore_list.dart';
import '../services/local_calendar.dart';
import '../services/cosmic_copy.dart';

class PlannedChore {
  const PlannedChore({
    required this.title,
    required this.id,
    required this.sourceListId,
    required this.isExtraProject,
  });

  final String title;
  final String id;
  final String sourceListId;
  final bool isExtraProject;
}

class DailyPlanAssignment {
  const DailyPlanAssignment({required this.person, required this.chores});

  final ChorePerson person;
  final List<PlannedChore> chores;
}

// /////Block One A///////////////////////////////////////////////////////////
/// Keeps the deep-cleaning recipient rule visible and easy to extend later.
/// The default is intentionally the first effective person for that date.
enum ExtraProjectRecipientStrategy { firstEffectivePerson }

extension ExtraProjectRecipientStrategyDetails
    on ExtraProjectRecipientStrategy {
  int assignmentIndexFor({required int assignmentCount}) {
    assert(assignmentCount > 0);
    return switch (this) {
      ExtraProjectRecipientStrategy.firstEffectivePerson => 0,
    };
  }
}

// /////Block Two/////////////////////////////////////////////////////////////
/// The main list supplies people and rotation. Linked lists supply projects.
class DailyPlan {
  DailyPlan._({
    required this.mainList,
    required this.date,
    required this.assignments,
    required this.extraListTitles,
    required this.extraProjectRecipientStrategy,
  });

  final ChoreList mainList;
  final DateTime date;
  final List<DailyPlanAssignment> assignments;
  final List<String> extraListTitles;
  final ExtraProjectRecipientStrategy extraProjectRecipientStrategy;

  factory DailyPlan.forList({
    required ChoreList mainList,
    required Iterable<ChoreList> allLists,
    required DateTime date,
    ExtraProjectRecipientStrategy extraProjectRecipientStrategy =
        ExtraProjectRecipientStrategy.firstEffectivePerson,
  }) {
    final day = mainList.dayIndexForDate(date);
    if (day == null) {
      return DailyPlan._(
        mainList: mainList,
        date: date,
        assignments: const <DailyPlanAssignment>[],
        extraListTitles: const <String>[],
        extraProjectRecipientStrategy: extraProjectRecipientStrategy,
      );
    }
    final rotation = mainList.rotationForDate(date);
    final base = mainList.assignmentsForDay(day, rotationStep: rotation);
    final combined = <DailyPlanAssignment>[
      for (var slot = 0; slot < base.length; slot++)
        DailyPlanAssignment(
          person: base[slot].person,
          chores: <PlannedChore>[
            for (var chore = 0; chore < base[slot].chores.length; chore++)
              PlannedChore(
                title: base[slot].chores[chore],
                id: mainList.choreIds[day]![slot][chore],
                sourceListId: mainList.id,
                isExtraProject: false,
              ),
          ],
        ),
    ];
    final extras = allLists.where(
      (list) => list.isSpecialProject && list.addToListId == mainList.id,
    );
    final usedExtras = <String>[];
    for (final extra in extras) {
      final extraDay = extra.dayIndexForDate(date);
      if (extraDay == null || combined.isEmpty) continue;
      final extraAssignments = extra.assignmentsForDay(
        extraDay,
        rotationStep: extra.rotationForDate(date),
      );
      final projects = <PlannedChore>[];
      for (var slot = 0; slot < extraAssignments.length; slot++) {
        for (
          var chore = 0;
          chore < extraAssignments[slot].chores.length;
          chore++
        ) {
          projects.add(
            PlannedChore(
              title: extraAssignments[slot].chores[chore],
              id: extra.choreIds[extraDay]![slot][chore],
              sourceListId: extra.id,
              isExtraProject: true,
            ),
          );
        }
      }
      if (projects.isNotEmpty) {
        final recipient = extraProjectRecipientStrategy.assignmentIndexFor(
          assignmentCount: combined.length,
        );
        combined[recipient].chores.addAll(projects);
        usedExtras.add(extra.title);
      }
    }
    return DailyPlan._(
      mainList: mainList,
      date: date,
      assignments: combined,
      extraListTitles: usedExtras,
      extraProjectRecipientStrategy: extraProjectRecipientStrategy,
    );
  }

  String completionKey(DailyPlanAssignment assignment, PlannedChore chore) {
    final personId = assignment.person.id.isEmpty
        ? 'legacy-person-${mainList.people.indexOf(assignment.person)}'
        : assignment.person.id;
    return '${mainList.id}|${LocalCalendar.key(date)}|$personId|${chore.sourceListId}|${chore.id}';
  }

  String get message => messageForMode();

  String messageForMode({bool cosmicMode = false}) {
    final day = mainList.dayIndexForDate(date);
    if (day == null) {
      return CosmicCopy.forMode(
        '${mainList.title} — No chores scheduled today.',
        cosmic: cosmicMode,
      );
    }
    final buffer = StringBuffer()
      ..writeln('Cosmic Chores — ${mainList.labelForDay(day)}')
      ..writeln();
    for (final assignment in assignments) {
      final chores = assignment.chores.isEmpty
          ? 'No chores today'
          : assignment.chores.map((chore) => chore.title).join(', ');
      buffer.writeln(
        '${assignment.person.name}: ${CosmicCopy.forMode(chores, cosmic: cosmicMode)}',
      );
    }
    if (extraListTitles.isNotEmpty) {
      buffer.writeln('\nExtra project: ${extraListTitles.join(', ')}');
    }
    buffer
      ..writeln()
      ..write('Sent from Cosmic Chores 🐸');
    return buffer.toString();
  }
}
