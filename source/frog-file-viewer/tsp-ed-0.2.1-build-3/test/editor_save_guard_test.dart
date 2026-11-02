import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/services/editor_save_guard.dart';

void main() {
  test('successful save without new edits may clear the dirty state', () {
    final guard = EditorSaveGuard()..openedDocument();
    guard.recordedEdit();
    final snapshot = guard.capture();
    expect(guard.isStillCurrent(snapshot), isTrue);
  });

  test('a new edit during save keeps the document dirty', () async {
    final guard = EditorSaveGuard()..openedDocument();
    guard.recordedEdit();
    final savingOldVersion = guard.capture();
    final picker = Completer<bool>();
    final completedSave = picker.future.then(
      (saved) => saved && guard.isStillCurrent(savingOldVersion),
    );

    // The picker is still open when the editor receives a newer revision.
    guard.recordedEdit();
    picker.complete(true);
    expect(await completedSave, isFalse);
  });

  test('save cancellation cannot mark unsaved changes clean', () async {
    final guard = EditorSaveGuard()..openedDocument();
    guard.recordedEdit();
    final saving = guard.capture();
    final picker = Completer<bool>();
    final completedSave = picker.future.then(
      (saved) => saved && guard.isStillCurrent(saving),
    );
    picker.complete(false);
    expect(await completedSave, isFalse);
  });

  test('save from a replaced document never clears a newer document', () {
    final guard = EditorSaveGuard()..openedDocument();
    guard.recordedEdit();
    final oldDocument = guard.capture();
    guard.openedDocument();
    expect(guard.isStillCurrent(oldDocument), isFalse);
    expect(guard.isStillCurrent(guard.capture()), isTrue);
  });

  test('out-of-order saves cannot clear revisions they did not capture', () {
    final guard = EditorSaveGuard()..openedDocument();
    guard.recordedEdit();
    final older = guard.capture();
    guard.recordedEdit();
    final newest = guard.capture();
    expect(guard.isStillCurrent(older), isFalse);
    expect(guard.isStillCurrent(newest), isTrue);
  });

  test('main editor wires edit revisions into asynchronous saves', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('final snapshot = _saveGuard.capture();'));
    expect(source, contains('_saveGuard.recordedEdit();'));
    expect(source, contains('_saveGuard.openedDocument();'));
    expect(source, contains('_saveGuard.isStillCurrent(snapshot)'));
    expect(source, contains('notifyOnSuccess: false,'));
  });
}
