/// Decides when a post has been on screen long enough to count as read, and
/// which chat the feed should be holding open.
///
/// Pure policy: it takes visibility reports and a clock, and answers questions.
/// No timers, no TDLib, no widgets — so the rules are testable, which matters
/// because getting them wrong writes read state to every Telegram client the
/// user owns.
///
///
/// * [readDwell] — how long a post must stay on screen before it counts as
///   read. Short enough to feel honest while scrolling, long enough that
///   flinging past a post doesn't mark it.
/// * [focusDwell] — how long a post must dominate the viewport before we open
///   its chat. Longer, because opening a chat is a request and TDLib expects
///   roughly one chat open at a time.
class FeedFocusTracker {
  /// Time on screen before a post is considered read.
  static const Duration readDwell = Duration(milliseconds: 500);

  /// Time dominating the viewport before a post's chat is opened.
  static const Duration focusDwell = Duration(milliseconds: 600);

  /// A post must be at least this visible to accumulate dwell at all.
  ///
  /// Full-width cards mean the topmost item is often a sliver clipped by the
  /// app bar; counting that as "seen" is what made the old implementation mark
  /// posts the user never actually looked at.
  static const double minVisibleFraction = 0.5;

  final Map<String, DateTime> _visibleSince = {};
  final Map<String, double> _fractions = {};
  final Set<String> _reported = {};

  String? _focusedPostId;
  DateTime? _dominantSince;
  String? _dominantCandidate;

  /// The post whose chat should currently be open, or null if none has settled.
  String? get focusedPostId => _focusedPostId;

  /// Posts currently accumulating dwell, for assertions and debugging.
  Iterable<String> get trackedPostIds => _visibleSince.keys;

  /// Records how much of a post is on screen.
  ///
  /// Dropping below [minVisibleFraction] resets that post's dwell — a post
  /// scrolled halfway off and back has not been continuously read.
  void onVisibilityChanged(String postId, double fraction, DateTime now) {
    _fractions[postId] = fraction;

    if (fraction >= minVisibleFraction) {
      _visibleSince.putIfAbsent(postId, () => now);
    } else {
      _visibleSince.remove(postId);
    }

    _updateDominant(now);
  }

  /// Forgets a post entirely, e.g. when its card leaves the tree.
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

  /// Promotes the dominant post to focused once it has held for [focusDwell].
  ///
  /// Returns true when the focused post changed, so the caller knows to swap
  /// `OpenChat`/`CloseChat`.
  bool settleFocus(DateTime now) {
    final candidate = _dominantCandidate;
    final since = _dominantSince;

    if (candidate == null || since == null) return false;
    if (now.difference(since) < focusDwell) return false;
    if (candidate == _focusedPostId) return false;

    _focusedPostId = candidate;
    return true;
  }

  /// Posts that have now been on screen long enough to count as read.
  ///
  /// Each post is only ever returned once — the caller does not have to
  /// de-duplicate before spending a request.
  List<String> takeNewlyRead(DateTime now) {
    final ready = <String>[];
    for (final entry in _visibleSince.entries) {
      if (_reported.contains(entry.key)) continue;
      if (now.difference(entry.value) >= readDwell) ready.add(entry.key);
    }
    _reported.addAll(ready);
    return ready;
  }

  /// Marks a post as already accounted for, so it is never reported again.
  ///
  /// Used to seed posts Telegram already considers read.
  void markAlreadyRead(String postId) => _reported.add(postId);

  /// True once [postId] has been reported as read by this tracker.
  bool hasReported(String postId) => _reported.contains(postId);

  /// Drops focus when nothing is on screen any more.
  ///
  /// Without this, navigating away from the feed leaves a chat open — TDLib
  /// expects roughly one open at a time, and a leaked one keeps streaming
  /// updates for a screen the user is no longer looking at.
  ///
  /// Returns true if focus was actually released.
  bool releaseFocusIfNothingVisible() {
    if (_dominantCandidate != null) return false;
    if (_focusedPostId == null) return false;
    _focusedPostId = null;
    return true;
  }

  /// Whether anything is still waiting on a dwell.
  ///
  /// Lets the caller stop its ticker once every visible post has been reported
  /// and focus has settled, instead of waking every frame for a static screen.
  bool get hasPendingWork {
    for (final id in _visibleSince.keys) {
      if (!_reported.contains(id)) return true;
    }
    // Covers both directions: a promotion waiting on its dwell, and a release
    // waiting to happen after everything scrolled away. Checking only for a
    // non-null candidate stopped the ticker before focus could be released,
    // leaking an open chat.
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
