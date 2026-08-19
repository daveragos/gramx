import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/handy_tdlib.dart';

/// Runs TDLib's blocking receive on a background isolate.
///
/// `handy_tdlib` is pure FFI over `libtdjson.so`, and TDLib's client registry
/// is process-global — so an isolate that opens the library itself receives
/// updates for the same client id. The package author endorses this directly
/// ("Pro tip: run tdReceive in Isolate in order to not block UI").
///
/// Two things move off the UI thread: the blocking native wait, and the JSON
/// parse, which was the expensive half. The isolate sends back decoded maps.
///
/// **`td_receive` must not be called concurrently for one client**, so once
/// this is running the main isolate must stop polling entirely. [TdlibService]
/// only starts its timer when [start] reports failure.
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

  /// Spawns the receiver.
  ///
  /// Returns false if the isolate could not be started or could not open the
  /// TDLib library — on a platform that links it statically, for instance.
  /// The caller falls back to polling on the main isolate, so a failure here
  /// degrades to the previous behaviour rather than a dead client.
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
      // The isolate reports its own readiness first: it can only know whether
      // DynamicLibrary.open succeeded once it is running.
      if (message is bool) {
        if (!ready.isCompleted) ready.complete(message);
        return;
      }
      if (message is Map<String, dynamic>) onPayload(message);
    });

    // Opening the library is near-instant, and bootstrap awaits this before
    // the first frame — so the failure path must not stall startup.
    final started = await ready.future
        .timeout(readyTimeout, onTimeout: () => false);

    if (!started) {
      debugPrint('[TdlibReceiver] Isolate could not open TDLib — using polling');
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
      await TdPlugin.initialize();
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
        // A payload we can't parse is not worth tearing the loop down for.
      }
    }
  }
}
