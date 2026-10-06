import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:gramx/infrastructure/telegram/tdlib_library.dart';
import 'package:handy_tdlib/handy_tdlib.dart';

/// Runs TDLib's blocking receive and the JSON decode on a background isolate.
///
/// TDLib's client registry is process-global, so an isolate that opens the
/// library itself receives updates for the same client. `td_receive` must not
/// be called concurrently, so [TdlibService] polls only when [start] fails.
class TdlibReceiver {
  /// How long the native call waits before returning empty. Also the worst-case
  /// delay on shutdown, since the isolate is killed between receives.
  static const double receiveTimeoutSeconds = 1.0;

  /// How long to wait for the isolate to confirm it opened TDLib.
  static const Duration readyTimeout = Duration(seconds: 2);

  final void Function(Map<String, dynamic> payload) onPayload;

  Isolate? _isolate;
  ReceivePort? _port;
  StreamSubscription<dynamic>? _sub;

  TdlibReceiver({required this.onPayload});

  bool get isRunning => _isolate != null;

  /// Spawns the receiver. Returns false if the isolate could not start or open
  /// the TDLib library, in which case the caller polls on the main isolate.
  Future<bool> start() async {
    if (_isolate != null) return true;

    final port = ReceivePort();
    final ready = Completer<bool>();

    try {
      _isolate = await Isolate.spawn(
        _receiveLoop,
        port.sendPort,
        debugName: 'tdlib-receiver',
        errorsAreFatal: false,
      );
    } catch (e) {
      debugPrint('[TdlibReceiver] Could not spawn isolate: $e');
      port.close();
      return false;
    }

    _port = port;
    _sub = port.listen((message) {
      // The first message is a bool: whether the isolate opened the library.
      if (message is bool) {
        if (!ready.isCompleted) ready.complete(message);
        return;
      }
      if (message is Map<String, dynamic>) onPayload(message);
    });

    // Bootstrap awaits this before the first frame, so cap the wait.
    final started = await ready.future.timeout(
      readyTimeout,
      onTimeout: () => false,
    );

    if (!started) {
      debugPrint(
        '[TdlibReceiver] Isolate could not open TDLib — using polling',
      );
      await stop();
      return false;
    }

    debugPrint('[TdlibReceiver] Receiving on a background isolate');
    return true;
  }

  Future<void> stop() async {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    await _sub?.cancel();
    _sub = null;
    _port?.close();
    _port = null;
  }

  /// Isolate entry point. Opens its own handle to the library, then loops.
  static Future<void> _receiveLoop(SendPort sendPort) async {
    try {
      await openTdlib();
    } catch (e) {
      sendPort.send(false);
      return;
    }
    sendPort.send(true);

    while (true) {
      final String? raw = TdPlugin.instance.tdReceive(receiveTimeoutSeconds);
      if (raw == null || raw.isEmpty) continue;

      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) sendPort.send(decoded);
      } catch (_) {
        // Skip payloads that fail to parse.
      }
    }
  }
}
