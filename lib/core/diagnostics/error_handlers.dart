import 'package:flutter/foundation.dart';

import 'package:gramx/core/diagnostics/error_log.dart';

/// Where a caught error is sent once there is somewhere to send it.
typedef ErrorSink =
    void Function(Object error, StackTrace? stack, ErrorSource source);

/// The three places an error can escape a Flutter app, wired to one sink.
///
/// Without these, an exception thrown outside a `try` reached `debugPrint` and
/// stopped there — and `debugPrint` does nothing in a release build. So the
/// first release would have shipped with no way to learn why it failed for
/// anybody.
///
/// [install] runs before the app has a log to write to, because the errors
/// worth catching most are the ones during startup. Anything that arrives
/// before [connect] is held, and handed over when the log appears.
abstract class ErrorHandlers {
  /// How many errors are held while waiting for a sink.
  ///
  /// A fault during startup usually repeats, and a hundred copies of it would
  /// push out the first one — which is the one that says what happened.
  static const int bufferLimit = 20;

  static final List<_Buffered> _buffer = [];
  static ErrorSink? _sink;

  /// Whether anything has been installed yet. Installing twice would chain the
  /// handlers onto themselves.
  static bool _installed = false;

  /// Takes over Flutter's two global error handlers.
  ///
  /// Call before `runApp`, and before anything that might throw.
  static void install() {
    if (_installed) return;
    _installed = true;

    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      // Still print it. Losing the red screen and the console trace in debug
      // would trade a real diagnostic for a written one.
      (previous ?? FlutterError.presentError)(details);
      _emit(details.exception, details.stack, ErrorSource.widget);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _emit(error, stack, ErrorSource.platform);
      // True means handled: the app keeps running, and the log holds the
      // reason. Returning false here would take the process down.
      return true;
    };
  }

  /// Hands over the buffered errors and every one after.
  static void connect(ErrorSink sink) {
    _sink = sink;
    final held = List<_Buffered>.from(_buffer);
    _buffer.clear();
    for (final entry in held) {
      sink(entry.error, entry.stack, entry.source);
    }
  }

  /// The handler for `runZonedGuarded`.
  static void onZoneError(Object error, StackTrace stack) =>
      _emit(error, stack, ErrorSource.zone);

  /// Forgets the sink and anything held. For tests.
  @visibleForTesting
  static void reset() {
    _sink = null;
    _buffer.clear();
    _installed = false;
  }

  /// What is waiting for a sink. For tests.
  @visibleForTesting
  static int get bufferedCount => _buffer.length;

  static void _emit(Object error, StackTrace? stack, ErrorSource source) {
    final sink = _sink;
    if (sink != null) {
      sink(error, stack, source);
      return;
    }
    if (_buffer.length >= bufferLimit) return;
    _buffer.add(_Buffered(error, stack, source));
  }
}

class _Buffered {
  final Object error;
  final StackTrace? stack;
  final ErrorSource source;

  const _Buffered(this.error, this.stack, this.source);
}
