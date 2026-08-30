import 'package:flutter/foundation.dart';

import 'package:gramx/core/telegram/telegram_ids.dart';

/// What a Telegram link points at.
///
/// The parse is deliberately pure and the resolution is not: turning a username
/// into a chat id costs a request, so it happens once, on a tap, in
/// `DeepLinkRouter` — never here.
@immutable
sealed class TelegramLink {
  const TelegramLink();
}

/// `t.me/durov` — a channel, a group or a person, and which of those it is
/// cannot be known without asking Telegram.
class TelegramChannelLink extends TelegramLink {
  final String username;

  const TelegramChannelLink(this.username);

  @override
  bool operator ==(Object other) =>
      other is TelegramChannelLink && other.username == username;

  @override
  int get hashCode => username.hashCode;

  @override
  String toString() => 'TelegramChannelLink($username)';
}

/// `t.me/durov/123` — one post in a public channel.
class TelegramPostLink extends TelegramLink {
  final String username;

  /// The number in the link, which is Telegram's *server* id. TDLib shifts it
  /// left by 20 bits; [tdlibMessageId] does that.
  final int serverMessageId;

  const TelegramPostLink(this.username, this.serverMessageId);

  int get tdlibMessageId => serverMessageId << TelegramIds.messageIdShift;

  @override
  bool operator ==(Object other) =>
      other is TelegramPostLink &&
      other.username == username &&
      other.serverMessageId == serverMessageId;

  @override
  int get hashCode => Object.hash(username, serverMessageId);

  @override
  String toString() => 'TelegramPostLink($username, $serverMessageId)';
}

/// `t.me/c/1234567890/123` — one post in a private channel, addressed by its
/// supergroup id. Only resolves for a member, which is true of the link itself.
class TelegramPrivatePostLink extends TelegramLink {
  final int supergroupId;
  final int serverMessageId;

  const TelegramPrivatePostLink(this.supergroupId, this.serverMessageId);

  /// The chat id TDLib knows this supergroup by.
  int get chatId => int.parse('-100$supergroupId');

  int get tdlibMessageId => serverMessageId << TelegramIds.messageIdShift;

  @override
  bool operator ==(Object other) =>
      other is TelegramPrivatePostLink &&
      other.supergroupId == supergroupId &&
      other.serverMessageId == serverMessageId;

  @override
  int get hashCode => Object.hash(supergroupId, serverMessageId);

  @override
  String toString() =>
      'TelegramPrivatePostLink($supergroupId, $serverMessageId)';
}

/// `t.me/+AbCdEf` or `t.me/joinchat/AbCdEf` — an invite to somewhere this
/// account is not yet.
class TelegramInviteLink extends TelegramLink {
  final String hash;

  const TelegramInviteLink(this.hash);

  @override
  bool operator ==(Object other) =>
      other is TelegramInviteLink && other.hash == hash;

  @override
  int get hashCode => hash.hashCode;

  @override
  String toString() => 'TelegramInviteLink($hash)';
}

/// Reads a Telegram link.
abstract class TelegramLinks {
  /// Hosts Telegram serves its links from.
  static const hosts = {'t.me', 'telegram.me', 'telegram.dog', 'www.t.me'};

  /// First path segments that are a *feature*, not a username.
  ///
  /// Telegram reserves these, and gramX implements none of them — a link to a
  /// sticker pack or a proxy is not something this app can open, and treating
  /// the word as a channel name would send somebody to a channel that does not
  /// exist. Unparsed is the honest answer, and the caller hands those to
  /// Telegram itself.
  static const reserved = {
    'addemoji',
    'addlist',
    'addstickers',
    'addtheme',
    'bg',
    'boost',
    'confirmphone',
    'contact',
    'giftcode',
    'invoice',
    'login',
    'proxy',
    'setlanguage',
    'share',
    'socks',
    'nft',
    'm',
  };

  /// What [uri] points at, or null when it is not a Telegram link this app can
  /// open.
  static TelegramLink? parse(Uri uri) => switch (uri.scheme.toLowerCase()) {
    'https' || 'http' => _parseWeb(uri),
    'tg' => _parseScheme(uri),
    _ => null,
  };

  static TelegramLink? _parseWeb(Uri uri) {
    if (!hosts.contains(uri.host.toLowerCase())) return null;

    final segments = [
      for (final segment in uri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    if (segments.isEmpty) return null;

    final first = segments.first;

    // `t.me/s/name` is the web *preview* of a channel — the page guest mode
    // reads. It names the same channel, so it opens the same screen.
    if (first == 's' && segments.length >= 2) {
      return _publicLink(segments[1], segments.skip(2).toList());
    }

    // `t.me/c/<supergroup>/<message>`, optionally with a topic id in between.
    if (first == 'c') {
      final group = segments.length >= 2 ? int.tryParse(segments[1]) : null;
      if (group == null) return null;
      final message = _lastNumber(segments.skip(2));
      if (message == null) return null;
      return TelegramPrivatePostLink(group, message);
    }

    if (first == 'joinchat' && segments.length >= 2) {
      return TelegramInviteLink(segments[1]);
    }
    // `t.me/+hash`. A `+` also introduces a phone number in a contact link,
    // which carries digits only — and that is a person to add, not a place to
    // go, so it is left unparsed.
    if (first.startsWith('+')) {
      final hash = first.substring(1);
      if (hash.isEmpty || int.tryParse(hash) != null) return null;
      return TelegramInviteLink(hash);
    }

    if (reserved.contains(first.toLowerCase())) return null;

    return _publicLink(first, segments.skip(1).toList());
  }

  /// A username, optionally followed by a post id — and, in a forum, a topic
  /// id before it.
  static TelegramLink? _publicLink(String name, List<String> rest) {
    if (!isUsername(name)) return null;

    // The *last* number is the message. A forum link carries the topic first,
    // and gramX has no topics yet (T13-12) — the post still opens.
    final message = _lastNumber(rest);
    if (message == null) {
      // Trailing junk that is not a message id means this is some link shape
      // this app does not know. Better handed to Telegram than half-opened.
      return rest.isEmpty ? TelegramChannelLink(name) : null;
    }
    return TelegramPostLink(name, message);
  }

  static TelegramLink? _parseScheme(Uri uri) {
    final params = uri.queryParameters;

    // The action is the authority in `tg://resolve?…` and the path in
    // `tg:/resolve?…` — the same link, written the way a URI normaliser leaves
    // it. Both forms arrive: Android hands over the first, and a router that
    // took the link as a location hands over the second. Matching only the
    // authority meant the normalised form parsed as nothing at all.
    final raw = uri.host.isEmpty ? uri.path : uri.host;
    final action = raw.replaceAll(RegExp(r'^/+|/+$'), '').toLowerCase();

    switch (action) {
      case 'resolve':
        final domain = params['domain'];
        if (domain == null || !isUsername(domain)) return null;
        final post = int.tryParse(params['post'] ?? '');
        return post == null || post <= 0
            ? TelegramChannelLink(domain)
            : TelegramPostLink(domain, post);

      case 'privatepost':
        final channel = int.tryParse(params['channel'] ?? '');
        final post = int.tryParse(params['post'] ?? '');
        if (channel == null || post == null || post <= 0) return null;
        return TelegramPrivatePostLink(channel, post);

      case 'join':
        final invite = params['invite'];
        return invite == null || invite.isEmpty
            ? null
            : TelegramInviteLink(invite);

      default:
        return null;
    }
  }

  /// The last path segment that is a positive number, if any.
  static int? _lastNumber(Iterable<String> segments) {
    int? found;
    for (final segment in segments) {
      final value = int.tryParse(segment);
      if (value == null) return found;
      if (value > 0) found = value;
    }
    return found;
  }

  /// Telegram's own rule for a username: 5–32 characters, letters, digits and
  /// underscores, starting with a letter.
  ///
  /// Checked rather than assumed, because everything that is not a reserved
  /// word reaches this — and `t.me/1234` is not a channel called "1234".
  static bool isUsername(String value) =>
      RegExp(r'^[A-Za-z][A-Za-z0-9_]{3,31}$').hasMatch(value);
}
