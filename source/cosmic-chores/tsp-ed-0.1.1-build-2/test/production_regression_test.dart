// /////Block One/////////////////////////////////////////////////////////////
import 'dart:convert';

import 'package:cosmic_chores/main.dart';
import 'package:cosmic_chores/models/chore_list.dart';
import 'package:cosmic_chores/models/daily_plan.dart';
import 'package:cosmic_chores/screens/cosmic_mission_control_page.dart';
import 'package:cosmic_chores/screens/saved_lists_page.dart';
import 'package:cosmic_chores/screens/weekly_review_page.dart';
import 'package:cosmic_chores/services/chore_store.dart';
import 'package:cosmic_chores/services/local_calendar.dart';
import 'package:cosmic_chores/services/native_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ChoreList fixture({
  String id = 'house',
  ChoreTemplate template = ChoreTemplate.week,
  DateTime? anchor,
  RotationMode mode = RotationMode.daily,
}) => ChoreList(
  id: id,
  title: 'House chores',
  template: template,
  monthDays: 28,
  people: const [
    ChorePerson(name: 'Alex', phone: '111', id: 'alex1'),
    ChorePerson(name: 'Alex', phone: '222', id: 'alex2'),
    ChorePerson(name: 'Casey', id: 'casey'),
  ],
  assignments: {
    for (var day = 0; day < 31; day++)
      day: [
        ['Dishes'],
        ['Dishes'],
        ['Sweep'],
      ],
  },
  sendHour: 6,
  sendMinute: 0,
  createdAt: anchor ?? DateTime(2026, 3, 1),
  rotationMode: mode,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cosmic_chores/native');
  String? saved;
  String? progress;
  bool failWrite = false;
  int writes = 0;
  Map<Object?, Object?>? reminder;
  final reminderCalls = <String>[];
  String? sharedBody;
  setUp(() {
    saved = null;
    progress = null;
    failWrite = false;
    writes = 0;
    reminder = null;
    reminderCalls.clear();
    sharedBody = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'readState':
              return saved;
            case 'writeState':
              writes++;
              if (failWrite) throw PlatformException(code: 'STORAGE_WRITE');
              saved = call.arguments as String;
              return null;
            case 'readMissionProgress':
              return progress;
            case 'writeMissionProgress':
              progress = call.arguments as String;
              return null;
            case 'scheduleReminder':
              reminderCalls.add(call.method);
              reminder = call.arguments as Map;
              return true;
            case 'ensureReminder':
              reminderCalls.add(call.method);
              reminder = call.arguments as Map;
              return true;
            case 'readCosmicMode':
              return false;
            case 'shareMessage':
              sharedBody = (call.arguments as Map)['body'] as String;
              return true;
            default:
              return null;
          }
        });
  });
  tearDown(() {
    LocalCalendar.now = DateTime.now;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // /////Block Two///////////////////////////////////////////////////////////
  test('calendar days survive DST, leap years, month and year boundaries', () {
    expect(
      LocalCalendar.daysBetween(DateTime(2026, 3, 7), DateTime(2026, 3, 9)),
      2,
    );
    expect(
      LocalCalendar.daysBetween(DateTime(2026, 10, 31), DateTime(2026, 11, 2)),
      2,
    );
    expect(
      LocalCalendar.daysBetween(DateTime(2028, 2, 28), DateTime(2028, 3, 1)),
      2,
    );
    expect(
      LocalCalendar.daysBetween(DateTime(2026, 12, 31), DateTime(2027, 1, 1)),
      1,
    );
    expect(LocalCalendar.daysInMonth(DateTime(2028, 2)), 29);
    expect(LocalCalendar.daysInMonth(DateTime(2027, 2)), 28);
  });

  test(
    'the saved device owner is excluded from prepared message recipients',
    () {
      final people = <ChorePerson>[
        const ChorePerson(name: 'Taylor', phone: '111', isDeviceOwner: true),
        const ChorePerson(name: 'Sean', phone: '222'),
      ];
      final list = ChoreList(
        id: 'two-person-list',
        title: 'Two people',
        template: ChoreTemplate.week,
        monthDays: 28,
        people: people,
        assignments: const <int, List<List<String>>>{},
        sendHour: 6,
        sendMinute: 0,
        createdAt: DateTime(2026, 10, 4),
      );

      expect(list.messageRecipients, <String>['222']);
      expect(
        list.messageForDay(0),
        allOf(
          contains('Taylor: No chores today'),
          contains('Sean: No chores today'),
        ),
      );
    },
  );
  test('Sunday rotation continues instead of restarting weekly', () {
    final list = fixture();
    expect(list.rotationForDate(DateTime(2026, 3, 8)), 7);
    expect(
      list.messageForDate(DateTime(2026, 3, 8)),
      contains('Casey: Dishes'),
    );
    expect(list.rotationForDate(DateTime(2026, 2, 28)), 0);
  });
  test('work-week rotation counts weekends but has no weekend chores', () {
    final list = fixture(
      template: ChoreTemplate.workWeek,
      anchor: DateTime(2026, 10, 2),
    );
    expect(list.rotationForDate(DateTime(2026, 10, 5)), 3);
    expect(list.dayIndexForDate(DateTime(2026, 10, 3)), isNull);
    expect(list.dayIndexForDate(DateTime(2026, 10, 5)), 0);
  });
  test('month follows device calendar and keeps all 31 stored days', () {
    final list = fixture(template: ChoreTemplate.month);
    LocalCalendar.now = () => DateTime(2027, 2, 28);
    expect(list.dayCount, 28);
    expect(list.storageDayCount, 31);
    final restored = ChoreList.fromJson(list.toJson());
    LocalCalendar.now = () => DateTime(2027, 3, 1);
    expect(restored.dayCount, 31);
    expect(restored.assignments[30]!.first, ['Dishes']);
    expect(restored.messageForDate(DateTime(2027, 3, 31)), contains('Day 31'));
  });
  test('all rotation modes use the same elapsed calendar days', () {
    for (final mode in RotationMode.values) {
      final list = fixture(mode: mode);
      expect(
        list.rotationForDate(DateTime(2026, 3, 15)),
        mode.rotationStep(14),
      );
      expect(list.rotationForDate(DateTime(2026, 3, 1, 23, 59)), 0);
    }
  });
  test('effective assignments agree with every rotation mode', () {
    final anchor = DateTime(2026, 10, 4);
    final expectedFirstPeople = <RotationMode, List<String>>{
      RotationMode.none: <String>['Alex', 'Alex', 'Alex', 'Alex'],
      RotationMode.daily: <String>['Alex', 'Casey', 'Alex', 'Casey'],
      RotationMode.everyOtherDay: <String>['Alex', 'Alex', 'Casey', 'Alex'],
      RotationMode.weekly: <String>['Alex', 'Alex', 'Alex', 'Casey'],
    };
    final offsets = <int>[0, 1, 2, 7];
    for (final mode in RotationMode.values) {
      final list = fixture(anchor: anchor, mode: mode);
      for (var index = 0; index < offsets.length; index++) {
        final date = DateTime(2026, 10, 4 + offsets[index]);
        final plan = DailyPlan.forList(
          mainList: list,
          allLists: <ChoreList>[list],
          date: date,
        );
        expect(
          plan.assignments.first.person.name,
          expectedFirstPeople[mode]![index],
        );
        expect(plan.assignments.first.chores.single.title, 'Dishes');
      }
    }
  });
  test(
    'a scheduled add-on joins the main plan for its first rotating person',
    () {
      final main = fixture(id: 'upkeep');
      final projects = ChoreList(
        id: 'deep-clean',
        title: 'Deep cleaning',
        template: ChoreTemplate.month,
        monthDays: 31,
        people: const [ChorePerson(name: 'Project slot', id: 'project')],
        assignments: {
          16: [
            ['Scrub the shower'],
          ],
        },
        sendHour: 6,
        sendMinute: 0,
        createdAt: DateTime(2026, 3, 1),
        addToListId: main.id,
      );
      final plan = DailyPlan.forList(
        mainList: main,
        allLists: [main, projects],
        date: DateTime(2026, 3, 17),
      );
      expect(plan.assignments.first.person.name, 'Casey');
      expect(
        plan.assignments.first.chores.map((chore) => chore.title),
        contains('Scrub the shower'),
      );
      expect(
        plan.assignments
            .skip(1)
            .expand((assignment) => assignment.chores)
            .map((chore) => chore.title),
        isNot(contains('Scrub the shower')),
      );
      expect(plan.message, contains('Casey: Dishes, Scrub the shower'));
      expect(plan.message, contains('Extra project: Deep cleaning'));
    },
  );
  test('an add-on stays out of the plan on a different calendar day', () {
    final main = fixture(id: 'upkeep');
    final projects = ChoreList(
      id: 'deep-clean',
      title: 'Deep cleaning',
      template: ChoreTemplate.month,
      monthDays: 31,
      people: const [ChorePerson(name: 'Project', id: 'project')],
      assignments: {
        16: [
          ['Scrub the shower'],
        ],
      },
      sendHour: 6,
      sendMinute: 0,
      createdAt: DateTime(2026, 3, 1),
      addToListId: main.id,
    );
    final plan = DailyPlan.forList(
      mainList: main,
      allLists: [main, projects],
      date: DateTime(2026, 3, 16),
    );
    expect(plan.extraListTitles, isEmpty);
    expect(
      plan.assignments
          .expand((assignment) => assignment.chores)
          .map((chore) => chore.title),
      isNot(contains('Scrub the shower')),
    );
  });
  test(
    'completion identities separate same-name people and different dates',
    () {
      final list = fixture();
      final date = DateTime(2026, 3, 1);
      expect(
        list.completionKey(date, 0, 0),
        isNot(list.completionKey(date, 1, 0)),
      );
      expect(
        list.completionKey(date, 0, 0),
        isNot(list.completionKey(DateTime(2026, 3, 8), 0, 0)),
      );
      final json = list.toJson();
      final people = json['people'] as List;
      (people[0] as Map)['name'] = 'Renamed';
      expect(
        ChoreList.fromJson(json).completionKey(date, 0, 0),
        list.completionKey(date, 0, 0),
      );
    },
  );
  test(
    'native month payload always includes day 31 and a calendar-date anchor',
    () async {
      LocalCalendar.now = () => DateTime(2027, 2);
      await NativeBridge.scheduleReminder(
        fixture(template: ChoreTemplate.month),
      );
      expect((reminder!['messagesByRotation'] as List).first, hasLength(31));
      expect(reminder!['rotationAnchorDate'], '2026-03-01');
    },
  );

  test('opening the app preserves a pending daily reminder', () async {
    saved = jsonEncode([fixture().toJson()]);
    final store = ChoreStore();
    addTearDown(store.dispose);

    await store.load();

    expect(reminderCalls, ['ensureReminder']);
  });

  // /////Block Three/////////////////////////////////////////////////////////
  test(
    'failed saves and deletes leave the committed collection unchanged',
    () async {
      final store = ChoreStore();
      addTearDown(store.dispose);
      await store.load();
      failWrite = true;
      await expectLater(
        store.save(fixture()),
        throwsA(isA<PlatformException>()),
      );
      expect(store.lists, isEmpty);
      failWrite = false;
      await store.save(fixture());
      failWrite = true;
      await expectLater(
        store.remove('house'),
        throwsA(isA<PlatformException>()),
      );
      expect(store.lists, hasLength(1));
    },
  );
  test(
    'a malformed load never permits replacement writes; retry recovers',
    () async {
      saved = '[{"id":"existing","template":"week"}]';
      final original = saved;
      final store = ChoreStore();
      addTearDown(store.dispose);
      await store.load();
      expect(store.loadError, isNotNull);
      await expectLater(store.save(fixture()), throwsStateError);
      expect(saved, original);
      expect(writes, 0);
      saved = jsonEncode([fixture().toJson()]);
      await store.load();
      expect(store.writable, isTrue);
      expect(store.lists, hasLength(1));
    },
  );
  test('queued saves preserve both updates', () async {
    final store = ChoreStore();
    addTearDown(store.dispose);
    await store.load();
    await Future.wait([
      store.save(fixture(id: 'one')),
      store.save(fixture(id: 'two')),
    ]);
    expect(store.lists, hasLength(2));
    expect(jsonDecode(saved!) as List, hasLength(2));
  });

  // /////Block Four//////////////////////////////////////////////////////////
  testWidgets('draft survives normal/cosmic mode and tablet resizing', (
    tester,
  ) async {
    await tester.pumpWidget(const CosmicChoresApp());
    await tester.pump();
    await tester.tap(find.text('Make list'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Full week'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(find.text('Next: How many people?'), 200);
    await tester.tap(find.text('Next: How many people?'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Choose how to add them'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'Alex');
    await tester.tap(find.text('Cosmic Mode'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Create new'));
    await tester.pump();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Alex',
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Alex',
    );
    await tester.tap(find.text('Normal Mode'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('missions rotate and clear checkmarks at local midnight', (
    tester,
  ) async {
    var now = DateTime(2026, 3, 1, 23, 59, 59);
    LocalCalendar.now = () => now;
    saved = jsonEncode([fixture().toJson()]);
    final store = ChoreStore();
    await store.load();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CosmicMissionControlPage(store: store)),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    expect(
      tester
          .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
          .value,
      isTrue,
    );
    now = DateTime(2026, 3, 2);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    for (final checkbox in tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    )) {
      expect(checkbox.value, isFalse);
    }
    await tester.scrollUntilVisible(find.text('Prepare today’s message'), 200);
    await tester.tap(find.text('Prepare today’s message'));
    await tester.pump();
    expect(sharedBody, fixture().messageForDate(now));
    expect(sharedBody, contains('Casey: Dishes'));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('saved preview starts on today and shares the same rotation', (
    tester,
  ) async {
    LocalCalendar.now = () => DateTime(2026, 3, 8);
    final list = fixture();
    final store = ChoreStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SavedListDetailPage(list: list, store: store),
      ),
    );
    await tester.scrollUntilVisible(find.text('Prepare message'), 200);
    await tester.tap(find.text('Prepare message'));
    await tester.pump();
    expect(sharedBody, list.messageForDate(LocalCalendar.now()));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('weekly review shows effective people and scheduled projects', (
    tester,
  ) async {
    LocalCalendar.now = () => DateTime(2026, 3, 8);
    final main = fixture();
    final project = ChoreList(
      id: 'deep-clean',
      title: 'Deep clean',
      template: ChoreTemplate.month,
      monthDays: 31,
      people: const <ChorePerson>[
        ChorePerson(name: 'Project queue', id: 'project-queue'),
      ],
      assignments: <int, List<List<String>>>{
        7: <List<String>>[
          <String>['Clean oven'],
        ],
      },
      sendHour: 6,
      sendMinute: 0,
      createdAt: DateTime(2026, 3, 1),
      addToListId: main.id,
    );
    saved = jsonEncode(<Map<String, Object?>>[main.toJson(), project.toJson()]);
    final effectivePlan = DailyPlan.forList(
      mainList: main,
      allLists: <ChoreList>[main, project],
      date: DateTime(2026, 3, 8),
    );
    expect(
      effectivePlan.assignments
          .expand((assignment) => assignment.chores)
          .map((chore) => chore.title),
      contains('Clean oven'),
    );
    final store = ChoreStore();
    await store.load();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WeeklyReviewPage(store: store)),
      ),
    );
    await tester.pump();

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('House chores'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('empty states scroll at 2x text in a compact window', (
    tester,
  ) async {
    final store = ChoreStore();
    await store.load();
    addTearDown(store.dispose);
    for (final page in <Widget>[
      CosmicMissionControlPage(store: store),
      SavedListsPage(store: store),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 250),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: Center(
                child: SizedBox(width: 320, height: 250, child: page),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
