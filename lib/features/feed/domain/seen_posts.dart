import 'dart:collection';

/// Posts the reader has seen that Telegram's read cursor does not cover yet.
///
/// Telegram keeps read state as one cursor per chat: everything at or below
/// it is read. A feed shows a channel's newest post first, so a reader who
/// sees it has not necessarily seen the ones before it — and moving the
/// cursor to the newest post would mark those read too, and the feed, which
/// hides what is read, would never show them. So the cursor only moves over
/// posts the reader has actually seen (see [readableUpTo]), and a post seen
/// above an unseen one is remembered here instead, until the cursor catches up
/// and it can be forgotten.
///
/// Telegram has no per-post "seen" of its own for a client to read back —
/// view counts are totals, not a record of this reader — which is why this
/// lives on the phone.
class SeenPosts {
  final Map<int, SplayTreeSet<int>> _byChat;

  SeenPosts([Map<int, Iterable<int>>? byChat])
    : _byChat = {
        for (final entry in (byChat ?? const {}).entries)
          entry.key: SplayTreeSet.of(entry.value),
      };

  /// Most ids kept per chat. A reader who sees three hundred posts of one
  /// channel without the cursor moving has skipped something that will never
  /// load; the oldest are dropped first.
  static const int maxPerChat = 300;

  bool get isEmpty => _byChat.isEmpty;

  /// Every remembered post, as `chatId_messageId`.
  Set<String> get postIds => {
    for (final entry in _byChat.entries)
      for (final id in entry.value) '${entry.key}_$id',
  };

  /// The remembered ids of one chat, oldest first.
  Set<int> idsIn(int chatId) => {...?_byChat[chatId]};

  bool contains(int chatId, int messageId) =>
      _byChat[chatId]?.contains(messageId) ?? false;

  /// Remembers a post. Returns whether it was new.
  bool add(int chatId, int messageId) {
    final ids = _byChat.putIfAbsent(chatId, SplayTreeSet.new);
    if (!ids.add(messageId)) return false;
    while (ids.length > maxPerChat) {
      ids.remove(ids.first);
    }
    return true;
  }

  /// Forgets everything at or below [cursor]: Telegram's cursor covers it now.
  /// Returns whether anything was forgotten.
  bool settle(int chatId, int cursor) {
    final ids = _byChat[chatId];
    if (ids == null) return false;
    final before = ids.length;
    ids.removeWhere((id) => id <= cursor);
    if (ids.isEmpty) _byChat.remove(chatId);
    return ids.length != before;
  }

  Map<String, List<int>> toJson() => {
    for (final entry in _byChat.entries)
      entry.key.toString(): entry.value.toList(),
  };

  /// Reads what [toJson] wrote. Anything else is an empty record rather than
  /// an error: losing it costs a few posts shown twice, not the feed.
  factory SeenPosts.fromJson(Object? decoded) {
    if (decoded is! Map) return SeenPosts();
    final byChat = <int, List<int>>{};
    for (final entry in decoded.entries) {
      final chatId = int.tryParse(entry.key.toString());
      final ids = entry.value;
      if (chatId == null || ids is! List) continue;
      byChat[chatId] = [
        for (final id in ids)
          if (id is int) id,
      ];
    }
    return SeenPosts(byChat);
  }
}

/// One message above a chat's read cursor, as far as the read rule cares.
///
/// [albumId] is the media album it belongs to, or 0. [isShown] is whether the
/// feed draws it for the reader to see at all: a notice about the chat is
/// dropped, and a post this account sent is its own reader.
typedef UnreadMessage = ({int id, int albumId, bool isShown});

/// How far a chat's read cursor can move without passing a message the reader
/// has not seen.
///
/// Walks [unread] oldest first from [cursor]. A message is passed if it was
/// [seen], if it is never shown, or if it belongs to an album whose first
/// message was seen — the feed draws an album as one post, keyed by its first
/// message. The walk stops at the first message that is none of those.
int readableUpTo({
  required int cursor,
  required List<UnreadMessage> unread,
  required Set<int> seen,
}) {
  final ordered = [...unread]..sort((a, b) => a.id.compareTo(b.id));
  final seenAlbums = <int>{};
  var upTo = cursor;
  for (final message in ordered) {
    if (message.id <= cursor) continue;
    final wasSeen = seen.contains(message.id);
    if (wasSeen && message.albumId != 0) seenAlbums.add(message.albumId);
    final passes =
        !message.isShown ||
        wasSeen ||
        (message.albumId != 0 && seenAlbums.contains(message.albumId));
    if (!passes) break;
    upTo = message.id;
  }
  return upTo;
}
