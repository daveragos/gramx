import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// What the client should be told when the app reaches a lifecycle state.
/// A value object so the decision can be tested without a TDLib client.
@immutable
class LifecycleIntent {
  /// Whether the account should report itself as online. Null means no change.
  final bool? online;

  /// Whether every network connection should be reopened.
  final bool reopenConnections;

  /// Whether the client should be shut down, flushing its database.
  final bool close;

  const LifecycleIntent({
    this.online,
    this.reopenConnections = false,
    this.close = false,
  });

  /// Nothing to do.
  static const none = LifecycleIntent();

  @override
  bool operator ==(Object other) =>
      other is LifecycleIntent &&
      other.online == online &&
      other.reopenConnections == reopenConnections &&
      other.close == close;

  @override
  int get hashCode => Object.hash(online, reopenConnections, close);

  @override
  String toString() =>
      'LifecycleIntent(online: $online, reopen: $reopenConnections, '
      'close: $close)';
}

/// The pure half of lifecycle handling: state in, intent out.
abstract class TdlibLifecycleRules {
  /// What to tell TDLib when the app reaches [state].
  ///
  /// [AppLifecycleState.inactive] is ignored: it fires for calls, the
  /// notification shade and dialogs, and would make presence flicker.
  static LifecycleIntent forState(AppLifecycleState state) => switch (state) {
    // Reopen so a phone woken on a different network drops its dead sockets.
    AppLifecycleState.resumed => const LifecycleIntent(
      online: true,
      reopenConnections: true,
    ),
    AppLifecycleState.inactive => LifecycleIntent.none,
    AppLifecycleState.hidden => const LifecycleIntent(online: false),
    AppLifecycleState.paused => const LifecycleIntent(online: false),
    // Go offline and close so TDLib flushes instead of being killed mid-write.
    AppLifecycleState.detached => const LifecycleIntent(
      online: false,
      close: true,
    ),
  };

  /// The TDLib network type for the platform's list of active interfaces.
  /// Wi-Fi or ethernet wins over mobile; `none` only when nothing is up.
  static td.NetworkType networkTypeFor(List<ConnectivityResult> results) {
    if (results.isEmpty) return const td.NetworkTypeOther();

    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return const td.NetworkTypeWiFi();
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return const td.NetworkTypeMobile();
    }
    // A VPN with no reported carrier is still a usable link.
    if (results.contains(ConnectivityResult.vpn)) {
      return const td.NetworkTypeOther();
    }
    if (results.every((r) => r == ConnectivityResult.none)) {
      return const td.NetworkTypeNone();
    }
    return const td.NetworkTypeOther();
  }
}

/// Keeps TDLib in step with the app's lifecycle and the device's network.
/// Decisions come from [TdlibLifecycleRules].
class TdlibLifecycle with WidgetsBindingObserver {
  final TdlibService _tdlib;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _started = false;

  TdlibLifecycle(this._tdlib, {Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  /// Begins observing. Safe to call more than once.
  void start() {
    if (_started) return;
    _started = true;

    WidgetsBinding.instance.addObserver(this);

    // TDLib assumes "other" until told, so report the current network now.
    unawaited(_pushCurrentNetwork());

    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      (results) => unawaited(
        _tdlib.setNetworkType(TdlibLifecycleRules.networkTypeFor(results)),
      ),
      onError: (Object e) =>
          debugPrint('[Lifecycle] connectivity stream error: $e'),
    );

    // The app is in the foreground now and no lifecycle event will say so.
    unawaited(_tdlib.setOnline(true));
  }

  Future<void> _pushCurrentNetwork() async {
    try {
      final results = await _connectivity.checkConnectivity();
      await _tdlib.setNetworkType(TdlibLifecycleRules.networkTypeFor(results));
    } catch (e) {
      debugPrint('[Lifecycle] initial connectivity check failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final intent = TdlibLifecycleRules.forState(state);
    if (intent == LifecycleIntent.none) return;

    unawaited(_apply(intent));
  }

  Future<void> _apply(LifecycleIntent intent) async {
    final online = intent.online;
    if (online != null) await _tdlib.setOnline(online);

    // Set presence before reopening so new connections report the right one.
    if (intent.reopenConnections) await _pushCurrentNetwork();

    if (intent.close) await _tdlib.close();
  }

  Future<void> dispose() async {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    await _connectivitySub?.cancel();
    _connectivitySub = null;
  }
}

/// The app's single lifecycle observer. Started from `bootstrap()` so it sees
/// every transition from launch.
final tdlibLifecycleProvider = Provider<TdlibLifecycle>((ref) {
  final lifecycle = TdlibLifecycle(ref.watch(tdlibServiceProvider));
  ref.onDispose(() => unawaited(lifecycle.dispose()));
  return lifecycle;
});
