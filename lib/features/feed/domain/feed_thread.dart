import 'package:gramx/features/feed/domain/post.dart';

/// A post plus the follow-ups the same channel posted in reply to it.
///
/// Channels often post a burst of related messages — a correction, a second
/// screenshot, a "part 2" — each replying to the first. As separate cards they
/// bury everyone else's posts under one channel. Collapsed into a thread, the
/// channel takes one slot and the reader can open the rest.
class FeedThread {
  final Post root;

  /// Follow-ups, oldest first, so the thread reads in the order it was written.
  final List<Post> replies;

  const FeedThread({required this.root, this.replies = const []});

  bool get hasReplies => replies.isNotEmpty;

  /// Every post in the thread, root first.
  List<Post> get allPosts => [root, ...replies];

  /// The most recent post anywhere in the thread. A thread is as fresh as its
  /// newest message, so a follow-up to an old post still surfaces.
  DateTime get lastActivity {
    var latest = root.publishedAt;
    for (final reply in replies) {
      if (reply.publishedAt.isAfter(latest)) latest = reply.publishedAt;
    }
    return latest;
  }
}

/// Collapses a flat post list into threads.
///
/// A post joins a thread when it replies to another post **from the same
/// channel that is also in this list**. Both halves matter:
///
/// * cross-channel replies aren't threads, they're quotes — the reply preview
///   on the card already shows that context;
/// * if the parent isn't in the list, the reply has nothing to collapse under
///   and must stand on its own, or it would vanish from the feed entirely.
///
/// Reply chains fold all the way to their root, so A ← B ← C is one thread of
/// three rather than two threads.
List<FeedThread> groupIntoThreads(List<Post> posts) {
  if (posts.length < 2) {
    return [for (final post in posts) FeedThread(root: post)];
  }

  // Key on chat *and* message id: message ids are only unique within a chat.
  final byKey = <String, Post>{
    for (final post in posts) '${post.chatId}_${post.messageId}': post,
  };

  String? parentKeyOf(Post post) {
    final replyTo = post.replyToMessageId;
    if (replyTo == null || replyTo == post.messageId) return null;
    final key = '${post.chatId}_$replyTo';
    return byKey.containsKey(key) ? key : null;
  }

  /// Walks up to the root of a reply chain.
  ///
  /// A cycle in malformed data makes the post its own root rather than
  /// resolving into the loop. Returning a key from inside the cycle would leave
  /// every member pointing at another member, so none would be a root and the
  /// whole group would drop out of the feed.
  String rootKeyOf(Post post) {
    final startKey = '${post.chatId}_${post.messageId}';
    var current = post;
    final seen = <String>{startKey};

    while (true) {
      final parentKey = parentKeyOf(current);
      if (parentKey == null) break;
      if (!seen.add(parentKey)) return startKey;
      current = byKey[parentKey]!;
    }
    return '${current.chatId}_${current.messageId}';
  }

  final repliesByRoot = <String, List<Post>>{};
  final roots = <Post>[];

  for (final post in posts) {
    final key = '${post.chatId}_${post.messageId}';
    final rootKey = rootKeyOf(post);
    if (rootKey == key) {
      roots.add(post);
    } else {
      repliesByRoot.putIfAbsent(rootKey, () => []).add(post);
    }
  }

  // Safety net: a reply group whose root never materialised would otherwise be
  // dropped silently. Losing posts is far worse than showing one uncollapsed,
  // so anything orphaned is promoted back to a top-level post.
  final rootKeys = {for (final r in roots) '${r.chatId}_${r.messageId}'};
  for (final entry in repliesByRoot.entries.toList()) {
    if (rootKeys.contains(entry.key)) continue;
    roots.addAll(entry.value);
    repliesByRoot.remove(entry.key);
  }

  final threads = [
    for (final root in roots)
      FeedThread(
        root: root,
        replies: (repliesByRoot['${root.chatId}_${root.messageId}'] ?? [])
          ..sort((a, b) => a.publishedAt.compareTo(b.publishedAt)),
      ),
  ];

  threads.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
  return threads;
}
