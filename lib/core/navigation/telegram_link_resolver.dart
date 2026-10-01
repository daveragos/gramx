import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/core/navigation/telegram_link.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// TDLib's classification of a link. Only [LinkUnknown] falls through to the
/// local parser, which would misread unsupported links as usernames.
@immutable
sealed class LinkVerdict {
  const LinkVerdict();
}

/// TDLib recognised the link and the app has a screen for it.
class LinkHandled extends LinkVerdict {
  final TelegramLink link;
  const LinkHandled(this.link);
}

/// TDLib recognised the link but the app has no screen for it.
class LinkForTelegram extends LinkVerdict {
  const LinkForTelegram();
}

/// TDLib had no answer: the link is not internal, or the client is not up.
class LinkUnknown extends LinkVerdict {
  const LinkUnknown();
}

/// Reads a Telegram link with TDLib's `GetInternalLinkType`, falling back to
/// [TelegramLinks]. `GetInternalLinkType` works before authorization, so it
/// makes no server request and works in guest mode.
class TelegramLinkResolver {
  final TdlibService _tdlib;

  const TelegramLinkResolver(this._tdlib);

  /// What [uri] points at, or null if this app cannot open it.
  Future<TelegramLink?> resolve(Uri uri) async {
    final verdict = await classify(uri);
    return switch (verdict) {
      LinkHandled(:final link) => link,
      LinkForTelegram() => null,
      LinkUnknown() => TelegramLinks.parse(uri),
    };
  }

  /// TDLib's verdict on [uri]. Exposed for tests; callers use [resolve].
  Future<LinkVerdict> classify(Uri uri) async {
    final td.TdObject reply;
    try {
      reply = await _tdlib.sendRequest(
        td.GetInternalLinkType(link: uri.toString()),
      );
    } catch (_) {
      // A 404 for a non-internal link, or the client is not up.
      return const LinkUnknown();
    }
    if (reply is! td.InternalLinkType) return const LinkUnknown();
    return verdictFor(reply, uri);
  }

  /// Maps a TDLib link type to a verdict. Unhandled types default to
  /// [LinkForTelegram], so the local parser never misreads them.
  @visibleForTesting
  static LinkVerdict verdictFor(td.InternalLinkType type, Uri uri) {
    switch (type) {
      case td.InternalLinkTypePublicChat():
        final username = type.chatUsername;
        return TelegramLinks.isUsername(username)
            ? LinkHandled(TelegramChannelLink(username))
            : const LinkForTelegram();

      // The ids need `getMessageLinkInfo`, a network call, so the local parser
      // reads them from the URL instead.
      case td.InternalLinkTypeMessage():
        final parsed = TelegramLinks.parse(uri);
        return parsed == null ? const LinkForTelegram() : LinkHandled(parsed);

      case td.InternalLinkTypeChatInvite():
        final hash = _inviteHash(type.inviteLink);
        return hash == null
            ? const LinkForTelegram()
            : LinkHandled(TelegramInviteLink(hash));

      // Includes `tg://search`, which the local parser handles.
      case td.InternalLinkTypeUnknownDeepLink():
        return const LinkUnknown();

      default:
        return const LinkForTelegram();
    }
  }

  /// The hash from TDLib's canonical invite URL.
  static String? _inviteHash(String inviteLink) {
    final parsed = TelegramLinks.parse(Uri.tryParse(inviteLink) ?? Uri());
    return parsed is TelegramInviteLink ? parsed.hash : null;
  }
}

final telegramLinkResolverProvider = Provider<TelegramLinkResolver>(
  (ref) => TelegramLinkResolver(ref.watch(tdlibServiceProvider)),
);
