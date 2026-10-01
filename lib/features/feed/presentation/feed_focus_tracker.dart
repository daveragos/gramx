/// Decides when a post has been on screen long enough to count as read, and
/// which chat the feed should hold open. Pure policy, so it can be tested.
///
/// [focusDwell] is longer than [readDwell], since opening a chat is a
/// request and TDLib expects about one open at a time.
class FeedFocusTracker {
  static const Duration readDwell = Duration(milliseconds: 500);

  static const Duration focusDwell = Duration(milliseconds: 600);

  /// A post must be at least this visible to accumulate dwell, so a sliver
  /// clipped by the app bar doesn't count.
  static const double minVisibleFraction = 0.5;

  final Map<String, DateTime> _visibleSince = {};
  final Map<String, double> _fractions = {};
  final Set<String> _reported = {};

  String? _focusedPostId;
  DateTime? _dominantSince;
  String? _dominantCandidate;

  /// The post whose chat should be open, or null if none has settled.
  String? get focusedPostId => _focusedPostId;

  Iterable<String> get trackedPostIds => _visibleSince.keys;

  /// Records how much of a post is on screen. Dropping below
  /// [minVisibleFraction] resets that post's dwell.
  void onVisibilityChanged(String postId, double fraction, DateTime now) {
    _fractions[postId] = fraction;

    if (fraction >= minVisibleFraction) {
      _visibleSince.putIfAbsent(postId, () => now);
    } else {
      _visibleSince.remove(postId);
    }

    _updateDominant(now);
  }

  /// Forgets a post whose card left the tree.
  void onDisposed(String postId) {
    _visibleSince.remove(postId);
    _fractions.remove(postId);
  }

  void _updateDominant(DateTime now) {
    String? best;
    var bestFraction = 0.0;
    for (final entry in _fractions.entries) {
      if (entry.value > bestFraction) {
        bestFraction = entry.value;
        best = entry.key;
      }
    }

    if (bestFraction < minVisibleFraction) best = null;

    if (best != _dominantCandidate) {
      _dominantCandidate = best;
      _dominantSince = best == null ? null : now;
    }
  }

  /// Promotes the dominant post to focused after [focusDwell]. Returns true
  /// when the focused post changed.
  bool settleFocus(DateTime now) {
    final candidate = _dominantCandidate;
    final since = _dominantSince;

    if (candidate == null || since == null) return false;
    if (now.difference(since) < focusDwell) return false;
    if (candidate == _focusedPostId) return false;

    _focusedPostId = candidate;
    return true;
  }

  /// Posts on screen long enough to count as read, each returned once.
  List<String> takeNewlyRead(DateTime now) {
    final ready = <String>[];
    for (final entry in _visibleSince.entries) {
      if (_reported.contains(entry.key)) continue;
      if (now.difference(entry.value) >= readDwell) ready.add(entry.key);
    }
    _reported.addAll(ready);
    return ready;
  }

  /// Marks a post as already read, so it is never reported.
  void markAlreadyRead(String postId) => _reported.add(postId);

  bool hasReported(String postId) => _reported.contains(postId);

  /// Drops focus when nothing is on screen, so a chat isn't left open.
  /// Returns true if focus was released.
  bool releaseFocusIfNothingVisible() {
    if (_dominantCandidate != null) return false;
    if (_focusedPostId == null) return false;
    _focusedPostId = null;
    return true;
  }

  /// Whether anything is waiting on a dwell, so the ticker can stop.
  bool get hasPendingWork {
    for (final id in _visibleSince.keys) {
      if (!_reported.contains(id)) return true;
    }
    // Covers both a pending promotion and a pending release.
    return _dominantCandidate != _focusedPostId;
  }

  void clear() {
    _visibleSince.clear();
    _fractions.clear();
    _reported.clear();
    _focusedPostId = null;
    _dominantSince = null;
    _dominantCandidate = null;
  }
}
