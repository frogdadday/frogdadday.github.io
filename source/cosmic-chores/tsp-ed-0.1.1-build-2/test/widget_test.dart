// /////Block One/////////////////////////////////////////////////////////////
import 'package:cosmic_chores/main.dart';
import 'package:cosmic_chores/models/chore_list.dart';
import 'package:cosmic_chores/screens/cosmic_mission_control_page.dart';
import 'package:cosmic_chores/screens/create_chore_list_page.dart';
import 'package:cosmic_chores/services/chore_store.dart';
import 'package:cosmic_chores/widgets/constellation_title.dart';
import 'package:cosmic_chores/widgets/cosmic_star_field.dart';
import 'package:cosmic_chores/widgets/create_chore_list_dialogs.dart';
import 'package:cosmic_chores/widgets/frog_spaceship.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts with a clearly reachable daily checklist', (
    tester,
  ) async {
    await tester.pumpWidget(const CosmicChoresApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Today'), findsOneWidget);
    await tester.tap(find.text('Make list'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Make a new chore list'), findsOneWidget);
    expect(find.text('Special & deep cleaning'), findsOneWidget);
    expect(find.text('Full week'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Work week'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Work week'), findsOneWidget);
    expect(find.text('Send Me a Coffee'), findsOneWidget);
  });

  testWidgets('setup accepts a one-person household immediately', (
    tester,
  ) async {
    await tester.pumpWidget(const CosmicChoresApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Make list'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Full week'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text('Next: How many people?'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Next: How many people?'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Choose how to add them'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('Add the 1 person for this list.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'Alex');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Review list'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Review list'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('saved list editor exposes people and chores', (tester) async {
    final list = ChoreList(
      id: 'editable',
      title: 'House Chores',
      template: ChoreTemplate.week,
      monthDays: 31,
      people: const <ChorePerson>[
        ChorePerson(name: 'Alex'),
        ChorePerson(name: 'Bailey'),
      ],
      assignments: <int, List<List<String>>>{
        for (var day = 0; day < 7; day++)
          day: <List<String>>[
            <String>['Dishes'],
            <String>[],
          ],
      },
      sendHour: 6,
      sendMinute: 0,
      createdAt: DateTime(2026, 10, 3),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateChoreListPage(
            store: ChoreStore(),
            initialList: list,
            onSaved: () {},
          ),
        ),
      ),
    );

    expect(find.text('Edit the chore list'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -1000));
    await tester.pump();
    expect(find.text('Your visual schedule grid'), findsOneWidget);
    expect(find.text('Dishes'), findsWidgets);
    await tester.tap(find.text('Dishes').first);
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'Kitchen dishes');
    await tester.tap(find.text('Save change'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Kitchen dishes'), findsWidgets);
    await tester.tap(find.text('Kitchen dishes').first);
    await tester.pump();
    expect(find.text('Remove chore'), findsOneWidget);
    await tester.tap(find.text('Remove chore'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Save changes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('person and rotation dialogs preserve values and wording', (
    tester,
  ) async {
    ChorePerson? updatedPerson;
    RotationMode? updatedRotation;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: <Widget>[
                FilledButton(
                  onPressed: () async {
                    updatedPerson = await showPersonEditDialog(
                      context: context,
                      person: const ChorePerson(name: 'Alex', id: 'alex-id'),
                      personIndex: 0,
                    );
                  },
                  child: const Text('Open person editor'),
                ),
                FilledButton(
                  onPressed: () async {
                    updatedRotation = await showRotationModeDialog(
                      context: context,
                      selectedMode: RotationMode.daily,
                    );
                  },
                  child: const Text('Open rotation editor'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open rotation editor'));
    await tester.pump();
    expect(find.text('Rotate options'), findsOneWidget);
    for (final mode in RotationMode.values) {
      expect(find.text(mode.label), findsOneWidget);
      expect(find.text(mode.description), findsOneWidget);
    }
    await tester.tap(find.text(RotationMode.everyOtherDay.label));
    await tester.pumpAndSettle();
    expect(updatedRotation, RotationMode.everyOtherDay);

    await tester.tap(find.text('Open person editor'));
    await tester.pump();
    expect(find.text('Edit person'), findsOneWidget);
    expect(find.text('Mobile number (optional)'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Avery');
    await tester.tap(find.text('Save change'));
    await tester.pumpAndSettle();
    expect(updatedPerson?.name, 'Avery');
    expect(updatedPerson?.id, 'alex-id');
  });

  testWidgets('planned chores can repeat without filling each day manually', (
    tester,
  ) async {
    final list = ChoreList(
      id: 'planned',
      title: 'Weekly home',
      template: ChoreTemplate.week,
      monthDays: 31,
      people: const <ChorePerson>[
        ChorePerson(name: 'Alex'),
        ChorePerson(name: 'Bailey'),
      ],
      assignments: <int, List<List<String>>>{
        for (var day = 0; day < 7; day++)
          day: <List<String>>[<String>[], <String>[]],
      },
      sendHour: 6,
      sendMinute: 0,
      createdAt: DateTime(2026, 10, 3),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateChoreListPage(
            store: ChoreStore(),
            initialList: list,
            onSaved: () {},
          ),
        ),
      ),
    );

    final plannedChoreButton = find.widgetWithText(
      FilledButton,
      'Add a planned chore',
    );
    await tester.scrollUntilVisible(
      plannedChoreButton,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(plannedChoreButton);
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'Tidy counters');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.tap(find.text('Every day'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add chore'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('compact phones use bottom navigation without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const CosmicChoresApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded tablet windows use a navigation rail', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const CosmicChoresApp());
    await tester.pump();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cosmic Mode opens the space mission dashboard', (tester) async {
    await tester.pumpWidget(const CosmicChoresApp());
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Cosmic Mode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CosmicStarField), findsOneWidget);
    expect(find.byType(ConstellationTitle), findsOneWidget);
    expect(find.byType(FrogSpaceship), findsOneWidget);
    expect(find.byType(CosmicMissionControlPage), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(CosmicMissionControlPage)))
          .brightness,
      Brightness.dark,
    );
    expect(find.text('Missions'), findsOneWidget);
    expect(find.text('Normal Mode'), findsOneWidget);
    await tester.tap(find.text('Create new'));
    await tester.pump();
    expect(find.text('Make a new mission list'), findsOneWidget);
    expect(find.textContaining('add at least one crewmember'), findsOneWidget);
    expect(find.textContaining('few missions'), findsOneWidget);
    expect(find.textContaining('Make a new chore list'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
