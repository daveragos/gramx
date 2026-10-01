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

    // `inactive` fires for calls, the shade and dialogs, not for leaving.
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

    // Closing flushes the database; an unflushed one slows the next launch.
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

    // Wi-Fi decides whether a download is free, so it wins over mobile.
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

    // On some platforms a VPN is reported alone; it is still a usable link.
    test('a lone VPN is a usable network, not an absent one', () {
      final type = TdlibLifecycleRules.networkTypeFor([ConnectivityResult.vpn]);

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

  // These must work during a flood wait, since they help a connection recover.
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
