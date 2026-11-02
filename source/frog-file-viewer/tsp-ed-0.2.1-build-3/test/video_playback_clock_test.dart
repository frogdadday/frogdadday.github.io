import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/viewers/video_playback_clock.dart';

void main() {
  Duration estimate({
    bool playing = true,
    bool buffering = false,
    bool error = false,
    Duration native = const Duration(seconds: 1),
    Duration anchor = const Duration(seconds: 1),
    Duration elapsed = const Duration(seconds: 4),
  }) => VideoPlaybackClock.displayPosition(
    native: native,
    fallbackAnchor: anchor,
    fallbackElapsed: elapsed,
    duration: const Duration(seconds: 12),
    playRequested: playing,
    actuallyPlaying: playing,
    buffering: buffering,
    hasError: error,
  );

  test('Moto MKV stalled native position can still show advancing playback', () {
    expect(estimate(), const Duration(seconds: 5));
  });

  test('buffering, pause or codec failure stop speculative advancement', () {
    expect(estimate(buffering: true), const Duration(seconds: 1));
    expect(estimate(playing: false), const Duration(seconds: 1));
    expect(estimate(error: true), const Duration(seconds: 1));
  });

  test('real native time wins over a stale estimate, with duration clamp', () {
    expect(estimate(native: const Duration(seconds: 8)), const Duration(seconds: 8));
    expect(estimate(native: const Duration(seconds: 20)), const Duration(seconds: 12));
  });

  test('estimated completion never authorizes stopping native video', () {
    expect(
      VideoPlaybackClock.actuallyCompleted(
        nativeCompleted: false,
        native: const Duration(seconds: 1),
        duration: const Duration(seconds: 12),
      ),
      false,
    );
    expect(
      VideoPlaybackClock.actuallyCompleted(
        nativeCompleted: true,
        native: const Duration(seconds: 1),
        duration: const Duration(seconds: 12),
      ),
      true,
    );
  });
}
