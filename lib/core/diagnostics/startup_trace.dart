import 'package:flutter/foundation.dart';

/// Where a cold start spends its time.
///
/// One line in the debug log per milestone, stamped with the milliseconds
/// since the Dart side came up, so "the app takes too long to load" can be
/// answered with a number for each stage rather than a guess about which one.
/// Each milestone is recorded once — the feed rebuilds itself several times
/// on the way up, and only the first time it has posts is a startup fact.
///
/// Nothing in release: it is for reading a `flutter run` log or `adb logcat`,
/// not for the reader.
abstract final class StartupTrace {
  static final Stopwatch _clock = Stopwatch()..start();
  static final Set<String> _seen = {};

  /// Records that [milestone] has been reached, the first time it is.
  static void mark(String milestone) {
    if (kReleaseMode) return;
    if (!_seen.add(milestone)) return;
    debugPrint('[Startup] +${_clock.elapsedMilliseconds} ms  $milestone');
  }
}
