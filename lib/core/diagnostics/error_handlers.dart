import 'package:flutter/foundation.dart';

import 'package:gramx/core/diagnostics/error_log.dart';

/// Where a caught error is sent once there is somewhere to send it.
typedef ErrorSink =
    void Function(Object error, StackTrace? stack, ErrorSource source);

/// Routes uncaught errors from Flutter, the platform dispatcher and the root
/// zone to one sink. Errors before [connect] are buffered.
abstract class ErrorHandlers {
  /// How many errors are buffered; later ones are dropped.
  static const int bufferLimit = 20;

  static final List<_Buffered> _buffer = [];
  static ErrorSink? _sink;

  /// Guards against installing twice, which would chain the handlers.
  static bool _installed = false;

  /// Takes over Flutter's two global error handlers. Call before `runApp`.
  static void install() {
    if (_installed) return;
    _installed = true;

    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      // Keep the default red screen and console trace.
      (previous ?? FlutterError.presentError)(details);
      _emit(details.exception, details.stack, ErrorSource.widget);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _emit(error, stack, ErrorSource.platform);
      // Handled, so the process keeps running.
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
