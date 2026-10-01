import 'package:flutter/foundation.dart';

import 'package:gramx/core/telegram/telegram_ids.dart';

/// What a Telegram link points at. Parsing makes no requests; resolving a
/// username to a chat id happens later, when the link is opened.
@immutable
sealed class TelegramLink {
  const TelegramLink();
}

/// `t.me/durov`: a channel, group or person, which only Telegram can tell.
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

/// `t.me/durov/123`: one post in a public channel.
class TelegramPostLink extends TelegramLink {
  final String username;

  /// The server message id from the link. See [tdlibMessageId].
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

/// `t.me/c/1234567890/123`: one post in a private channel (members only).
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

/// `t.me/c/1234567890`: a private channel with no post.
class TelegramPrivateChannelLink extends TelegramLink {
  final int supergroupId;

  const TelegramPrivateChannelLink(this.supergroupId);

  /// The chat id TDLib knows this supergroup by.
  int get chatId => int.parse('-100$supergroupId');

  @override
  bool operator ==(Object other) =>
      other is TelegramPrivateChannelLink && other.supergroupId == supergroupId;

  @override
  int get hashCode => supergroupId.hashCode;

  @override
  String toString() => 'TelegramPrivateChannelLink($supergroupId)';
}

/// `tg://search?query=%23flutter`: a hashtag search. [tag] keeps its `#`.
class TelegramHashtagLink extends TelegramLink {
  final String tag;

  const TelegramHashtagLink(this.tag);

  @override
  bool operator ==(Object other) =>
      other is TelegramHashtagLink && other.tag == tag;

  @override
  int get hashCode => tag.hashCode;

  @override
  String toString() => 'TelegramHashtagLink($tag)';
}

/// `t.me/+AbCdEf` or `t.me/joinchat/AbCdEf`: an invite link.
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
  static const hosts = {'t.me', 'telegram.me', 'telegram.dog'};

  /// First path segments Telegram reserves for features, not usernames.
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

  /// Whether [uri] has a Telegram scheme or host. Looser than [parse], so
  /// link shapes only TDLib understands still reach the resolver.
  static bool couldBeTelegram(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'tg') return true;
    if (scheme != 'http' && scheme != 'https') return false;
    return hosts.contains(
      uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), ''),
    );
  }

  /// What [uri] points at, or null if this app cannot open it.
  static TelegramLink? parse(Uri uri) => switch (uri.scheme.toLowerCase()) {
    'https' || 'http' => _parseWeb(uri),
    'tg' => _parseScheme(uri),
    _ => null,
  };

  static TelegramLink? _parseWeb(Uri uri) {
    // `www.` is an alias on every host.
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    if (!hosts.contains(host)) return null;

    final segments = [
      for (final segment in uri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    if (segments.isEmpty) return null;

    final first = segments.first;

    // `t.me/s/name` is a channel's web preview and opens the same channel.
    if (first == 's' && segments.length >= 2) {
      return _publicLink(segments[1], segments.skip(2).toList());
    }

    // `t.me/c/<supergroup>/<message>`, optionally with a topic id between.
    if (first == 'c') {
      final group = segments.length >= 2 ? int.tryParse(segments[1]) : null;
      if (group == null) return null;
      final message = _lastNumber(segments.skip(2));
      // Topics are not supported, so a lone topic id opens the channel.
      return message == null
          ? TelegramPrivateChannelLink(group)
          : TelegramPrivatePostLink(group, message);
    }

    if (first == 'joinchat' && segments.length >= 2) {
      return TelegramInviteLink(segments[1]);
    }
    // `t.me/+hash`. All digits means a phone number contact link instead.
    if (first.startsWith('+')) {
      final hash = first.substring(1);
      if (hash.isEmpty || int.tryParse(hash) != null) return null;
      return TelegramInviteLink(hash);
    }

    if (reserved.contains(first.toLowerCase())) return null;

    return _publicLink(first, segments.skip(1).toList());
  }

  /// A username, optionally followed by a topic id and a post id.
  static TelegramLink? _publicLink(String rawName, List<String> rest) {
    // `t.me/@durov` redirects to `t.me/durov`.
    final name = _stripHandleSigil(rawName);
    if (!isUsername(name)) return null;

    // The last number is the message; a forum link has the topic first.
    final message = _lastNumber(rest);
    if (message == null) {
      // An unknown trailing segment means an unsupported link shape.
      return rest.isEmpty ? TelegramChannelLink(name) : null;
    }
    return TelegramPostLink(name, message);
  }

  static TelegramLink? _parseScheme(Uri uri) {
    final params = uri.queryParameters;

    // The action is the host in `tg://resolve?…` but the path in the
    // normalised `tg:/resolve?…` that the router receives.
    final raw = uri.host.isEmpty ? uri.path : uri.host;
    final action = raw.replaceAll(RegExp(r'^/+|/+$'), '').toLowerCase();

    switch (action) {
      case 'resolve':
        final domain = _stripHandleSigil(params['domain'] ?? '');
        if (!isUsername(domain)) return null;
        final post = int.tryParse(params['post'] ?? '');
        return post == null || post <= 0
            ? TelegramChannelLink(domain)
            : TelegramPostLink(domain, post);

      case 'privatepost':
        final channel = int.tryParse(params['channel'] ?? '');
        final post = int.tryParse(params['post'] ?? '');
        if (channel == null || post == null || post <= 0) return null;
        return TelegramPrivatePostLink(channel, post);

      // `q` is an older spelling of `query`; both are still emitted.
      case 'search':
        final tag = normaliseHashtag(params['query'] ?? params['q'] ?? '');
        return tag == null ? null : TelegramHashtagLink(tag);

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

  /// Whether [value] is a valid username: 4 to 32 letters, digits and
  /// underscores, starting with a letter.
  static bool isUsername(String value) =>
      RegExp(r'^[A-Za-z][A-Za-z0-9_]{3,31}$').hasMatch(value);

  static String _stripHandleSigil(String value) =>
      value.startsWith('@') ? value.substring(1) : value;

  /// A search query as a `#tag` (links include the `#` or not), or null.
  static String? normaliseHashtag(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final core = _stripHandleSigil(
      trimmed.startsWith('#') ? trimmed.substring(1) : trimmed,
    );
    // A phrase with spaces is a text search, not a hashtag.
    if (core.isEmpty || core.contains(RegExp(r'\s'))) return null;
    return '#$core';
  }
}
