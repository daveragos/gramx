import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/core/config/trok_bots.dart';

import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// Proof from Telegram of who is asking: Mini App init data for Trok's bot,
/// which Trok's server checks with the bot's token. gramX holds no secret,
/// since anything built into an open-source app is public.
abstract interface class TrokCredentials {
  /// The init data to send as `Authorization: tma <init data>`.
  Future<String> initData();

  /// Drops the init data held, so the next [initData] fetches fresh.
  void invalidate();
}

/// Gets init data the way a Telegram client opens a bot's Main Mini App,
/// without showing the app.
class TdlibTrokCredentials implements TrokCredentials {
  /// Trok's bot. Telegram signs init data for it.
  static const botUsername = TrokBots.trok;

  /// How gramX names itself to Telegram when opening the Mini App.
  static const applicationName = 'gramx';

  /// Trok refuses init data older than a day; fetch fresh a little before.
  static const _lifetime = Duration(hours: 23);

  final TdlibService _tdlib;
  int? _botUserId;
  String? _initData;
  Future<String>? _fetching;

  TdlibTrokCredentials(this._tdlib);

  @override
  Future<String> initData() {
    final held = _initData;
    if (held != null && !_isStale(held)) return Future.value(held);
    return _fetching ??= _fetch().whenComplete(() => _fetching = null);
  }

  @override
  void invalidate() => _initData = null;

  Future<String> _fetch() async {
    final botUserId = _botUserId ??= await _resolveBot();
    final app = await _tdlib.sendRequest(
      td.GetMainWebApp(
        chatId: 0,
        botUserId: botUserId,
        startParameter: '',
        applicationName: applicationName,
      ),
    );
    if (app is! td.MainWebApp) {
      throw StateError('Unexpected reply to getMainWebApp: $app');
    }
    final initData = initDataFromUrl(app.url);
    if (initData == null) {
      throw StateError('No tgWebAppData in the Mini App link.');
    }
    return _initData = initData;
  }

  Future<int> _resolveBot() async {
    final chat = await _tdlib.sendRequest(
      const td.SearchPublicChat(username: botUsername),
    );
    if (chat is td.Chat && chat.type is td.ChatTypePrivate) {
      final userId = (chat.type as td.ChatTypePrivate).userId;
      // TDLib knows a bot has a Main Mini App only once it holds the bot's
      // full profile. Without it, the first getMainWebApp for a bot new to
      // this phone fails.
      await _tdlib.sendRequest(td.GetUserFullInfo(userId: userId));
      return userId;
    }
    throw StateError('@$botUsername is not a bot Telegram knows.');
  }

  /// The init data in a Mini App link: `tgWebAppData` from its fragment,
  /// decoded once and otherwise untouched, since Trok checks its signature.
  static String? initDataFromUrl(String url) {
    final hash = url.indexOf('#');
    if (hash < 0) return null;
    const key = 'tgWebAppData=';
    for (final part in url.substring(hash + 1).split('&')) {
      if (part.startsWith(key)) {
        final value = Uri.decodeComponent(part.substring(key.length));
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }

  static bool _isStale(String initData) {
    const key = 'auth_date=';
    final field = initData
        .split('&')
        .firstWhere((p) => p.startsWith(key), orElse: () => key);
    final signedAt = int.tryParse(field.substring(key.length));
    if (signedAt == null) return false;
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(signedAt * 1000),
    );
    return age > _lifetime;
  }
}
