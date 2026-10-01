/// Rate-limits each file's download progress updates, which TDLib can send
/// many times a second.
class FileUpdateThrottle {
  /// The minimum gap between two progress updates for the same file.
  final Duration interval;

  /// Cap on how many files are tracked. Completed files are removed, so this
  /// only fills with stalled downloads.
  final int trackingLimit;

  final Map<int, DateTime> _lastEmit = {};

  FileUpdateThrottle({
    this.interval = const Duration(milliseconds: 200),
    this.trackingLimit = 256,
  });

  /// How many files are currently tracked.
  int get trackedCount => _lastEmit.length;

  /// Whether this update should reach the UI. Completed downloads always
  /// pass; everything else, including upload progress, is throttled.
  bool allow({
    required int fileId,
    required bool isCompleted,
    required DateTime now,
  }) {
    if (isCompleted) {
      _lastEmit.remove(fileId);
      return true;
    }

    final last = _lastEmit[fileId];
    if (last != null && now.difference(last) < interval) return false;

    if (_lastEmit.length >= trackingLimit) _lastEmit.clear();
    _lastEmit[fileId] = now;
    return true;
  }

  void clear() => _lastEmit.clear();
}
