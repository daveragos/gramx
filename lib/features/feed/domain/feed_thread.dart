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

  /// Every post in the thread, root first — the order it was written in.
  List<Post> get allPosts => [root, ...replies];

  /// The post that most recently arrived.
  ///
  /// This is what the collapsed card shows. A thread surfaces in the feed
  /// *because* of its newest post, so showing the root instead displayed an
  /// old timestamp and hid the new message behind an expand-and-scroll.
  Post get latest => replies.isEmpty ? root : replies.last;

  /// Everything except [latest], oldest first — the context behind it.
  List<Post> get earlier =>
      replies.isEmpty ? const [] : allPosts.sublist(0, allPosts.length - 1);

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

/// One row of the feed: a thread, and where it came from.
///
/// The feed is not purely chronological any more — see [buildFeedEntries] — so
/// a row has to be able to say "this is older, and you hadn't read it", or a
/// three-day-old post appearing between two fresh ones just looks like a bug.
class FeedEntry {
  final FeedThread thread;

  /// True when this row was lifted out of the unread backlog rather than
  /// arriving in its chronological place.
  final bool isBacklog;

  const FeedEntry({required this.thread, this.isBacklog = false});
}

/// How many chronological rows sit between two backlog rows.
///
/// One in four: enough that a backlog actually shrinks while reading, few
/// enough that the feed still reads as "what's new" rather than as a chore
/// list. The first slot is never a backlog row — the top of the feed is the
/// newest post, always.
const int kDefaultBlendEvery = 4;

/// Builds the feed's rows: newest first, with unread backlog woven in.
///
/// [posts] is the merged feed, any order — it is sorted here. [backlogIds] are
/// posts the unread sweep pulled from behind each channel's read cursor; they
/// are lifted out of their chronological position rather than copied, so the
/// same post never appears twice.
///
/// Deliberately a pure function of a *fixed* backlog set. Picking the oldest
/// unread out of whatever happens to be loaded would reshuffle the top of the
/// feed every time pagination brought older posts in, which is the one thing a
/// reading surface must never do.
List<FeedEntry> buildFeedEntries(
  List<Post> posts, {
  Set<String> backlogIds = const {},
  int blendEvery = kDefaultBlendEvery,
}) {
  if (posts.isEmpty) return const [];

  final backlogPosts = <Post>[];
  final freshPosts = <Post>[];
  for (final post in posts) {
    // Reading a backlog post does not move it. The set only changes on a
    // refresh, so nothing shifts under the reader's thumb mid-scroll — the
    // same rule the "new posts" pill follows.
    if (backlogIds.contains(post.id)) {
      backlogPosts.add(post);
    } else {
      freshPosts.add(post);
    }
  }

  // Threads are grouped within each pool, never across: a backlog post and a
  // fresh one from the same channel are two different reading moments.
  final fresh = groupIntoThreads(freshPosts);
  final backlog = groupIntoThreads(backlogPosts)
    // Oldest first — the backlog is read forwards, the way it was written.
    ..sort((a, b) => a.lastActivity.compareTo(b.lastActivity));

  if (backlog.isEmpty) {
    return [for (final thread in fresh) FeedEntry(thread: thread)];
  }
  if (fresh.isEmpty) {
    // Nothing new at all. Falling back to newest-first keeps the feed's one
    // promise — the top is the most recent thing — rather than opening on
    // something from last week.
    final newestFirst = backlog.reversed;
    return [
      for (final thread in newestFirst) FeedEntry(thread: thread, isBacklog: true),
    ];
  }

  final entries = <FeedEntry>[];
  final remaining = List<FeedThread>.from(backlog);
  var sinceBacklog = 0;

  for (final thread in fresh) {
    entries.add(FeedEntry(thread: thread));
    sinceBacklog++;

    if (sinceBacklog >= blendEvery - 1 && remaining.isNotEmpty) {
      entries.add(FeedEntry(thread: remaining.removeAt(0), isBacklog: true));
      sinceBacklog = 0;
    }
  }

  // Whatever is left goes on the end rather than being dropped: an unread post
  // the reader never sees is worse than one late in the list.
  for (final thread in remaining) {
    entries.add(FeedEntry(thread: thread, isBacklog: true));
  }

  return entries;
}
