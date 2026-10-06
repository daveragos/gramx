import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/core/navigation/share_intake.dart';
import 'package:gramx/core/navigation/telegram_link.dart';

/// What a public username belongs to. `t.me/<name>` looks the same for all
/// three, but each opens a different screen.
enum ResolvedChatKind {
  channel,

  group,

  /// A user or bot.
  person,
}

/// Maps a parsed link to a route string.
abstract class DeepLinkRoutes {
  /// The route for a link, or null if the app has no screen for it. [chatId]
  /// and [kind] come from resolving a username; `t.me/c/` links are channels.
  static String? routeFor(
    TelegramLink link, {
    int? chatId,
    ResolvedChatKind kind = ResolvedChatKind.channel,
  }) => switch (link) {
    TelegramChannelLink() when chatId != null => switch (kind) {
      ResolvedChatKind.channel => '/channel/$chatId',
      ResolvedChatKind.group => '/chat/$chatId',
      // A private chat's id is its user's id.
      ResolvedChatKind.person => '/user/$chatId',
    },
    // A message link in a group opens the group, not the post screen.
    TelegramPostLink()
        when chatId != null && kind != ResolvedChatKind.channel =>
      '/chat/$chatId',
    TelegramPostLink() when chatId != null =>
      '/post/${chatId}_${link.tdlibMessageId}',
    TelegramPrivatePostLink() => '/post/${link.chatId}_${link.tdlibMessageId}',
    // The id is already TDLib's, so no resolution is needed.
    TelegramPrivateChannelLink() => '/channel/${link.chatId}',
    // Invites are opened externally; hashtags are handled by the shell.
    _ => null,
  };

  /// Whether opening [link] needs a username resolved first.
  static String? usernameToResolve(TelegramLink link) => switch (link) {
    TelegramChannelLink() => link.username,
    TelegramPostLink() => link.username,
    _ => null,
  };
}

/// Returns a Telegram link that reached the router as a location, for
/// [PendingDeepLink], or null if it is not one.
Uri? deepLinkFromStrayLocation(Uri location) =>
    TelegramLinks.parse(location) == null ? null : location;

/// A link waiting for the shell to open it, since a cold start link arrives
/// before there is a navigator.
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

  /// Begins listening, and picks up the launch link, which the stream does
  /// not carry. Called from `bootstrap()`.
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

  /// Records a link for the shell. Only checks scheme and host, so shapes
  /// only TDLib recognises still reach the resolver.
  ///
  /// A share from the iOS share extension opens the Telegram link it holds,
  /// or else goes to [PendingSharedText] for the composer.
  void offer(Uri uri) {
    final shared = ShareLinks.sharedText(uri);
    if (shared != null) {
      final link = ShareLinks.telegramLinkIn(shared);
      if (link == null) {
        ref.read(pendingSharedTextProvider.notifier).offer(shared);
        return;
      }
      uri = link;
    }

    if (!TelegramLinks.couldBeTelegram(uri)) {
      debugPrint('[DeepLink] not a Telegram link: $uri');
      return;
    }
    state = uri;
  }

  /// Takes and clears the pending link, so it cannot open twice.
  Uri? take() {
    final pending = state;
    state = null;
    return pending;
  }
}

final pendingDeepLinkProvider = NotifierProvider<PendingDeepLink, Uri?>(
  PendingDeepLink.new,
);
