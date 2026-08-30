import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/infrastructure/telegram/tdlib_lifecycle.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

void main() {
  group('TdlibLifecycleRules.forState', () {
    test('resumed goes online and reopens connections', () {
      final intent = TdlibLifecycleRules.forState(AppLifecycleState.resumed);

      expect(intent.online, isTrue);
      expect(intent.reopenConnections, isTrue);
      expect(intent.close, isFalse);
    });

    // Both platforms emit `inactive` for an incoming call, the notification
    // shade, the app switcher and a permission dialog. None of those mean the
    // reader left, and acting on them would flicker the account's presence on
    // and off all day — one request per flicker.
    test('inactive changes nothing at all', () {
      expect(
        TdlibLifecycleRules.forState(AppLifecycleState.inactive),
        LifecycleIntent.none,
      );
    });

    test('paused and hidden go offline without closing', () {
      for (final state in [
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
      ]) {
        final intent = TdlibLifecycleRules.forState(state);
        expect(intent.online, isFalse, reason: '$state');
        expect(intent.close, isFalse, reason: '$state');
        expect(intent.reopenConnections, isFalse, reason: '$state');
      }
    });

    // The database is flushed on close. A process killed without it leaves one
    // that has to be recovered on the next launch, which the reader pays for
    // as a slow start.
    test('detached closes the client and stops claiming presence', () {
      final intent = TdlibLifecycleRules.forState(AppLifecycleState.detached);

      expect(intent.close, isTrue);
      expect(intent.online, isFalse);
    });

    test('every lifecycle state is answered', () {
      for (final state in AppLifecycleState.values) {
        expect(
          () => TdlibLifecycleRules.forState(state),
          returnsNormally,
          reason: '$state',
        );
      }
    });
  });

  group('TdlibLifecycleRules.networkTypeFor', () {
    test('wifi and ethernet both read as WiFi', () {
      expect(
        TdlibLifecycleRules.networkTypeFor([ConnectivityResult.wifi]),
        isA<td.NetworkTypeWiFi>(),
      );
      expect(
        TdlibLifecycleRules.networkTypeFor([ConnectivityResult.ethernet]),
        isA<td.NetworkTypeWiFi>(),
      );
    });

    test('mobile alone reads as Mobile', () {
      expect(
        TdlibLifecycleRules.networkTypeFor([ConnectivityResult.mobile]),
        isA<td.NetworkTypeMobile>(),
      );
    });

    // A device can be on both at once. Wi-Fi is the one TDLib should be told
    // about, because it is the one that decides whether a download is free.
    test('wifi wins when both are up', () {
      expect(
        TdlibLifecycleRules.networkTypeFor([
          ConnectivityResult.mobile,
          ConnectivityResult.wifi,
        ]),
        isA<td.NetworkTypeWiFi>(),
      );
    });

    test('nothing up reads as None', () {
      expect(
        TdlibLifecycleRules.networkTypeFor([ConnectivityResult.none]),
        isA<td.NetworkTypeNone>(),
      );
    });

    // A VPN is reported alongside whatever carries it, but on some platforms
    // it arrives alone. It is still a usable link, so it must not be reported
    // as no network at all — that would stop TDLib trying.
    test('a lone VPN is a usable network, not an absent one', () {
      final type = TdlibLifecycleRules.networkTypeFor([
        ConnectivityResult.vpn,
      ]);

      expect(type, isA<td.NetworkTypeOther>());
      expect(type, isNot(isA<td.NetworkTypeNone>()));
    });

    test('an empty answer is other, not none', () {
      expect(
        TdlibLifecycleRules.networkTypeFor(const []),
        isA<td.NetworkTypeOther>(),
      );
    });
  });

  // These three have to work while the account is rate limited: telling TDLib
  // the app went away, or that the network changed, is how a flood wait ends
  // sooner rather than later. Gating them parks the one call that reopens a
  // dead connection behind the deadline that connection caused.
  group('lifecycle requests bypass the flood gate', () {
    test('setNetworkType, setOption and close are all local-only', () {
      expect(
        TdlibService.isLocalOnlyRequest(const td.SetNetworkType()),
        isTrue,
      );
      expect(
        TdlibService.isLocalOnlyRequest(
          const td.SetOption(
            name: 'online',
            value: td.OptionValueBoolean(value: false),
          ),
        ),
        isTrue,
      );
      expect(TdlibService.isLocalOnlyRequest(const td.Close()), isTrue);
    });

    test('a networked request is still gated', () {
      expect(
        TdlibService.isLocalOnlyRequest(const td.SearchPublicChats(query: 'x')),
        isFalse,
      );
    });
  });
}
