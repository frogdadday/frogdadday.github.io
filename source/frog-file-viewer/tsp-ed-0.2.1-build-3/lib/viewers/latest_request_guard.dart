/// Issues monotonically increasing tokens so stale async completions cannot
/// overwrite the result of a newer user request.
class LatestRequestGuard {
  int _latest = 0;

  int begin() => ++_latest;

  bool isLatest(int token) => token == _latest;

  void invalidate() {
    _latest++;
  }
}
