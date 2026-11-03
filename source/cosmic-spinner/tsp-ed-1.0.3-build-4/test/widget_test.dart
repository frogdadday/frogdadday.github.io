import 'storage_harness.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sean_johnston/main.dart';

void main() {
  setUp(mockStorage);
  testWidgets('home offers all three spinner paths', (tester) async {
    await tester.pumpWidget(const SeanJohnstonApp());
    await tester.pumpAndSettle();

    expect(find.text('Template Spinners'), findsOneWidget);
    expect(find.text('Saved Spinners'), findsOneWidget);
    expect(find.text('Create Your Own'), findsOneWidget);
    expect(find.byKey(const Key('sound-toggle')), findsOneWidget);
    expect(find.byKey(const Key('cosmic-toggle')), findsOneWidget);
    expect(find.text('Support'), findsOneWidget);
  });
}
