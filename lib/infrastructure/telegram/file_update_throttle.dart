/// How often one file's download progress is allowed through to the UI.
///
/// TDLib emits `UpdateFile` continuously while bytes arrive — often many times
/// a second for a single download — and every one of them rebuilds whatever is
/// watching it. That cost is the reason the update stream used to be filtered
/// down to *completed* files only, which is in turn why a download in gramX
/// showed no progress at all: a snackbar saying "downloading…", then a finished
/// icon, and nothing in between.
///
/// A time gate per file is what makes real progress affordable. Pure, and its
/// own class rather than three fields on the service, because the interesting
/// part is a rule with two ways to be wrong — dropping a terminal event, or
/// letting a flood through — and neither needs a TDLib client to test.
class FileUpdateThrottle {
  /// The minimum gap between two progress updates for the same file.
  final Duration interval;

  /// Ceiling on how many files are tracked at once.
  ///
  /// An entry is dropped the moment its file completes, so this only ever
  /// holds downloads that stalled or were abandoned. Clearing wholesale is
  /// safe: the worst it costs is one un-throttled update per tracked file.
  final int trackingLimit;

  final Map<int, DateTime> _lastEmit = {};

  FileUpdateThrottle({
    this.interval = const Duration(milliseconds: 200),
    this.trackingLimit = 256,
  });

  /// How many files are currently being timed. Exposed for the bound above.
  int get trackedCount => _lastEmit.length;

  /// Whether this update should reach the UI.
  ///
  /// A completed download always passes and forgets the file: that is the
  /// event a listener *acts* on rather than draws, and dropping one would
  /// leave a progress ring spinning over a file that had already arrived.
  /// Everything else — including upload progress, which rides the same
  /// update — waits its turn.
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
