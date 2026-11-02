/// The native video position is authoritative whenever it advances. Some
/// Android MKV decoders report a static position while frames keep playing;
/// for those, use elapsed time ONLY while the controller confirms playback
/// and is not buffering. Never stop the player on speculative completion.
class VideoPlaybackClock {
  const VideoPlaybackClock._();

  static Duration displayPosition({
    required Duration native,
    required Duration fallbackAnchor,
    required Duration fallbackElapsed,
    required Duration duration,
    required bool playRequested,
    required bool actuallyPlaying,
    required bool buffering,
    required bool hasError,
  }) {
    final fallbackAllowed =
        playRequested && actuallyPlaying && !buffering && !hasError;
    final estimated =
        fallbackAllowed ? fallbackAnchor + fallbackElapsed : fallbackAnchor;
    var position = native > estimated ? native : estimated;
    if (position < Duration.zero) position = Duration.zero;
    if (duration > Duration.zero && position > duration) position = duration;
    return position;
  }

  /// Do not interpret an estimated wall-clock value as native completion:
  /// slow decoders and buffering can make the estimate exceed real progress.
  static bool actuallyCompleted({
    required bool nativeCompleted,
    required Duration native,
    required Duration duration,
  }) =>
      nativeCompleted ||
      (duration > Duration.zero && native >= duration);
}
