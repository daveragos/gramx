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

/// `t.me/c/1234567890` — a private channel with no post singled out.
///
/// The same address as [TelegramPrivatePostLink] without the message, which
/// Telegram emits when somebody copies a link to the channel rather than to
/// one of its posts. It used to parse as nothing, because the message id was
/// read as required — so the one link shape that names a channel you are
/// already in was the one gramX handed back to Telegram.
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

/// `tg://search?query=%23flutter` — Telegram's global hashtag search.
///
/// gramX already had the screen; it just had no link into it. The tag
/// keeps its leading `#`, because that is what the search field expects and
/// re-adding it at the other end is a second place to get it wrong.
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
  static const hosts = {'t.me', 'telegram.me', 'telegram.dog'};

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

  /// Whether [uri] is Telegram's at all — its scheme or its host, nothing
  /// more.
  ///
  /// Deliberately weaker than [parse]. It answers the question a *gate* asks
  /// ("is this ours to think about?") rather than the one a router asks
  /// ("where does it go?"), and the two used to be the same call: a link was
  /// dropped on arrival unless the local parser could already route it, which
  /// meant TDLib never got to see the shapes only TDLib knows. Cheap enough to
  /// run on the link stream, and wrong only in the direction that keeps a link
  /// alive long enough to be asked about properly.
  static bool couldBeTelegram(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'tg') return true;
    if (scheme != 'http' && scheme != 'https') return false;
    return hosts.contains(
      uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), ''),
    );
  }

  /// What [uri] points at, or null when it is not a Telegram link this app can
  /// open.
  static TelegramLink? parse(Uri uri) => switch (uri.scheme.toLowerCase()) {
    'https' || 'http' => _parseWeb(uri),
    'tg' => _parseScheme(uri),
    _ => null,
  };

  static TelegramLink? _parseWeb(Uri uri) {
    // `www.` is an alias on every one of these, not a fourth host. Listing
    // `www.t.me` as its own entry covered one third of the cases.
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    if (!hosts.contains(host)) return null;

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
      // No message is a link to the channel itself, not a broken link to a
      // post. A forum topic id lands here too — gramX has no topics,
      // so it opens the channel rather than refusing the link.
      return message == null
          ? TelegramPrivateChannelLink(group)
          : TelegramPrivatePostLink(group, message);
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
  static TelegramLink? _publicLink(String rawName, List<String> rest) {
    // Telegram writes a handle both ways, and `t.me/@durov` redirects to
    // `t.me/durov`. The sigil is punctuation, not part of the name.
    final name = _stripHandleSigil(rawName);
    if (!isUsername(name)) return null;

    // The *last* number is the message. A forum link carries the topic first,
    // and gramX has no topics yet — the post still opens.
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

      // Telegram's global hashtag search. `q` is the older spelling of the
      // same parameter and both are still emitted.
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

  /// Telegram's own rule for a username: 5–32 characters, letters, digits and
  /// underscores, starting with a letter.
  ///
  /// Checked rather than assumed, because everything that is not a reserved
  /// word reaches this — and `t.me/1234` is not a channel called "1234".
  static bool isUsername(String value) =>
      RegExp(r'^[A-Za-z][A-Za-z0-9_]{3,31}$').hasMatch(value);

  static String _stripHandleSigil(String value) =>
      value.startsWith('@') ? value.substring(1) : value;

  /// A search query as a `#tag`, or null when it is not one.
  ///
  /// Telegram sends the tag with or without its `#` depending on which client
  /// wrote the link, so both are accepted and the sigil is put back — one
  /// spelling reaches the search field, whichever arrived.
  static String? normaliseHashtag(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final core = _stripHandleSigil(
      trimmed.startsWith('#') ? trimmed.substring(1) : trimmed,
    );
    // A phrase is a text search, not a hashtag, and gramX's hashtag screen
    // would search for something nobody can have tagged.
    if (core.isEmpty || core.contains(RegExp(r'\s'))) return null;
    return '#$core';
  }
}
