import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/services/temporary_media_copy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('failed provider stream removes its partial copy', () async {
    final root = await Directory.systemTemp.createTemp('frog-media-fail-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final partial = File(
      '${root.path}${Platform.pathSeparator}frog_preview_test.mp3.partial',
    );
    final completed = File(
      '${root.path}${Platform.pathSeparator}frog_preview_test.mp3',
    );

    Stream<List<int>> failing() async* {
      yield [1, 2, 3];
      throw StateError('provider disconnected');
    }

    await expectLater(
      TemporaryMediaCopy().copy(
        chunks: failing(),
        partialFile: partial,
        completedFile: completed,
        maxBytes: 1024,
      ),
      throwsStateError,
    );
    expect(await partial.exists(), isFalse);
    expect(await completed.exists(), isFalse);
  });

  test('cancelling an in-flight provider copy removes partial data', () async {
    final root = await Directory.systemTemp.createTemp('frog-media-cancel-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final partial = File(
      '${root.path}${Platform.pathSeparator}frog_preview_test.mkv.partial',
    );
    final completed = File(
      '${root.path}${Platform.pathSeparator}frog_preview_test.mkv',
    );
    final source = StreamController<List<int>>();
    final copy = TemporaryMediaCopy();
    final future = copy.copy(
      chunks: source.stream,
      partialFile: partial,
      completedFile: completed,
      maxBytes: 1024,
    );
    // Register the error expectation before cancellation. Otherwise the copy
    // can report its expected cancellation error before expectLater is
    // attached, which the test runner correctly treats as an unhandled error.
    final cancellation = expectLater(
      future,
      throwsA(isA<PreviewCopyCancelled>()),
    );
    source.add([1, 2, 3, 4]);
    await Future<void>.delayed(Duration.zero);

    await copy.cancel();
    await source.close();
    await cancellation;
    expect(await partial.exists(), isFalse);
    expect(await completed.exists(), isFalse);
  });

  test('unknown-size provider is bounded while streaming', () async {
    final root = await Directory.systemTemp.createTemp('frog-media-bound-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final partial = File(
      '${root.path}${Platform.pathSeparator}frog_preview_bound.mp4.partial',
    );
    final completed = File(
      '${root.path}${Platform.pathSeparator}frog_preview_bound.mp4',
    );
    var emitted = 0;
    Stream<List<int>> oversized() async* {
      while (emitted < 20) {
        emitted++;
        yield List<int>.filled(128, emitted);
      }
    }

    await expectLater(
      TemporaryMediaCopy().copy(
        chunks: oversized(),
        partialFile: partial,
        completedFile: completed,
        maxBytes: 512,
      ),
      throwsFormatException,
    );
    expect(emitted, 5, reason: 'copy must stop reading at the first overflow');
    expect(await partial.exists(), isFalse);
    expect(await completed.exists(), isFalse);
  });

  test(
    'rename failure removes partial data without replacing destination',
    () async {
      final root = await Directory.systemTemp.createTemp('frog-media-rename-');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final partial = File(
        '${root.path}${Platform.pathSeparator}frog_preview_rename.mp3.partial',
      );
      final completedDirectory = Directory(
        '${root.path}${Platform.pathSeparator}frog_preview_rename.mp3',
      );
      await completedDirectory.create();

      await expectLater(
        TemporaryMediaCopy().copy(
          chunks: Stream<List<int>>.value([1, 2, 3]),
          partialFile: partial,
          completedFile: File(completedDirectory.path),
          maxBytes: 512,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await partial.exists(), isFalse);
      expect(await completedDirectory.exists(), isTrue);
    },
  );

  test(
    'restart cleanup removes partial and stale completed previews',
    () async {
      final root = await Directory.systemTemp.createTemp('frog-media-clean-');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final partial = File(
        '${root.path}${Platform.pathSeparator}frog_preview_a.mp4.partial',
      );
      final stale = File(
        '${root.path}${Platform.pathSeparator}frog_preview_b.mp4',
      );
      final unrelated = File('${root.path}${Platform.pathSeparator}keep.txt');
      await partial.writeAsBytes([1]);
      await stale.writeAsBytes([2]);
      await stale.setLastModified(
        DateTime.now().subtract(const Duration(days: 2)),
      );
      await unrelated.writeAsBytes([3]);

      await TemporaryMediaCopy.cleanupAfterRestart(root);

      expect(await partial.exists(), isFalse);
      expect(await stale.exists(), isFalse);
      expect(await unrelated.exists(), isTrue);
    },
  );

  test(
    'temporary storage probe accepts Android available-byte result',
    () async {
      const channel = MethodChannel('frog_file_viewer/storage');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'availableTempBytes');
            return 123456;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      expect(await TemporaryStorageProbe.availableBytes(), 123456);
    },
  );
}
