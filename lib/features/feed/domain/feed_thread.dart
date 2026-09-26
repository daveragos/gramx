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

  /// Whether the "show earlier posts" control is worth drawing.
  ///
  /// Every post in a thread is a reply to the one before it, and a reply
  /// already draws what it answers — as a quoted passage above it, or as a
  /// quote card under its own words. So a thread hiding exactly **one** post
  /// is hiding a post that is on screen anyway, and the control offers to
  /// reveal what the reader can already read. Two or more is the point at
  /// which there is genuinely something behind the card.
  bool get hasEarlierToBeShown => earlier.length >= 2;

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
    // A reply into another chat is a quote, not a thread — and message ids are
    // only unique within a chat, so treating one as a parent can collapse two
    // unrelated posts into the same card.
    if (post.replyToChatId != null && post.replyToChatId != post.chatId) {
      return null;
    }
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

/// How close together two posts have to be before they read as one burst.
///
/// A channel posting every hour is an active channel; a channel posting four
/// times inside ten minutes is one thought that arrived in pieces. Only the
/// second is noise, and only the second gets spread out.
const Duration kBurstWindow = Duration(minutes: 10);

/// Rows that must sit between two posts from the same channel before the
/// second one is allowed back in.
///
/// Two is the smallest number that breaks a run: at one, a burst still reads
/// as alternating stripes of the same channel.
const int kBurstSpacing = 2;

/// Spreads a channel's simultaneous posts out across the feed.
///
/// [groupIntoThreads] collapses follow-ups that *reply* to each other, which is
/// the tidy case. The untidy one is a channel that fires off three or four
/// unrelated posts within a minute — no replies, nothing to collapse, and no
/// reason for the reader to see them as a group. Chronologically they land as
/// a solid block, and one channel takes over the top of the feed.
///
/// The rule is deliberately narrow, because the alternative — ranking the feed
/// — would stop it being chronological at all. A thread is held back only when
/// **both** are true: the same channel appeared within the last [spacing] rows,
/// *and* this post was written within [window] of that one. A channel that
/// posts steadily through the day is never touched; a burst is broken up and
/// its members re-enter one at a time, as soon as there is something else
/// between them.
///
/// Order within a channel is never changed — a burst's second post still comes
/// before its third. Nothing is dropped: whatever is still held at the end is
/// appended, so the list that comes out has exactly the threads that went in.
///
/// The cost, which is real: where a held post lands depends on what is below
/// it, so paging in older posts gives a burst something new to be spread
/// between and can move it down a row or two. That is the one thing the blend
/// deliberately avoids, and it is accepted here because the alternative is the
/// burst standing as a block at the top of the feed, which is what this is
/// for. It only ever moves *down* and only within a burst, so nothing the
/// reader has already read changes place.
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

  /// Whether an earlier-queued thread from the same channel is still waiting.
  ///
  /// This is what keeps a channel's own posts in order. Without it the third
  /// post of a burst could satisfy the time rule against the *first* — which
  /// is by then the last one emitted — and overtake the second, which was
  /// still held. A burst read out of sequence is a worse bug than a burst.
  ///
  /// [heldIndex] is where the thread itself sits in the queue, so it only
  /// looks at what is genuinely ahead of it; -1 for one arriving fresh.
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
    // Same channel, close by — but written far enough apart to be its own
    // post rather than part of a burst.
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

  /// Lets held threads back in the moment the gap in front of them is wide
  /// enough. Self-limiting: emitting one moves that channel's marker to the
  /// row just written, so its next one is held again.
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

  // Nothing left to interleave with. Spacing is a preference, not a promise:
  // losing a post to keep it would be much worse.
  while (held.isNotEmpty) {
    final index = nextAdmissible();
    emit(held.removeAt(index < 0 ? 0 : index));
  }

  return out;
}

/// One row of the feed: a thread, and whether it came out of the backlog.
///
/// The flag is not drawn — an unread post is an unread post, and labelling
/// some of them "older" only tells the reader something the timestamp already
/// says. It exists so the blend can be reasoned about and tested.
class FeedEntry {
  final FeedThread thread;

  /// True when this row was lifted out of the unread backlog rather than
  /// arriving in its chronological place.
  final bool isBacklog;

  const FeedEntry({required this.thread, this.isBacklog = false});
}

/// One row in every [kDefaultBlendEvery] is an unread post from further back.
///
/// One in three: enough that a backlog visibly shrinks while reading, few
/// enough that the feed still opens on what's new. The first row is never a
/// backlog row — the top of the feed is the newest post, always.
const int kDefaultBlendEvery = 3;

/// Posts at the very top of the feed that count as "new" rather than backlog.
///
/// Everything unread behind this window is a candidate for the mix, whether it
/// arrived from the unread sweep or was already loaded: an unread post from
/// three days ago is exactly as unread as one from three hours ago.
const int kFreshWindow = 15;

/// Orders unread posts for the mix: a different channel each time, oldest
/// first within a channel.
///
/// Straight chronological order clusters — a channel that went quiet a week
/// ago contributes a run of consecutive posts, and the mix reads as that one
/// channel rather than as a backlog. Taking one per channel in rotation keeps
/// consecutive backlog rows from the same source apart.
List<String> orderBacklogIds(List<Post> posts) {
  final byChannel = <int, List<Post>>{};
  for (final post in posts) {
    byChannel.putIfAbsent(post.chatId, () => <Post>[]).add(post);
  }
  for (final channelPosts in byChannel.values) {
    channelPosts.sort((a, b) => a.publishedAt.compareTo(b.publishedAt));
  }

  // Channels whose oldest unread is oldest go first, so the longest-neglected
  // channel leads each round rather than whichever hashed first.
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

/// Unread posts far enough back to be worth lifting into the mix.
///
/// Everything in the newest [freshWindow] is left alone: it is already at the
/// top of the feed, and moving it would be shuffling for its own sake.
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
///
/// [backlogOrder] is the running pool of unread posts eligible for the mix, in
/// the order they should be used. It is deliberately an ordered list held by
/// the caller and appended to, never re-derived: re-picking "the oldest unread
/// currently loaded" on every build would reshuffle the rows the reader is
/// looking at each time pagination brought older posts in.
///
/// Only as many rows are lifted as the cadence has slots for. Backlog posts
/// beyond that keep their chronological place rather than being dumped at the
/// end, so the feed never degenerates into a reverse-ordered tail.
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

  // How many slots the cadence offers over this many rows. Under one full
  // cadence there is nothing to weave into, so the feed stays as it was —
  // which is also what keeps the fresh side from ever being empty here.
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
    // Reading a lifted post does not move it: the pool changes only on a
    // refresh, so nothing shifts under the reader's thumb mid-scroll.
    if (lifted.contains(post.id)) {
      backlogPosts.add(post);
    } else {
      freshPosts.add(post);
    }
  }

  // Threaded within each pool, never across: a channel's backlog post and its
  // post from an hour ago are two different reading moments.
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
