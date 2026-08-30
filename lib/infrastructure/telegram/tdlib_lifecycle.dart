import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// What the client should be told when the app reaches a lifecycle state.
///
/// A value object rather than a set of calls, so the decision — which is the
/// part that is easy to get wrong — can be tested without a TDLib client.
@immutable
class LifecycleIntent {
  /// Whether the account should report itself as present.
  ///
  /// Null means *no change*: the state says nothing about whether the reader
  /// went away, so repeating the last answer is better than guessing a new one.
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

  /// Nothing to do — the state is a transient one.
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
  /// The one non-obvious case is [AppLifecycleState.inactive]. Both platforms
  /// emit it constantly — an incoming call, the notification shade, the app
  /// switcher, a permission dialog — and none of those mean the reader left.
  /// Treating it as "away" would flicker the account's presence on and off all
  /// day and spend a request on each flicker, so it is deliberately ignored.
  static LifecycleIntent forState(AppLifecycleState state) => switch (state) {
    // Coming back is also the moment a connection made on a network that no
    // longer exists has to be replaced. Reopening here is what stops a phone
    // woken on a different network from sitting on a dead socket.
    AppLifecycleState.resumed => const LifecycleIntent(
      online: true,
      reopenConnections: true,
    ),
    AppLifecycleState.inactive => LifecycleIntent.none,
    AppLifecycleState.hidden => const LifecycleIntent(online: false),
    AppLifecycleState.paused => const LifecycleIntent(online: false),
    // The process is going away. Say goodbye in both senses: stop claiming to
    // be present, and let TDLib flush rather than be killed mid-write.
    AppLifecycleState.detached => const LifecycleIntent(
      online: false,
      close: true,
    ),
  };

  /// The TDLib network type for what the platform reports.
  ///
  /// `connectivity_plus` answers with a *list* — a device can be on Wi-Fi and
  /// mobile at once, and a VPN is reported alongside whatever carries it. The
  /// order here is the order TDLib cares about: an interface that is cheap and
  /// fast first, `none` only when nothing at all is up.
  static td.NetworkType networkTypeFor(List<ConnectivityResult> results) {
    if (results.isEmpty) return const td.NetworkTypeOther();

    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return const td.NetworkTypeWiFi();
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return const td.NetworkTypeMobile();
    }
    // A VPN with no carrier reported under it still has *something* underneath;
    // "other" is TDLib's answer for a link it can use but can't characterise.
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
///
/// Owns the two subscriptions and nothing else — every decision it makes comes
/// from [TdlibLifecycleRules], which is where the tests point.
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

    // Seed the client with the network it is actually on before waiting for a
    // change: TDLib assumes "other" until told, and the first thing it does on
    // a metered connection should not be based on a guess.
    unawaited(_pushCurrentNetwork());

    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      (results) => unawaited(
        _tdlib.setNetworkType(TdlibLifecycleRules.networkTypeFor(results)),
      ),
      onError: (Object e) =>
          debugPrint('[Lifecycle] connectivity stream error: $e'),
    );

    // The app is on screen the moment this runs; nothing else will say so.
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

    // Order matters: reopening while still claiming to be away would have the
    // fresh connection announce the wrong presence.
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

/// The app's single lifecycle observer.
///
/// Read once from `bootstrap()`, which is also where it is started — a
/// lifecycle observer created lazily by whichever widget happened to ask for it
/// first would miss every transition before that widget was built.
final tdlibLifecycleProvider = Provider<TdlibLifecycle>((ref) {
  final lifecycle = TdlibLifecycle(ref.watch(tdlibServiceProvider));
  ref.onDispose(() => unawaited(lifecycle.dispose()));
  return lifecycle;
});
