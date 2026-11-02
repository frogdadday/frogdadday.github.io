import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/services/draft_recovery_store.dart';
import 'package:frog_file_viewer/services/file_tools.dart';

void main() {
  test('recovery draft restores locally and is deleted on request', () async {
    final root = await Directory.systemTemp.createTemp('frog-recovery-test-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final store = DraftRecoveryStore.withRoot(root);
    final bytes = await FileTools.blankPdf();

    await store.save(bytes, 'important.pdf');
    final draft = await store.load();
    expect(draft, isNotNull);
    expect(draft!.documentName, 'important.pdf');
    expect(FileTools.looksLikePdf(draft.bytes), isTrue);

    await store.delete();
    expect(await store.load(), isNull);
  });

  test('cleans partial .tmp writes and preserves an earlier recovery', () async {
    final root = await Directory.systemTemp.createTemp('frog-recovery-fail-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final ids = ['original', 'replacement'].iterator;
    final store = DraftRecoveryStore.withRoot(
      root,
      idFactory: () {
        ids.moveNext();
        return ids.current;
      },
    );
    final bytes = await FileTools.blankPdf();
    await store.save(bytes, 'original.pdf');
    final recoveryDir = Directory(
      '${root.path}${Platform.pathSeparator}frog_pdf_recovery',
    );
    final pdfTemp = File(
      '${recoveryDir.path}${Platform.pathSeparator}draft-replacement.pdf.tmp',
    );
    final metadataTemp = Directory(
      '${recoveryDir.path}${Platform.pathSeparator}draft-replacement.json.tmp',
    );

    // A directory in place of the second temporary file simulates an
    // interrupted/unwritable metadata write after draft.pdf.tmp was written.
    await metadataTemp.create();
    await expectLater(
      store.save(bytes, 'replacement.pdf'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await pdfTemp.exists(), isFalse);
    await metadataTemp.delete();
    final recovered = await store.load();
    expect(recovered?.documentName, 'original.pdf');
    expect(recovered?.bytes, orderedEquals(bytes));
  });

  test('corrupt newer PDF checkpoint cannot replace a valid older one', () async {
    final root = await Directory.systemTemp.createTemp(
      'frog-recovery-corrupt-',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final store = DraftRecoveryStore.withRoot(root);
    final valid = await FileTools.blankPdf();
    await store.save(valid, 'last-valid.pdf');
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}frog_pdf_recovery',
    );
    final damagedPdf = File('${directory.path}/draft-broken.pdf');
    final damagedMetadata = File('${directory.path}/draft-broken.json');
    // This used to be accepted because it had a %PDF signature, which
    // could erase the previous recoverable session during cleanup.
    await damagedPdf.writeAsBytes(
      '%PDF-1.7\\nmissing page tree and xref'.codeUnits,
    );
    await damagedMetadata.writeAsString(
      jsonEncode({
        'documentName': 'broken-newer.pdf',
        'savedAt': DateTime.now()
            .toUtc()
            .add(const Duration(seconds: 2))
            .toIso8601String(),
      }),
    );

    final restored = await store.load();
    expect(restored?.documentName, 'last-valid.pdf');
    expect(restored?.bytes, orderedEquals(valid));
    expect(await damagedPdf.exists(), isFalse);
    expect(await damagedMetadata.exists(), isFalse);
  });

  test('recovery drafts expire instead of retaining files indefinitely', () async {
    final root = await Directory.systemTemp.createTemp('frog-recovery-expiry-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final store = DraftRecoveryStore.withRoot(root, idFactory: () => 'old');
    await store.save(await FileTools.blankPdf(), 'old.pdf');
    final metadata = File(
      '${root.path}${Platform.pathSeparator}frog_pdf_recovery${Platform.pathSeparator}draft-old.json',
    );
    await metadata.writeAsString(
      jsonEncode({
        'documentName': 'old.pdf',
        'savedAt': DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 2))
            .toIso8601String(),
      }),
    );

    expect(await store.load(), isNull);
    expect(await metadata.exists(), isFalse);
  });

  test('failed final rename preserves the previous committed pair', () async {
    final root = await Directory.systemTemp.createTemp('frog-recovery-rename-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final ids = ['original', 'replacement'].iterator;
    final store = DraftRecoveryStore.withRoot(
      root,
      idFactory: () {
        ids.moveNext();
        return ids.current;
      },
    );
    final bytes = await FileTools.blankPdf();
    await store.save(bytes, 'original.pdf');
    final recoveryDir = Directory(
      '${root.path}${Platform.pathSeparator}frog_pdf_recovery',
    );
    final blockedFinal = Directory(
      '${recoveryDir.path}${Platform.pathSeparator}draft-replacement.json',
    );
    await blockedFinal.create();

    await expectLater(
      store.save(bytes, 'replacement.pdf'),
      throwsA(isA<FileSystemException>()),
    );
    final recovered = await store.load();
    expect(recovered?.documentName, 'original.pdf');
  });

  test('restart ignores partial files and restores the last valid pair', () async {
    final root = await Directory.systemTemp.createTemp(
      'frog-recovery-restart-',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final bytes = await FileTools.blankPdf();
    await DraftRecoveryStore.withRoot(
      root,
      idFactory: () => 'committed',
    ).save(bytes, 'committed.pdf');
    final recoveryDir = Directory(
      '${root.path}${Platform.pathSeparator}frog_pdf_recovery',
    );
    await File(
      '${recoveryDir.path}${Platform.pathSeparator}draft-interrupted.pdf',
    ).writeAsBytes(bytes);
    await File(
      '${recoveryDir.path}${Platform.pathSeparator}draft-interrupted.json.tmp',
    ).writeAsString('{');

    final restarted = DraftRecoveryStore.withRoot(root);
    final recovered = await restarted.load();
    expect(recovered?.documentName, 'committed.pdf');
    expect(
      await File(
        '${recoveryDir.path}${Platform.pathSeparator}draft-interrupted.pdf',
      ).exists(),
      isFalse,
    );
  });

  test(
    'overlapping saves serialize and retain the newest checkpoint',
    () async {
      final root = await Directory.systemTemp.createTemp('frog-recovery-race-');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final ids = ['first', 'second'].iterator;
      var tick = 0;
      final base = DateTime.utc(2026, 10, 23, 12);
      final store = DraftRecoveryStore.withRoot(
        root,
        idFactory: () {
          ids.moveNext();
          return ids.current;
        },
        now: () => base.add(Duration(seconds: tick++)),
      );
      final bytes = await FileTools.blankPdf();

      await Future.wait([
        store.save(bytes, 'first.pdf'),
        store.save(bytes, 'second.pdf'),
      ]);

      final recovered = await store.load();
      expect(recovered?.documentName, 'second.pdf');
    },
  );
}
