import 'dart:collection';

/// Posts the user has seen that Telegram's read cursor doesn't cover yet.
///
/// The cursor only moves over seen posts (see [readableUpTo]), since the
/// feed is newest first. A post seen above an unseen one is kept here until
/// the cursor catches up; Telegram has no per-post seen state.
class SeenPosts {
  final Map<int, SplayTreeSet<int>> _byChat;

  SeenPosts([Map<int, Iterable<int>>? byChat])
    : _byChat = {
        for (final entry in (byChat ?? const {}).entries)
          entry.key: SplayTreeSet.of(entry.value),
      };

  /// Most ids kept per chat; the oldest are dropped first.
  static const int maxPerChat = 300;

  bool get isEmpty => _byChat.isEmpty;

  /// Every remembered post, as `chatId_messageId`.
  Set<String> get postIds => {
    for (final entry in _byChat.entries)
      for (final id in entry.value) '${entry.key}_$id',
  };

  Set<int> idsIn(int chatId) => {...?_byChat[chatId]};

  bool contains(int chatId, int messageId) =>
      _byChat[chatId]?.contains(messageId) ?? false;

  /// Remembers a post and returns whether it was new.
  bool add(int chatId, int messageId) {
    final ids = _byChat.putIfAbsent(chatId, SplayTreeSet.new);
    if (!ids.add(messageId)) return false;
    while (ids.length > maxPerChat) {
      ids.remove(ids.first);
    }
    return true;
  }

  /// Forgets everything at or below [cursor]. Returns whether anything was
  /// forgotten.
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

  /// Reads what [toJson] wrote, or an empty record for anything else.
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

/// One message above a chat's read cursor. [isShown] is false for messages
/// the feed doesn't draw.
typedef UnreadMessage = ({int id, int albumId, bool isShown});

/// How far a chat's read cursor can move without passing an unseen message.
/// Unshown messages pass, as do album members once the album was seen.
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
