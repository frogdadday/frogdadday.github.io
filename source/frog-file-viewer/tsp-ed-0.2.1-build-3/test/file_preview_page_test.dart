import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/viewers/file_preview_page.dart';

base class _MemoryPlatformFile extends PlatformFile {
  _MemoryPlatformFile({
    required this.name,
    required this.stream,
    this.reportedLength,
  });

  @override
  final String name;
  final Stream<Uint8List> Function() stream;
  final int? reportedLength;

  @override
  Uri get uri => Uri(scheme: 'content', path: name);

  @override
  XFile get xFile => XFile.fromData(Uint8List(0), name: name);

  @override
  int? lengthSync() => reportedLength;

  @override
  Future<int?> length() async => reportedLength;

  @override
  Future<Uint8List> readAsBytes() async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream()) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  @override
  Stream<Uint8List> readAsByteStream() => stream();
}

base class _LocalPlatformFile extends PlatformFile {
  _LocalPlatformFile(this.file);

  final File file;

  @override
  String get name => file.uri.pathSegments.last;

  @override
  Uri get uri => file.uri;

  @override
  XFile get xFile => XFile(file.path);

  @override
  int? lengthSync() => file.lengthSync();

  @override
  Future<int?> length() => file.length();

  @override
  Future<Uint8List> readAsBytes() => file.readAsBytes();

  @override
  Stream<Uint8List> readAsByteStream() =>
      file.openRead().map(Uint8List.fromList);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _MemoryPlatformFile bytesFile(String name, List<int> bytes) {
    final data = Uint8List.fromList(bytes);
    return _MemoryPlatformFile(
      name: name,
      reportedLength: data.length,
      stream: () => Stream<Uint8List>.value(data),
    );
  }

  testWidgets('loads and disposes a read-only text preview', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FilePreviewPage(
          file: bytesFile('notes.txt', utf8.encode('frog pond')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('frog pond'), findsOneWidget);
    expect(find.textContaining('Original unchanged'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows clear errors for empty, invalid, and oversized files', (
    tester,
  ) async {
    final empty = _MemoryPlatformFile(
      name: 'empty.txt',
      reportedLength: 0,
      stream: () => const Stream<Uint8List>.empty(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FilePreviewPage(key: UniqueKey(), file: empty),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This file is empty.'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: FilePreviewPage(
          key: UniqueKey(),
          file: bytesFile('broken.pdf', utf8.encode('not a pdf')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('The selected file is not a valid PDF.'), findsOneWidget);

    var listened = false;
    final oversized = _MemoryPlatformFile(
      name: 'huge.txt',
      reportedLength: 3 * 1024 * 1024,
      stream: () => Stream<Uint8List>.multi((controller) {
        listened = true;
        controller.close();
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FilePreviewPage(key: UniqueKey(), file: oversized),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Preview limited to 2 MB'), findsOneWidget);
    expect(listened, isFalse);
  });

  testWidgets('back navigation cancels a provider media copy', (tester) async {
    // Keep each stage explicit: this regression previously hung while a
    // provider stream was still awaiting its next chunk.
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('frog-preview-back-'),
    ))!;
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final file = _MemoryPlatformFile(
      name: 'waiting.mp4',
      reportedLength: 400,
      stream: () => Stream<Uint8List>.periodic(
        const Duration(milliseconds: 100),
        (_) => Uint8List.fromList([1, 2, 3, 4]),
      ).take(100),
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home')),
      ),
    );
    unawaited(
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => FilePreviewPage(
            file: file,
            temporaryDirectory: () async => root,
            availableTempBytes: () async => 1024 * 1024 * 1024,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('home'), findsOneWidget);
    expect(
      root.listSync().whereType<File>().where(
        (file) => file.path.contains('frog_preview_'),
      ),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 8)));

  testWidgets('short landscape and large text keep preview reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.4;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: FilePreviewPage(
          file: bytesFile(
            'long-accessible-name.txt',
            utf8.encode('one\ntwo\nthree'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('one\ntwo\nthree'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsupported codec initialization reports a device error', (
    tester,
  ) async {
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('frog-codec-error-'),
    ))!;
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final video = File('${root.path}${Platform.pathSeparator}broken.mp4');
    await tester.runAsync(() => video.writeAsBytes([0, 1, 2, 3]));

    await tester.pumpWidget(
      MaterialApp(
        home: FilePreviewPage(
          file: _LocalPlatformFile(video),
          videoControllerLoader: (_) async {
            throw PlatformException(code: 'unsupported-codec');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('could not be opened on this device'),
      findsOneWidget,
    );
  });

  testWidgets('AVI is rejected clearly without changing the original', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FilePreviewPage(file: bytesFile('legacy.avi', [1, 2, 3])),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('AVI preview is not supported'), findsOneWidget);
    expect(find.textContaining('Original unchanged'), findsOneWidget);
  });

  testWidgets('preview can be opened and closed repeatedly', (tester) async {
    for (var iteration = 0; iteration < 3; iteration++) {
      await tester.pumpWidget(
        MaterialApp(
          home: FilePreviewPage(
            file: bytesFile('repeat.txt', utf8.encode('repeat $iteration')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('repeat $iteration'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
