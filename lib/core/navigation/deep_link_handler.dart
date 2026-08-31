import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/core/navigation/telegram_link.dart';

/// Where a parsed link should take the reader.
///
/// A route string rather than a navigation call, so the whole decision is one
/// pure function with a testable answer — the screen that acts on it does
/// nothing but push what it is given.
abstract class DeepLinkRoutes {
  /// The screen for a link whose chat id is already known.
  ///
  /// [chatId] comes from resolving a username, which costs a request and so
  /// happens outside this. A private-post link carries its own id and needs no
  /// resolution at all.
  static String? routeFor(TelegramLink link, {int? chatId}) => switch (link) {
    TelegramChannelLink() when chatId != null => '/channel/$chatId',
    // The channel screen scrolls to the post and highlights it, which is what
    // the existing `highlight` parameter is for — a link to a post is a link
    // to it *in its channel*, not to a detached copy.
    TelegramPostLink() when chatId != null =>
      '/post/${chatId}_${link.tdlibMessageId}',
    TelegramPrivatePostLink() =>
      '/post/${link.chatId}_${link.tdlibMessageId}',
    // A private channel with no post singled out. The id is already the one
    // TDLib knows, so unlike a username this costs no resolution.
    TelegramPrivateChannelLink() => '/channel/${link.chatId}',
    // An invite is a join, not a destination. Nothing in gramX joins a private
    // chat, so this is one of the shapes handed back to Telegram. A hashtag is
    // not a route either — it sets the search field and switches tab, which
    // the shell does directly.
    _ => null,
  };

  /// Whether opening [link] needs a username resolved first.
  static String? usernameToResolve(TelegramLink link) => switch (link) {
    TelegramChannelLink() => link.username,
    TelegramPostLink() => link.username,
    _ => null,
  };
}

/// What to do with a location the router has no route for.
///
/// A Telegram link should never reach the router as a *location* — app_links
/// owns them and parks them in [PendingDeepLink]. But a platform that routes
/// one anyway, on any OS, past or future, lands the reader on "Page Not Found"
/// with a raw `GoException` under it: the worst version of an outcome that is
/// entirely recoverable, since the link is right there and the app knows how
/// to open it.
///
/// Returns the link to hand back to [PendingDeepLink], or null when the
/// location really is nothing this app knows.
Uri? deepLinkFromStrayLocation(Uri location) =>
    TelegramLinks.parse(location) == null ? null : location;

/// A link waiting to be opened.
///
/// Held in a provider rather than pushed directly, because a link can arrive
/// before there is a navigator — a cold start from a tapped link runs before
/// the first frame. The shell watches this and consumes it once it can.
class PendingDeepLink extends Notifier<Uri?> {
  StreamSubscription<Uri>? _sub;

  @override
  Uri? build() {
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });
    return null;
  }

  /// Begins listening, and picks up the link the app was launched with.
  ///
  /// Called from `bootstrap()`. The launch link is asked for explicitly
  /// because the stream only carries links that arrive while running — a cold
  /// start would otherwise drop the very link that caused it.
  Future<void> start({AppLinks? links}) async {
    if (_sub != null) return;
    final appLinks = links ?? AppLinks();

    _sub = appLinks.uriLinkStream.listen(
      offer,
      onError: (Object e) => debugPrint('[DeepLink] stream error: $e'),
    );

    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) offer(initial);
    } catch (e) {
      debugPrint('[DeepLink] no launch link: $e');
    }
  }

  /// Records a link for the shell to act on.
  ///
  /// The gate is `couldBeTelegram` — scheme and host — and not a full parse.
  /// It used to be the parse, which quietly made the local regex the final
  /// word on every incoming link: a shape only TDLib recognises was dropped
  /// here and never reached the resolver that could have typed it. Deciding
  /// *where* a link goes needs TDLib and is therefore asynchronous, and this
  /// runs on a stream listener, so the decision belongs downstream. Anything
  /// Telegram's but unopenable is handed back to the OS by the shell.
  void offer(Uri uri) {
    if (!TelegramLinks.couldBeTelegram(uri)) {
      debugPrint('[DeepLink] not a Telegram link: $uri');
      return;
    }
    state = uri;
  }

  /// Takes the pending link, leaving nothing behind.
  ///
  /// Consumed rather than cleared by the caller, so a rebuild between the read
  /// and the clear cannot open the same link twice.
  Uri? take() {
    final pending = state;
    state = null;
    return pending;
  }
}

final pendingDeepLinkProvider = NotifierProvider<PendingDeepLink, Uri?>(
  PendingDeepLink.new,
);
