import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sean_johnston/models/spinner_model.dart';
import 'package:sean_johnston/screens/editor_page.dart';
import 'package:sean_johnston/screens/saved_page.dart';
import 'package:sean_johnston/services/app_controller.dart';
import 'package:sean_johnston/theme/app_theme.dart';

import 'storage_harness.dart';

void main() {
  setUp(mockStorage);

  test('categories persist and older saved spinners stay uncategorized', () {
    final original = spinnerTemplates.first.copyWith(category: 'Movies');
    expect(SpinnerModel.fromJson(original.toJson()).category, 'Movies');

    final olderJson = spinnerTemplates.first.toJson()..remove('category');
    expect(SpinnerModel.fromJson(olderJson).category, isEmpty);
  });

  testWidgets('saved spinners group into categories and filter a category', (
    tester,
  ) async {
    final controller = AppController();
    await controller.ready;
    await controller.saveSpinner(
      spinnerTemplates.first.copyWith(
        id: 'horror',
        title: 'Horror picker',
        isTemplate: false,
        category: 'Movies',
      ),
    );
    await controller.saveSpinner(
      spinnerTemplates.first.copyWith(
        id: 'rock',
        title: 'Rock picker',
        isTemplate: false,
        category: 'Music',
      ),
    );
    await controller.saveSpinner(
      spinnerTemplates.first.copyWith(
        id: 'misc',
        title: 'Anything picker',
        isTemplate: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SavedPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Movies'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Uncategorized'), findsOneWidget);

    await tester.tap(find.text('Movies'));
    await tester.pumpAndSettle();
    expect(find.text('Horror picker'), findsOneWidget);
    expect(find.text('Rock picker'), findsNothing);
    expect(find.text('Anything picker'), findsNothing);
    controller.dispose();
  });

  testWidgets('editor teaches new categories and offers existing ones', (
    tester,
  ) async {
    final controller = AppController();
    await controller.ready;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: EditorPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Where should this spinner live?'), findsOneWidget);
    expect(find.textContaining('New to categories?'), findsOneWidget);

    await controller.saveSpinner(
      spinnerTemplates.first.copyWith(
        id: 'movie-category',
        isTemplate: false,
        category: 'Movies',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: buildAppTheme(),
        home: EditorPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Choose an existing category'), findsOneWidget);
    await tester.tap(find.byKey(const Key('category-choice-movies')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('spinner-category-field')))
          .controller!
          .text,
      'Movies',
    );
    controller.dispose();
  });
}
