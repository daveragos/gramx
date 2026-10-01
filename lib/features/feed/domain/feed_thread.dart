import 'package:gramx/features/feed/domain/post.dart';

/// A post plus the follow-ups its channel posted in reply to it, so a burst
/// of related messages takes one slot in the feed.
class FeedThread {
  final Post root;

  /// Follow-ups, oldest first.
  final List<Post> replies;

  const FeedThread({required this.root, this.replies = const []});

  bool get hasReplies => replies.isNotEmpty;

  /// Every post in the thread, root first.
  List<Post> get allPosts => [root, ...replies];

  /// The newest post, which the collapsed card shows.
  Post get latest => replies.isEmpty ? root : replies.last;

  /// Everything except [latest], oldest first.
  List<Post> get earlier =>
      replies.isEmpty ? const [] : allPosts.sublist(0, allPosts.length - 1);

  /// Whether to draw "show earlier posts". Each reply already shows what it
  /// answers, so hiding a single post hides nothing new; two or more do.
  bool get hasEarlierToBeShown => earlier.length >= 2;

  /// The newest post's time, so a follow-up to an old post still surfaces.
  DateTime get lastActivity {
    var latest = root.publishedAt;
    for (final reply in replies) {
      if (reply.publishedAt.isAfter(latest)) latest = reply.publishedAt;
    }
    return latest;
  }
}

/// Collapses a flat post list into threads. A post joins a thread when it
/// replies to a loaded post from the same channel; chains fold to the root.
List<FeedThread> groupIntoThreads(List<Post> posts) {
  if (posts.length < 2) {
    return [for (final post in posts) FeedThread(root: post)];
  }

  // Message ids are only unique within a chat.
  final byKey = <String, Post>{
    for (final post in posts) '${post.chatId}_${post.messageId}': post,
  };

  String? parentKeyOf(Post post) {
    final replyTo = post.replyToMessageId;
    if (replyTo == null || replyTo == post.messageId) return null;
    // A reply into another chat is a quote, not a thread.
    if (post.replyToChatId != null && post.replyToChatId != post.chatId) {
      return null;
    }
    final key = '${post.chatId}_$replyTo';
    return byKey.containsKey(key) ? key : null;
  }

  /// Walks up to the root of a reply chain. A cycle in malformed data makes
  /// the post its own root, or the whole cycle would drop out of the feed.
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

  // Show the posts of a group whose root is missing as top-level posts.
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

/// How close together a channel's posts must be to count as one burst.
const Duration kBurstWindow = Duration(minutes: 10);

/// Rows that must sit between two posts of a burst.
const int kBurstSpacing = 2;

/// Spreads a channel's bursts of unrelated posts out across the feed.
///
/// A thread is held back only when its channel appeared within the last
/// [spacing] rows and within [window] of this post. Order within a channel
/// is kept and nothing is dropped.
List<FeedThread> scatterChannelBursts(
  List<FeedThread> threads, {
  Duration window = kBurstWindow,
  int spacing = kBurstSpacing,
}) {
  if (threads.length < 3 || spacing < 1) return threads;

  final out = <FeedThread>[];
  final held = <FeedThread>[];
  final lastRow = <int, int>{};
  final lastAt = <int, DateTime>{};

  /// Whether an earlier thread from the same channel is still held, which
  /// keeps a channel's posts in order. [heldIndex] is the thread's own place
  /// in the queue, or -1.
  bool queued(FeedThread thread, int heldIndex) {
    final limit = heldIndex < 0 ? held.length : heldIndex;
    for (var i = 0; i < limit; i++) {
      if (held[i].root.chatId == thread.root.chatId) return true;
    }
    return false;
  }

  bool eligible(FeedThread thread, int heldIndex) {
    if (queued(thread, heldIndex)) return false;

    final chatId = thread.root.chatId;
    final row = lastRow[chatId];
    if (row == null) return true;
    // Far enough down the feed that the run is already broken.
    if (out.length - row > spacing) return true;
    // Same channel nearby, but written far enough apart to stand alone.
    return lastAt[chatId]!.difference(thread.lastActivity).abs() > window;
  }

  void emit(FeedThread thread) {
    out.add(thread);
    lastRow[thread.root.chatId] = out.length - 1;
    lastAt[thread.root.chatId] = thread.lastActivity;
  }

  /// The first held thread that may go back in, or -1.
  int nextAdmissible() {
    for (var i = 0; i < held.length; i++) {
      if (eligible(held[i], i)) return i;
    }
    return -1;
  }

  /// Lets held threads back in once the gap before them is wide enough.
  void drain() {
    while (true) {
      final index = nextAdmissible();
      if (index < 0) return;
      emit(held.removeAt(index));
    }
  }

  for (final thread in threads) {
    if (eligible(thread, -1)) {
      emit(thread);
      drain();
    } else {
      held.add(thread);
    }
  }

  // Nothing left to interleave with, so append the rest.
  while (held.isNotEmpty) {
    final index = nextAdmissible();
    emit(held.removeAt(index < 0 ? 0 : index));
  }

  return out;
}

/// One row of the feed. [isBacklog] isn't drawn; it is for testing.
class FeedEntry {
  final FeedThread thread;

  /// Whether this row was lifted out of the unread backlog.
  final bool isBacklog;

  const FeedEntry({required this.thread, this.isBacklog = false});
}

/// One row in every [kDefaultBlendEvery] is an unread post from further back.
/// The first row is always the newest post.
const int kDefaultBlendEvery = 3;

/// Posts at the top of the feed that count as new rather than backlog.
const int kFreshWindow = 15;

/// Orders unread posts for the mix: channels in rotation, oldest first
/// within each.
List<String> orderBacklogIds(List<Post> posts) {
  final byChannel = <int, List<Post>>{};
  for (final post in posts) {
    byChannel.putIfAbsent(post.chatId, () => <Post>[]).add(post);
  }
  for (final channelPosts in byChannel.values) {
    channelPosts.sort((a, b) => a.publishedAt.compareTo(b.publishedAt));
  }

  // The channel with the oldest unread post leads each round.
  final queues = byChannel.values.toList()
    ..sort((a, b) => a.first.publishedAt.compareTo(b.first.publishedAt));

  final ordered = <String>[];
  var taken = true;
  var round = 0;
  while (taken) {
    taken = false;
    for (final queue in queues) {
      if (round >= queue.length) continue;
      ordered.add(queue[round].id);
      taken = true;
    }
    round++;
  }
  return ordered;
}

/// Unread posts older than the newest [freshWindow], ordered for the mix.
List<String> selectBacklogCandidates(
  List<Post> posts, {
  int freshWindow = kFreshWindow,
}) {
  if (posts.length <= freshWindow) return const [];

  final newestFirst = List<Post>.from(posts)
    ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

  final candidates = [
    for (final post in newestFirst.skip(freshWindow))
      if (!post.isRead) post,
  ];
  return orderBacklogIds(candidates);
}

/// Builds the feed's rows: newest first, with unread backlog woven in.
/// [backlogOrder] is the caller's append-only pool, so paging doesn't
/// reshuffle rows on screen.
List<FeedEntry> buildFeedEntries(
  List<Post> posts, {
  List<String> backlogOrder = const [],
  int blendEvery = kDefaultBlendEvery,
}) {
  if (posts.isEmpty) return const [];

  final chronological = scatterChannelBursts(groupIntoThreads(posts));
  if (backlogOrder.isEmpty || blendEvery < 2) {
    return [for (final thread in chronological) FeedEntry(thread: thread)];
  }

  // Under one full cadence there is nothing to weave into.
  final slots = chronological.length ~/ blendEvery;
  if (slots == 0) {
    return [for (final thread in chronological) FeedEntry(thread: thread)];
  }

  final loaded = {for (final post in posts) post.id};
  final lifted = <String>{};
  for (final id in backlogOrder) {
    if (lifted.length >= slots) break;
    if (loaded.contains(id)) lifted.add(id);
  }
  if (lifted.isEmpty) {
    return [for (final thread in chronological) FeedEntry(thread: thread)];
  }

  final backlogPosts = <Post>[];
  final freshPosts = <Post>[];
  for (final post in posts) {
    if (lifted.contains(post.id)) {
      backlogPosts.add(post);
    } else {
      freshPosts.add(post);
    }
  }

  final fresh = scatterChannelBursts(groupIntoThreads(freshPosts));
  final position = {
    for (var i = 0; i < backlogOrder.length; i++) backlogOrder[i]: i,
  };
  final backlog = groupIntoThreads(backlogPosts)
    ..sort(
      (a, b) => (position[a.root.id] ?? 1 << 30).compareTo(
        position[b.root.id] ?? 1 << 30,
      ),
    );

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

  for (final thread in remaining) {
    entries.add(FeedEntry(thread: thread, isBacklog: true));
  }

  return entries;
}
