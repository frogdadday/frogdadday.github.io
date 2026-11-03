import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sean_johnston/services/app_controller.dart';
import 'package:sean_johnston/models/spinner_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cosmic_spinner/storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  SpinnerModel wheel(String id) => SpinnerModel(
    id: id,
    title: id,
    slices: ['A', 'B'],
    colorValue: 0xFFFFDC45,
  );
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'mutation waits for delayed startup and preserves existing wheels',
    () async {
      final read = Completer<String?>();
      String? written;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'read') return read.future;
        written = call.arguments as String;
        return null;
      });
      final c = AppController();
      final change = c.toggleSound();
      expect(written, isNull);
      read.complete(
        jsonEncode({
          'saved': [wheel('original').toJson()],
        }),
      );
      expect(await change, isTrue);
      expect((jsonDecode(written!)['saved'] as List).single['id'], 'original');
      c.dispose();
    },
  );

  test('failed load prevents writes and can be retried', () async {
    bool fail = true;
    int writes = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'read') {
        if (fail) throw PlatformException(code: 'READ');
        return null;
      }
      writes++;
      return null;
    });
    final c = AppController();
    await c.ready;
    expect(c.loadError, isNotNull);
    expect(await c.toggleSound(), isFalse);
    expect(writes, 0);
    fail = false;
    await c.retryLoad();
    expect(c.loaded, isTrue);
    c.dispose();
  });

  test('failed save is visible and retry persists retained state', () async {
    bool fail = true;
    String? raw;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'read') return '{"localSavingAllowed":true}';
      if (fail) throw PlatformException(code: 'WRITE');
      raw = call.arguments as String;
      return null;
    });
    final c = AppController();
    await c.ready;
    expect(await c.saveSpinner(wheel('new')), isFalse);
    expect(c.saveError, isNotNull);
    expect(c.saved.single.id, 'new');
    fail = false;
    expect(await c.retrySave(), isTrue);
    expect(c.saveError, isNull);
    expect(jsonDecode(raw!)['saved'], hasLength(1));
    c.dispose();
  });

  test(
    'malformed records are preserved while later valid records load',
    () async {
      final broken = {'id': 'broken', 'slices': []};
      String? raw = jsonEncode({
        'saved': [broken, wheel('good').toJson()],
        'draft': broken,
      });
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'read') return raw;
        raw = call.arguments as String;
        return null;
      });
      final c = AppController();
      await c.ready;
      expect(c.saved.single.id, 'good');
      expect(c.recoveryWarning, isNotNull);
      await c.toggleSound();
      expect((jsonDecode(raw!)['saved'] as List).last, equals(broken));
      expect(jsonDecode(raw!)['unreadableDraft'], broken);
      c.dispose();
    },
  );

  test('undo preserves unrelated draft and writes stay ordered', () async {
    final gate = Completer<void>();
    final writes = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'read') return '{"localSavingAllowed":true}';
      writes.add(call.arguments as String);
      if (writes.length == 1) await gate.future;
      return null;
    });
    final c = AppController();
    await c.ready;
    final draft = c.saveDraft(wheel('draft'));
    final restore = c.restoreSpinner(wheel('restored'));
    await Future<void>.delayed(Duration.zero);
    expect(writes, hasLength(1));
    gate.complete();
    await Future.wait([draft, restore]);
    expect(c.draft!.id, 'draft');
    expect(jsonDecode(writes.last)['draft']['id'], 'draft');
    expect(jsonDecode(writes.last)['saved'], hasLength(1));
    c.dispose();
  });

  test(
    'invalid root remains protected and models own immutable slices',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async => 'not json');
      final c = AppController();
      await c.ready;
      expect(c.loaded, isFalse);
      final slices = ['A', 'B'];
      final model = SpinnerModel(
        id: 'x',
        title: '',
        slices: slices,
        colorValue: 1,
      );
      slices.clear();
      expect(model.slices, hasLength(2));
      expect(() => model.slices.add('C'), throwsUnsupportedError);
      expect(
        () => SpinnerModel(id: 'x', title: '', slices: [], colorValue: 1),
        throwsFormatException,
      );
      c.dispose();
    },
  );
}
