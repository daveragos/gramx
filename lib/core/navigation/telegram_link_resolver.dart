import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/core/navigation/telegram_link.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// What TDLib made of a link, before gramX decides what to do about it.
///
/// Three answers, not two, and the third is the one that matters. "TDLib could
/// not say" and "TDLib says this is a Telegram link gramX has no screen for"
/// look identical if you collapse them into null — and they must not be
/// treated alike. The first should fall through to the local parser; the
/// second must **not**, because the local parser's last rule is "anything left
/// is a username", and a link shape Telegram adds next year would be read as a
/// channel that does not exist.
@immutable
sealed class LinkVerdict {
  const LinkVerdict();
}

/// TDLib typed the link and gramX has somewhere to put it.
class LinkHandled extends LinkVerdict {
  final TelegramLink link;
  const LinkHandled(this.link);
}

/// TDLib typed the link and gramX has no screen for it — a bot start, a story,
/// a sticker set, a gift. Authoritative: hand it to Telegram, do not guess.
class LinkForTelegram extends LinkVerdict {
  const LinkForTelegram();
}

/// TDLib had no answer — the link is not internal, or the client is not up
/// yet. Ask the local parser.
class LinkUnknown extends LinkVerdict {
  const LinkUnknown();
}

/// Reads a Telegram link, asking Telegram's own parser first.
///
/// `GetInternalLinkType` is the parser shipped inside TDLib. It knows the
/// forty-odd link shapes Telegram publishes — bot starts, stories, gifts,
/// folder invites, boosts, premium features — and gains new ones with every
/// TDLib bump, which no regex in this repository ever will. TDLib documents it
/// as *"Returns a 404 error if the link is not internal. Can be called before
/// authorization"*, and callable before authorization means it never reaches
/// the server: it is off the request budget and works in guest mode. See
/// `docs/TDLIB.md`.
///
/// [TelegramLinks] stays, as the fallback. It is needed for two real cases,
/// not as a hedge:
///
///  * **Cold start.** A link can arrive before the native client has finished
///    its handshake, which is exactly when a tapped link is most likely to be
///    what launched the app.
///  * **Addressing a message.** TDLib types a message link but hands back only
///    a URL to pass to `getMessageLinkInfo` — which is *not* documented
///    offline, so calling it would put a networked request on the budget for
///    every tapped post link. The local parser already reads the username and
///    the post id out of the same URL for nothing, and the existing
///    `SearchPublicChat` resolve is the one request that path is allowed.
class TelegramLinkResolver {
  final TdlibService _tdlib;

  const TelegramLinkResolver(this._tdlib);

  /// What [uri] points at, or null when nothing here can open it.
  Future<TelegramLink?> resolve(Uri uri) async {
    final verdict = await classify(uri);
    return switch (verdict) {
      LinkHandled(:final link) => link,
      // Telegram's own parser recognised it and gramX has no screen. Guessing
      // past that is how a reader ends up on a channel that does not exist.
      LinkForTelegram() => null,
      LinkUnknown() => TelegramLinks.parse(uri),
    };
  }

  /// TDLib's verdict on [uri]. Exposed for the tests that pin the three-state
  /// behaviour; callers want [resolve].
  Future<LinkVerdict> classify(Uri uri) async {
    final td.TdObject reply;
    try {
      reply = await _tdlib.sendRequest(
        td.GetInternalLinkType(link: uri.toString()),
      );
    } catch (_) {
      // A 404 for a link that is not Telegram's, or a client that is not up.
      // Neither is a reason to refuse the link outright.
      return const LinkUnknown();
    }
    if (reply is! td.InternalLinkType) return const LinkUnknown();
    return verdictFor(reply, uri);
  }

  /// Maps one of TDLib's forty-odd link types onto what gramX can do with it.
  ///
  /// Pure and static so every branch is testable without a client. The default
  /// is deliberately [LinkForTelegram] rather than [LinkUnknown]: a type this
  /// app has not heard of is still a link Telegram understands, and the honest
  /// thing is to hand it over rather than let the local parser read the first
  /// path segment as a channel name.
  @visibleForTesting
  static LinkVerdict verdictFor(td.InternalLinkType type, Uri uri) {
    switch (type) {
      case td.InternalLinkTypePublicChat():
        final username = type.chatUsername;
        return TelegramLinks.isUsername(username)
            ? LinkHandled(TelegramChannelLink(username))
            : const LinkForTelegram();

      // TDLib names the kind but not the address — the id pair is behind
      // `getMessageLinkInfo`, which is a networked request. The local parser
      // reads the same two numbers out of the URL for free.
      case td.InternalLinkTypeMessage():
        final parsed = TelegramLinks.parse(uri);
        return parsed == null
            ? const LinkForTelegram()
            : LinkHandled(parsed);

      case td.InternalLinkTypeChatInvite():
        final hash = _inviteHash(type.inviteLink);
        return hash == null
            ? const LinkForTelegram()
            : LinkHandled(TelegramInviteLink(hash));

      // TDLib does not recognise the deep link at all, which is not the same
      // as recognising it and finding it unsupported. `tg://search` lands here
      // on this TDLib version, and the local parser opens it.
      case td.InternalLinkTypeUnknownDeepLink():
        return const LinkUnknown();

      // Everything else — bot starts, stories, gifts, folder invites, boosts,
      // stickers, proxies, settings screens — is a real Telegram link with no
      // gramX screen behind it.
      default:
        return const LinkForTelegram();
    }
  }

  /// The opaque token out of `https://t.me/+HASH` or `.../joinchat/HASH`.
  ///
  /// TDLib hands back its own canonical spelling of an invite, which is a URL
  /// rather than the hash [TelegramInviteLink] holds.
  static String? _inviteHash(String inviteLink) {
    final parsed = TelegramLinks.parse(Uri.tryParse(inviteLink) ?? Uri());
    return parsed is TelegramInviteLink ? parsed.hash : null;
  }
}

final telegramLinkResolverProvider = Provider<TelegramLinkResolver>(
  (ref) => TelegramLinkResolver(ref.watch(tdlibServiceProvider)),
);
