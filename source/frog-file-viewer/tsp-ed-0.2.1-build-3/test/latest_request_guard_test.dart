import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/viewers/latest_request_guard.dart';

void main() {
  test('out-of-order seek completion cannot apply an older position', () async {
    final guard = LatestRequestGuard();
    final first = Completer<void>();
    final second = Completer<void>();
    var applied = Duration.zero;

    Future<void> seek(
      int token,
      Duration position,
      Completer<void> completion,
    ) async {
      await completion.future;
      if (guard.isLatest(token)) applied = position;
    }

    final firstToken = guard.begin();
    final firstSeek = seek(firstToken, const Duration(seconds: 5), first);
    final secondToken = guard.begin();
    final secondSeek = seek(secondToken, const Duration(seconds: 20), second);

    second.complete();
    await secondSeek;
    first.complete();
    await firstSeek;

    expect(applied, const Duration(seconds: 20));
  });
}
