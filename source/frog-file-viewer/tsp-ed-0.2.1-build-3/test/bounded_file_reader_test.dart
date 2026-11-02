import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/services/bounded_file_reader.dart';

void main() {
  test('unknown content-provider size still streams successfully', () async {
    final bytes = await BoundedFileReader.readStream(
      Stream<List<int>>.fromIterable([
        utf8.encode('frog'),
        utf8.encode('pond'),
      ]),
      reportedLength: null,
      maxBytes: 10,
      limitMessage: 'Too large',
    );
    expect(utf8.decode(bytes), 'frogpond');
  });

  test('unknown length cannot bypass streamed byte limit', () async {
    await expectLater(
      BoundedFileReader.readStream(
        Stream<List<int>>.fromIterable([
          [1, 2, 3],
          [4, 5, 6],
        ]),
        reportedLength: null,
        maxBytes: 5,
        limitMessage: 'Too large',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('incorrectly small provider metadata does not bypass limit', () async {
    await expectLater(
      BoundedFileReader.readStream(
        Stream<List<int>>.value([1, 2, 3, 4]),
        reportedLength: 1,
        maxBytes: 3,
        limitMessage: 'Too large',
      ),
      throwsFormatException,
    );
  });

  test('oversized reported metadata aborts before streaming', () async {
    var listened = false;
    final data = Stream<List<int>>.multi((controller) {
      listened = true;
      controller.add([1]);
      controller.close();
    });
    await expectLater(
      BoundedFileReader.readStream(
        data,
        reportedLength: 99,
        maxBytes: 3,
        limitMessage: 'Too large',
      ),
      throwsFormatException,
    );
    expect(listened, isFalse);
  });

  test('empty picked stream is rejected', () async {
    await expectLater(
      BoundedFileReader.readStream(
        const Stream<List<int>>.empty(),
        reportedLength: null,
        maxBytes: 100,
        limitMessage: 'Too large',
      ),
      throwsFormatException,
    );
  });
}
