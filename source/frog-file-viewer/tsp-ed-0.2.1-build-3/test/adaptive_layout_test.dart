import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/main.dart';

void main() {
  Future<void> setWindow(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    await tester.pump();
  }

  testWidgets('compact phone actions stack vertically and remain scrollable', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await setWindow(tester, const Size(390, 760));
    await tester.pumpWidget(const FrogFileToolkit());
    final first = tester.getTopLeft(find.text('View a file'));
    final second = tester.getTopLeft(find.text('Open & edit PDF'));
    expect(second.dy, greaterThan(first.dy));
    expect((second.dx - first.dx).abs(), lessThan(15));

    await tester.dragUntilVisible(
      find.byKey(const Key('cosmic-mode-button')),
      find.byType(ListView),
      const Offset(0, -250),
    );
    await tester.ensureVisible(find.byKey(const Key('cosmic-mode-button')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet landscape shows two action columns', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await setWindow(tester, const Size(1280, 850));
    await tester.pumpWidget(const FrogFileToolkit());
    final first = tester.getTopLeft(find.text('View a file'));
    final second = tester.getTopLeft(find.text('Open & edit PDF'));
    expect((second.dy - first.dy).abs(), lessThan(8));
    expect(second.dx, greaterThan(first.dx + 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('resizing tablet to a narrow window reflows to one column', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await setWindow(tester, const Size(1280, 850));
    await tester.pumpWidget(const FrogFileToolkit());
    expect(
      (tester.getTopLeft(find.text('View a file')).dy -
              tester.getTopLeft(find.text('Open & edit PDF')).dy)
          .abs(),
      lessThan(8),
    );

    await setWindow(tester, const Size(560, 720));
    final first = tester.getTopLeft(find.text('View a file'));
    final second = tester.getTopLeft(find.text('Open & edit PDF'));
    expect(second.dy, greaterThan(first.dy + 30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('short landscape window can still reach the bottom actions', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await setWindow(tester, const Size(720, 380));
    await tester.pumpWidget(const FrogFileToolkit());
    await tester.dragUntilVisible(
      find.byKey(const Key('privacy-policy-button')),
      find.byType(ListView),
      const Offset(0, -230),
    );
    await tester.ensureVisible(find.byKey(const Key('privacy-policy-button')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('conversion sheets are scroll-safe on compact accessible screens', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(
      RegExp(r'showModalBottomSheet<String>\(').allMatches(source),
      hasLength(2),
    );
    expect(
      RegExp(r'isScrollControlled: true').allMatches(source),
      hasLength(2),
    );
    expect(
      RegExp(r'child: SingleChildScrollView\(').allMatches(source).length,
      greaterThanOrEqualTo(2),
    );
  });

  testWidgets('200 percent text keeps footer actions readable', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await setWindow(tester, const Size(390, 760));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    await tester.pumpWidget(const FrogFileToolkit());

    final privacy = find.byKey(const Key('privacy-policy-button'));
    await tester.dragUntilVisible(
      privacy,
      find.byType(ListView),
      const Offset(0, -500),
    );
    final privacySize = tester.getSize(privacy);
    final licensesSize = tester.getSize(
      find.byKey(const Key('open-source-licenses')),
    );
    expect(privacySize.width, greaterThan(150));
    expect(licensesSize.width, greaterThan(220));
    expect(privacySize.height, lessThan(140));
    expect(licensesSize.height, lessThan(140));
    expect(tester.takeException(), isNull);
  });
}
