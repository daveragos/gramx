import 'package:flutter/foundation.dart';

/// Logs cold start milestones with milliseconds since the Dart side started.
/// Each milestone is logged once. Disabled in release builds.
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
