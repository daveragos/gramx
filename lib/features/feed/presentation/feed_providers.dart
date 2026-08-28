import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/features/guest/data/guest_post_mapper.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/feed_thread.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/domain/reaction_choice.dart';
import 'package:gramx/features/feed/presentation/mute_registry.dart';
import 'package:gramx/features/feed/presentation/read_receipt_queue.dart';
import 'package:gramx/features/folders/data/folder_repository.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';

/// Narrows pagination cursors to a set of chats.
///
/// A null [allowedChatIds] means "no folder filter" and passes everything
/// through, which is what the All tab wants.
Map<int, int> narrowCursors(Map<int, int> cursors, Set<int>? allowedChatIds) {
  if (allowedChatIds == null) return cursors;
  return {
    for (final entry in cursors.entries)
      if (allowedChatIds.contains(entry.key)) entry.key: entry.value,
  };
}

/// Removes posts the reader has already finished with.
///
/// A post is dropped only when *both* are true: it was on screen before the
/// refresh ([seenBefore]) and it counts as read. That pairing matters —
///
/// * filtering on read alone would empty the feed on a cold start, since
///   everything older than the read cursor is read;
/// * filtering on seen alone would drop unread posts the reader deliberately
///   scrolled past to come back to.
///
/// "Counts as read" means Telegram's cursor **or** this app's own record
/// ([readHere]). Trusting only the cursor meant a post read seconds ago came
/// straight back on refresh, because the acknowledgement was still queued —
/// and being handed back what you just finished is the opposite of what the
/// gesture asks for.
///
/// New posts and posts still unread always survive.
List<Post> dropAlreadyRead(
  List<Post> posts,
  Set<String> seenBefore, {
  Set<String> readHere = const {},
}) {
  if (seenBefore.isEmpty) return posts;
  return posts
      .where((p) =>
          !((p.isRead || readHere.contains(p.id)) && seenBefore.contains(p.id)))
      .toList();
}

/// The ids a refresh retires: everything the reader had already finished with.
///
/// [dropAlreadyRead] takes them out of the freshly fetched page, but that page
/// is not the only thing that fills the feed — the backfill, the unread sweep
/// and pagination all merge into it a moment later, and they answer from
/// TDLib's history with no idea a refresh just happened. So a pull emptied the
/// read posts out and then watched them file straight back in, which is the
/// old feed "coming back on".
///
/// Remembering *which* ids went, rather than re-deriving "read" at each merge,
/// is what keeps that fix from also hiding the read posts a reader has never
/// seen: those are ordinary history and belong in the feed.
Set<String> retiredPostIds(
  List<Post> previous, {
  Set<String> readHere = const {},
}) {
  return {
    for (final post in previous)
      if (post.isRead || readHere.contains(post.id)) post.id,
  };
}

/// Drops anything a refresh retired. See [retiredPostIds].
List<Post> withoutRetired(List<Post> posts, Set<String> retired) {
  if (retired.isEmpty || posts.isEmpty) return posts;
  final kept = [
    for (final post in posts)
      if (!retired.contains(post.id)) post,
  ];
  return kept.length == posts.length ? posts : kept;
}

/// Merges [incoming] posts into [current], newest first.
///
/// Posts already present win: their entry is kept untouched so optimistic
/// reaction, bookmark and read state survives a refetch of the same post.
List<Post> mergePostsNewestFirst(List<Post> current, List<Post> incoming) {
  if (incoming.isEmpty) return current;

  final seen = current.map((p) => p.id).toSet();
  final additions = <Post>[];
  for (final post in incoming) {
    // `seen` grows as we go, so a batch containing the same post twice — which
    // happens when an album's members race each other — yields one entry.
    if (seen.add(post.id)) additions.add(post);
  }
  if (additions.isEmpty) return current;

  return [...current, ...additions]
    ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
}

/// The running pool of unread posts eligible for the mix, in the order they
/// should be used.
///
/// Ordered and append-only, not a set: the blend has to be stable. Re-deriving
/// "the oldest unread currently loaded" on every build would reshuffle the
/// rows the reader is looking at each time pagination brought older posts in.
/// It is cleared on refresh, and only then.
class BacklogIdsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  /// Appends ids not already pooled, keeping the order they arrived in.
  void add(Iterable<String> ids) {
    final known = state.toSet();
    final additions = [
      for (final id in ids)
        if (known.add(id)) id,
    ];
    if (additions.isEmpty) return;
    state = [...state, ...additions];
  }

  void clear() {
    if (state.isNotEmpty) state = const [];
  }
}

final backlogIdsProvider =
    NotifierProvider<BacklogIdsNotifier, List<String>>(BacklogIdsNotifier.new);

/// Stateful feed notifier that supports appending older posts (pagination)
/// and full refresh without destroying state.
class FeedNotifier extends AsyncNotifier<List<Post>> {
  final Map<int, int> _oldestMessageIds = {};
  bool _isLoadingMore = false;
  StreamSubscription<List<Post>>? _backfillSub;

  /// Posts the last refresh took out of the feed, so nothing puts them back.
  ///
  /// Everything that merges into the feed goes through [_admit], which is the
  /// only reason a refresh sticks: the backfill and the unread sweep restart
  /// right behind it and would otherwise re-deliver exactly what was dropped.
  /// Cleared on the next refresh, and only then.
  Set<String> _retired = const {};

  /// Set on dispose. The background passes below outlive a rebuild, and
  /// writing state after that throws.
  bool _disposed = false;

  @override
  Future<List<Post>> build() async {
    // Rebuild when sign-in completes. A build that ran before TDLib was
    // authorised resolves to an empty feed and, without this dependency, never
    // retries — which is why the feed sat on its loading state until the app
    // was restarted.
    ref.watch(authControllerProvider.select((auth) => auth.step));

    // And again when the chat cache first learns about a channel. Right after
    // sign-in this build runs against an empty cache, fetches nothing, and
    // that nothing would otherwise stand as the feed for the whole session.
    ref.watch(channelsKnownProvider);

    final repo = ref.watch(feedRepositoryProvider);
    final syncService = ref.watch(syncServiceProvider);

    final sub = syncService.livePostUpdates.listen((update) {
      if (update is LiveReactionsUpdate) {
        updateReactionsLive(update.postId, update.reactions, update.chosenReactions);
      } else if (update is LiveInteractionUpdate) {
        updateMetadataLive(update.postId, viewCount: update.viewCount, forwardCount: update.forwardCount);
        // Interaction info is the only place a user client hears about
        // reactions — updateMessageReactions is bots-only. Applied separately
        // so a view-count-only update never touches the reaction row.
        final reactions = update.reactions;
        final chosen = update.chosenReactions;
        if (reactions != null && chosen != null) {
          updateReactionsLive(update.postId, reactions, chosen);
        }
      }
    });
    ref.onDispose(() {
      _disposed = true;
      sub.cancel();
      _backfillSub?.cancel();
    });

    // Only the first fill warms up. A refresh that legitimately empties the
    // feed should say "you're all caught up", not hide behind a skeleton for
    // the length of a backfill. Written outside this build: a provider must
    // not be modified while another is building.
    Future.microtask(() => ref.read(feedWarmupProvider.notifier).start());

    final posts = await repo.fetchFeedPosts();
    _updateOldestIds(posts);
    // The mix has to be there in the first painted feed, not arrive twenty
    // seconds later while the reader is already scrolling. Both of these are
    // free: one reads what was just loaded, the other reads TDLib's own cache.
    _poolBacklogCandidates(posts);
    _primeBacklogFromCache(repo);
    _startBackfill(repo);
    return posts;
  }

  /// Fills the mix from TDLib's cache, without waiting for the network.
  ///
  /// Deliberately not awaited by `build`: it must not add a millisecond to the
  /// time the skeleton is on screen. It lands a beat after the first paint,
  /// which in practice is before the reader has finished looking at the top of
  /// the feed.
  Future<void> _primeBacklogFromCache(FeedRepository repo) async {
    try {
      final cached = _admit(await repo.fetchCachedUnreadBacklog());
      if (cached.isEmpty || _disposed) return;

      ref.read(backlogIdsProvider.notifier).add(orderBacklogIds(cached));
      final current = state.value ?? [];
      final merged = mergePostsNewestFirst(current, cached);
      if (!identical(merged, current)) {
        _updateOldestIds(cached);
        state = AsyncData(merged);
      }
    } catch (e) {
      debugPrint('[Feed] Priming the backlog failed: $e');
    }
  }

  /// Looks behind each channel's read cursor, once the fresh backfill is done.
  ///
  /// Deliberately last: it shares the request budget with the backfill, and
  /// what's new matters more than what's owed. Failures are silent by design —
  /// a backlog that doesn't arrive costs a blend, not the feed.
  Future<void> _sweepUnread(FeedRepository repo) async {
    try {
      final backlog = _admit(await repo.fetchUnreadBacklog());
      if (backlog.isEmpty || _disposed) return;

      // Round-robin across channels, so a channel sitting on a week of unread
      // doesn't take every backlog slot in a row.
      ref.read(backlogIdsProvider.notifier).add(orderBacklogIds(backlog));
      final current = state.value ?? [];
      final merged = mergePostsNewestFirst(current, backlog);
      if (!identical(merged, current)) {
        _updateOldestIds(backlog);
        state = AsyncData(merged);
      }
      _poolBacklogCandidates();
    } catch (e) {
      debugPrint('[Feed] Unread sweep failed: $e');
    }
  }

  /// Fills the feed in behind the first paint.
  ///
  /// A cold start only volunteers one post per channel (plus whatever is cached
  /// locally), so real history arrives here — throttled, one channel at a time,
  /// merged as it lands rather than in one batch at the end.
  void _startBackfill(FeedRepository repo) {
    _backfillSub?.cancel();
    _backfillSub = repo.backfillRecentHistory().listen(
      _mergeBackfilled,
      onError: (Object e) {
        debugPrint('[Feed] Backfill error: $e');
        ref.read(feedWarmupProvider.notifier).finish();
      },
      onDone: () {
        // Whatever the feed has by now is what it has: an empty list from here
        // on genuinely means empty.
        ref.read(feedWarmupProvider.notifier).finish();
        _sweepUnread(repo);
      },
    );
  }

  /// Adds posts we don't already have, leaving existing entries untouched so
  /// optimistic reaction and bookmark state survives.
  void _mergeBackfilled(List<Post> incoming) {
    final current = state.value ?? [];
    final existingIds = current.map((p) => p.id).toSet();
    final additions = _admit(incoming)
        .where((p) => !existingIds.contains(p.id))
        .toList();
    if (additions.isEmpty) return;

    _updateOldestIds(additions);
    state = AsyncData(mergePostsNewestFirst(current, additions));
    // Something to show: the skeleton has served its purpose.
    ref.read(feedWarmupProvider.notifier).finish();
    _poolBacklogCandidates();
  }

  /// Offers everything unread behind the fresh window to the mix.
  ///
  /// Not only what the unread sweep fetched: a post from three days ago that
  /// arrived with the ordinary backfill is exactly as unread, and belongs in
  /// the mix on the same terms.
  void _poolBacklogCandidates([List<Post>? loaded]) {
    // Takes the list explicitly during `build`, where `state` is not set yet.
    final posts = loaded ?? state.value;
    if (posts == null || posts.isEmpty) return;
    ref
        .read(backlogIdsProvider.notifier)
        .add(selectBacklogCandidates(posts));
  }

  /// Splices freshly arrived posts into the feed.
  ///
  /// Called when the user taps the "new posts" pill — never automatically, so
  /// the list never shifts under someone mid-read.
  void prependPosts(List<Post> incoming) {
    final current = state.value ?? [];
    final merged = mergePostsNewestFirst(current, incoming);
    if (identical(merged, current)) return;
    state = AsyncData(merged);
  }

  /// Everything that arrives after a refresh passes through here.
  ///
  /// One gate rather than a check at each of the five call sites: the whole
  /// bug was that one of them did not have it.
  List<Post> _admit(List<Post> posts) => withoutRetired(posts, _retired);

  /// Track the oldest messageId per channel for cursor-based pagination.
  void _updateOldestIds(List<Post> posts) {
    for (final post in posts) {
      final existing = _oldestMessageIds[post.chatId];
      if (existing == null || post.messageId < existing) {
        _oldestMessageIds[post.chatId] = post.messageId;
      }
    }
  }

  /// Loads older posts and appends them.
  ///
  /// [allowedChatIds] narrows the request to one folder's channels. Without it,
  /// scrolling to the bottom of a three-channel folder tab paged *every*
  /// subscription and then filtered almost all of it away — so the visible list
  /// barely grew and the scroll listener fired again immediately.
  Future<void> loadMore({Set<int>? allowedChatIds}) async {
    if (_isLoadingMore || _oldestMessageIds.isEmpty) return;

    final cursors = narrowCursors(_oldestMessageIds, allowedChatIds);
    if (cursors.isEmpty) return;

    _isLoadingMore = true;
    try {
      final repo = ref.read(feedRepositoryProvider);
      final olderPosts = _admit(await repo.fetchOlderPosts(cursors));
      if (olderPosts.isNotEmpty) {
        _updateOldestIds(olderPosts);
        final current = state.value ?? [];
        final merged = mergePostsNewestFirst(current, olderPosts);
        if (!identical(merged, current)) state = AsyncData(merged);
        _poolBacklogCandidates();
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Full refresh: re-fetch from scratch (for pull-to-refresh).
  ///
  /// Posts the reader already finished are dropped — pulling for new material
  /// and being handed back what you just read is the opposite of what the
  /// gesture asks for. See [dropAlreadyRead] for exactly which ones go.
  Future<void> refresh() async {
    _backfillSub?.cancel();
    // The blend is fixed between refreshes; this is the moment it is allowed
    // to change, which is what "stays until you refresh" means.
    ref.read(backlogIdsProvider.notifier).clear();
    final previous = state.value ?? const <Post>[];
    final seenBefore = previous.map((p) => p.id).toSet();

    _oldestMessageIds.clear();
    state = const AsyncLoading();
    final repo = ref.read(feedRepositoryProvider);
    final readHere = ref.read(optimisticPostUpdatesProvider.notifier).readPostIds;
    // Named before the fetch so a failed refresh cannot leave half a rule in
    // place: either the whole pull happened or none of it did.
    final retiring = retiredPostIds(previous, readHere: readHere);
    state = await AsyncValue.guard(() async {
      final fetched = await repo.fetchFeedPosts();
      final posts = dropAlreadyRead(fetched, seenBefore, readHere: readHere);
      // Whatever the fetch itself dropped joins the list: the server can know
      // a post was read on another device when this session still had it
      // marked unread.
      final kept = posts.map((p) => p.id).toSet();
      _retired = {
        ...retiring,
        for (final post in fetched)
          if (!kept.contains(post.id)) post.id,
      };
      _updateOldestIds(posts);
      return posts;
    });
    if (state.hasValue) _startBackfill(repo);
  }

  /// Optimistically toggle bookmark on a post without re-fetching the feed.
  void toggleBookmarkOptimistic(String postId) {
    final current = state.value;
    if (current == null) return;
    final updated = current.map((p) {
      if (p.id == postId) {
        return p.copyWith(isBookmarked: !p.isBookmarked);
      }
      return p;
    }).toList();
    state = AsyncData(updated);
  }

  /// Optimistically toggle reaction emoji on a post without re-fetching the feed.
  void toggleReactionOptimistic(String postId, String emoji) {
    final current = state.value;
    if (current == null) return;
    final updated = current.map((p) {
      if (p.id == postId) {
        final next = applyReactionChoice(
          reactions: p.reactions,
          chosen: p.chosenReactions,
          emoji: emoji,
        );
        return p.copyWith(
          reactions: next.reactions,
          chosenReactions: next.chosen,
        );
      }
      return p;
    }).toList();
    state = AsyncData(updated);
  }

  /// Live update reactions from TDLib's interaction-info stream.
  void updateReactionsLive(String postId, Map<String, int> reactions, Set<String> chosenReactions) {
    // The server has spoken, so the optimistic guess must step aside or it
    // keeps overriding every future update for this post.
    ref.read(optimisticPostUpdatesProvider.notifier).clearReactions(postId);

    final current = state.value;
    if (current == null) return;
    final updated = current.map((p) {
      if (p.id == postId) {
        return p.copyWith(reactions: reactions, chosenReactions: chosenReactions);
      }
      return p;
    }).toList();
    state = AsyncData(updated);
  }

  /// Live update views and forward counts from TDLib UpdateMessageInteractionInfo stream
  void updateMetadataLive(String postId, {int? viewCount, int? forwardCount}) {
    final current = state.value;
    if (current == null) return;
    final updated = current.map((p) {
      if (p.id == postId) {
        return p.copyWith(
          viewCount: viewCount ?? p.viewCount,
          forwardCount: forwardCount ?? p.forwardCount,
        );
      }
      return p;
    }).toList();
    state = AsyncData(updated);
  }

  /// Optimistically update poll options when user votes on a poll.
  void votePollOptimistic(String postId, List<int> optionIds) {
    final current = state.value;
    if (current == null) return;
    final updated = current.map((p) {
      if (p.id == postId && p.poll != null) {
        final currentPoll = p.poll!;
        final newTotalVoters = currentPoll.totalVoterCount + 1;

        final updatedOptions = currentPoll.options.asMap().entries.map((entry) {
          final idx = entry.key;
          final opt = entry.value;
          final isNewlyChosen = optionIds.contains(idx);
          final newCount = isNewlyChosen ? opt.voterCount + 1 : opt.voterCount;
          final pct = newTotalVoters > 0 ? (newCount / newTotalVoters) * 100 : 0.0;
          return opt.copyWith(
            voterCount: newCount,
            votePercentage: pct,
            isChosen: isNewlyChosen || opt.isChosen,
          );
        }).toList();

        final updatedPoll = currentPoll.copyWith(
          options: updatedOptions,
          totalVoterCount: newTotalVoters,
          chosenOptionIds: {...currentPoll.chosenOptionIds, ...optionIds}.toList(),
        );

        return p.copyWith(poll: updatedPoll);
      }
      return p;
    }).toList();
    state = AsyncData(updated);
  }

  /// Optimistically mark a post as read without re-fetching the feed.
  void markReadOptimistic(String postId) {
    final current = state.value;
    if (current == null) return;
    final updated = current.map((p) {
      if (p.id == postId && !p.isRead) {
        return p.copyWith(isRead: true);
      }
      return p;
    }).toList();
    state = AsyncData(updated);
  }
}

/// True while the feed's first fill is still running.
///
/// The first fetch after signing in answers from a cold cache and is often
/// empty: real history arrives on the throttled backfill, one channel a
/// second. Telling the reader "no posts" during that window is a lie, and it
/// is the window they spend staring at the screen — so the feed keeps its
/// skeleton up until the fill is done or something arrives.
class FeedWarmupNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void start() {
    if (!state) state = true;
  }

  void finish() {
    if (state) state = false;
  }
}

final feedWarmupProvider =
    NotifierProvider<FeedWarmupNotifier, bool>(FeedWarmupNotifier.new);

/// Main feed posts provider — uses AsyncNotifier for stateful pagination.
final feedPostsProvider =
    AsyncNotifierProvider<FeedNotifier, List<Post>>(FeedNotifier.new);

/// Fetches a single post by its composite ID (chatId_messageId).
///
/// Deliberately blind to optimistic overrides: watching them here made every
/// reaction tap re-run this future, which is a TDLib request and a full
/// loading state for the screen. Read [postDetailProvider] instead, which
/// layers the overrides on synchronously.
final postDetailFetchProvider =
    FutureProvider.family<Post?, String>((ref, postId) async {
  final parts = postId.split('_');
  if (parts.length != 2) return null;
  final chatId = int.tryParse(parts[0]);
  final messageId = int.tryParse(parts[1]);
  if (chatId == null || messageId == null) return null;

  // A guest post has no TDLib message behind it, so asking TDLib for one
  // answers nothing and the screen said "post not found" for every post the
  // reader could plainly see. The guest feed already holds it.
  if (GuestPostMapper.isSynthetic(chatId)) {
    final feed = await ref.watch(guestFeedProvider.future);
    return feed.posts.where((p) => p.id == postId).firstOrNull;
  }

  final repo = ref.watch(feedRepositoryProvider);
  return repo.fetchSinglePost(chatId, messageId);
});

/// A single post with optimistic state applied.
///
/// Synchronous, so a reaction or a bookmark shows instantly and costs nothing.
final postDetailProvider =
    Provider.family<AsyncValue<Post?>, String>((ref, postId) {
  final overrides = ref.watch(optimisticPostUpdatesProvider);
  return ref.watch(postDetailFetchProvider(postId)).whenData(
        (post) => post == null ? null : applyPostOverrides(post, overrides),
      );
});

/// Toggle bookmark action — call this to flip bookmark state.
final bookmarkToggleProvider =
    FutureProvider.family<void, String>((ref, postId) async {
  final repo = ref.read(feedRepositoryProvider);
  final parts = postId.split('_');
  if (parts.length != 2) return;
  final chatId = int.tryParse(parts[0]);
  final messageId = int.tryParse(parts[1]);
  if (chatId == null || messageId == null) return;

  // Optimistic local state update
  ref.read(feedPostsProvider.notifier).toggleBookmarkOptimistic(postId);

  // Persist asynchronously
  await repo.toggleBookmark(chatId, messageId);
});

/// The channels hidden from the feed, with their expiry times.
///
/// State is the set of ids muted *right now*, so every reader of it — the feed
/// filter, the channel list — stays a plain set membership test. The rules and
/// the expiry times live in [MuteRegistry].
class MutedChannelsNotifier extends Notifier<Set<String>> {
  static const String _fileName = 'muted_channels.json';

  MuteRegistry _registry = MuteRegistry();
  Timer? _expiryTimer;

  @override
  Set<String> build() {
    ref.onDispose(() {
      _expiryTimer?.cancel();
      _expiryTimer = null;
    });
    _loadFromDisk();
    return {};
  }

  /// When a channel's mute lifts, or null if it is indefinite or not muted.
  DateTime? mutedUntil(String channelId, {int? chatId, String? username}) =>
      _registry.mutedUntil(
        channelId,
        chatId: chatId,
        username: username,
        now: DateTime.now(),
      );

  bool isMuted(String channelId, {int? chatId, String? username}) =>
      _registry.isMuted(
        channelId,
        chatId: chatId,
        username: username,
        now: DateTime.now(),
      );

  /// Mutes a channel for [duration], or lifts the mute if it already has one.
  ///
  /// Timed mutes are what Telegram offers, and what a reader actually wants:
  /// "not during this news cycle" is a different thing from "never again", and
  /// only one of them should require remembering to undo it.
  void mute(
    String channelId, {
    int? chatId,
    String? username,
    MuteDuration duration = MuteDuration.forever,
  }) {
    final now = DateTime.now();
    _registry.mute(
      channelId,
      chatId: chatId,
      username: username,
      until: duration.expiryFrom(now),
    );
    _commit();
  }

  void unmute(String channelId, {int? chatId, String? username}) {
    _registry.unmute(channelId, chatId: chatId, username: username);
    _commit();
  }

  /// Mutes indefinitely, or unmutes. Kept for the plain on/off affordances.
  void toggleMute(String channelId, {int? chatId, String? username}) {
    if (isMuted(channelId, chatId: chatId, username: username)) {
      unmute(channelId, chatId: chatId, username: username);
    } else {
      mute(channelId, chatId: chatId, username: username);
    }
  }

  /// Publishes the registry as the active id set, saves it, and arms the timer
  /// for the next expiry — so a mute lifts on its own rather than at whatever
  /// moment the app next happens to rebuild.
  void _commit() {
    final now = DateTime.now();
    _registry.pruneExpired(now);
    state = _registry.activeIds(now);
    _saveToDisk();
    _scheduleExpiry();
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    _expiryTimer = null;

    final now = DateTime.now();
    final next = _registry.nextExpiry(now);
    if (next == null) return;

    // A second of slack, so the timer never fires a hair before the deadline
    // and leaves the mute in place until something else pokes it.
    final delay = next.difference(now) + const Duration(seconds: 1);
    _expiryTimer = Timer(delay, _commit);
  }

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> _loadFromDisk() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return;
      // Tolerates the old shape — a bare list of ids with no expiry.
      _registry = MuteRegistry.fromJson(jsonDecode(await file.readAsString()));
      _commit();
    } catch (e) {
      debugPrint('[MutedChannels] Error loading from disk: $e');
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final file = await _getFile();
      await file.writeAsString(jsonEncode(_registry.toJson()));
    } catch (e) {
      debugPrint('[MutedChannels] Error saving to disk: $e');
    }
  }
}

final mutedChannelsProvider =
    NotifierProvider<MutedChannelsNotifier, Set<String>>(
        MutedChannelsNotifier.new);

/// The folder tab currently on screen.
///
/// The bottom bar needs this: re-tapping Home should return the *visible* feed
/// to the top, and only the feed knows which tab that is.
class ActiveFolderNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void set(String folderId) {
    if (state != folderId) state = folderId;
  }
}

final activeFolderProvider =
    NotifierProvider<ActiveFolderNotifier, String>(ActiveFolderNotifier.new);

/// A request for one folder's feed to return to the top.
///
/// Carries a tick so two requests for the same folder are distinct events; the
/// feed itself owns its scroll controller, so this is how another widget asks.
class ScrollToTopRequest {
  final String folderId;
  final int tick;

  const ScrollToTopRequest(this.folderId, this.tick);
}

class FeedScrollToTopNotifier extends Notifier<ScrollToTopRequest?> {
  @override
  ScrollToTopRequest? build() => null;

  void request(String folderId) =>
      state = ScrollToTopRequest(folderId, (state?.tick ?? 0) + 1);
}

final feedScrollToTopProvider =
    NotifierProvider<FeedScrollToTopNotifier, ScrollToTopRequest?>(
        FeedScrollToTopNotifier.new);

/// Fetches a post's comment thread from its linked discussion group.
///
/// Overrides are applied by [postCommentsProvider] rather than here. Watching
/// them inside the future meant reacting to one comment refetched the entire
/// thread — the whole screen dropped to a spinner and scrolled back to the top
/// on every tap.
final postCommentsFetchProvider =
    FutureProvider.family<List<Post>, String>((ref, postId) async {
  final parts = postId.split('_');
  if (parts.length != 2) return [];
  final chatId = int.tryParse(parts[0]);
  final messageId = int.tryParse(parts[1]);
  if (chatId == null || messageId == null) return [];

  final repo = ref.watch(feedRepositoryProvider);
  return repo.fetchPostComments(chatId, messageId);
});

/// The comment thread with optimistic reaction state applied.
///
/// Comments aren't in the feed list, so without this layer a reaction tapped
/// here showed nothing at all until the thread was refetched.
final postCommentsProvider =
    Provider.family<AsyncValue<List<Post>>, String>((ref, postId) {
  final overrides = ref.watch(optimisticPostUpdatesProvider);
  return ref.watch(postCommentsFetchProvider(postId)).whenData(
        (comments) =>
            comments.map((c) => applyPostOverrides(c, overrides)).toList(),
      );
});

/// Marks a post read because the user explicitly opened it.
///
/// Passive reading is handled by `FeedFocusController`, which waits for a real
/// dwell. This provider is for the deliberate act of tapping a post, where
/// forcing the read state through is what the user asked for.
final markPostAsReadProvider =
    FutureProvider.family<void, String>((ref, postId) async {
  ref.read(optimisticPostUpdatesProvider.notifier).markRead(postId);
  ref.read(feedPostsProvider.notifier).markReadOptimistic(postId);

  // Through the queue, so this ack is batched with whatever the dwell tracker
  // has already collected for the same chat — then sent immediately, because
  // opening a post is as deliberate as read intent gets.
  final queue = ref.read(readReceiptQueueProvider.notifier);
  queue.add(postId);
  await queue.flush();
});

/// Reads a chat-folder title, whatever shape TDLib hands it over in.
///
/// The field has been a plain String and a FormattedText across TDLib versions,
/// and arrives as a decoded map in some paths, so all three are handled.
String parseFolderTitle(dynamic rawTitle) {
  if (rawTitle == null) return 'Folder';
  if (rawTitle is String) return rawTitle;
  if (rawTitle is td.FormattedText) return rawTitle.text;
  if (rawTitle is Map) {
    final text = rawTitle['text'];
    if (text is String) return text;
  }
  try {
    final text = (rawTitle as dynamic).text;
    if (text is String) return text;
  } catch (_) {}
  return rawTitle.toString();
}

/// A folder the user asked to open from somewhere other than the feed.
///
/// The folders screen sets this and switches to the Home tab; the feed consumes
/// it once and selects the matching tab.
class RequestedFolderNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void request(String folderId) => state = folderId;

  /// Reads and clears, so the request fires once rather than on every rebuild.
  String? consume() {
    final value = state;
    if (value != null) state = null;
    return value;
  }
}

final requestedFolderProvider =
    NotifierProvider<RequestedFolderNotifier, String?>(
        RequestedFolderNotifier.new);

/// Provides user's dynamic folders synced from Telegram (StreamProvider for real-time reactivity)
final foldersProvider = StreamProvider<List<td.ChatFolderInfo>>((ref) async* {
  final tdlib = ref.watch(tdlibServiceProvider);
  // Yield initial cached folders
  yield tdlib.chatFolders;
  // Listen for UpdateChatFolders updates
  await for (final update in tdlib.updatesStream) {
    if (update is td.UpdateChatFolders) {
      yield update.chatFolders;
    }
  }
});

/// Cached folder channel IDs per folder (fetched once via TDLib and cached in Riverpod)
final folderChannelIdsProvider =
    FutureProvider.family<Set<String>, int>((ref, folderId) async {
  // Same reason as the feed: asked before the cache filled, this answers with
  // an empty set — and an empty folder is a folder whose tab disappears.
  ref.watch(channelsKnownProvider);

  final folderRepo = ref.watch(folderRepositoryProvider);
  final allowedChannelIds = await folderRepo.getFolderChannelChatIds(folderId);
  return allowedChannelIds.map((id) => id.toString()).toSet();
});

/// Whether folder [folderId] is an "unread" style filter rather than a fixed
/// list of chats — see `folderHasChannels` in `home_screen.dart`, which keeps
/// such a folder's tab visible even when its resolved chat list is empty.
final folderExcludesReadProvider =
    FutureProvider.family<bool, int>((ref, folderId) async {
  final folderRepo = ref.watch(folderRepositoryProvider);
  return folderRepo.folderExcludesRead(folderId);
});

bool _isPostMuted(Post post, Set<String> mutedIds) {
  if (mutedIds.isEmpty) return false;
  // One place decides what a channel is called; see MuteRegistry.aliasesOf.
  return MuteRegistry.aliasesOf(
    post.channelId,
    chatId: post.chatId,
    username: post.channelUsername,
  ).any(mutedIds.contains);
}

class OptimisticPostUpdatesNotifier extends Notifier<Map<String, Map<String, dynamic>>> {
  @override
  Map<String, Map<String, dynamic>> build() => {};

  void toggleReaction(String postId, String emoji, Post currentPost) {
    final currentData = state[postId] ?? {};
    final next = applyReactionChoice(
      reactions: (currentData['reactions'] as Map<String, int>?) ??
          currentPost.reactions,
      chosen: (currentData['chosenReactions'] as Set<String>?) ??
          currentPost.chosenReactions,
      emoji: emoji,
    );

    state = {
      ...state,
      postId: {
        ...currentData,
        'reactions': next.reactions,
        'chosenReactions': next.chosen,
      },
    };
  }

  /// Drops the optimistic reaction guess for a post.
  ///
  /// Called when the server tells us the real counts. Without this the guess
  /// stayed on top of every later update, so reaction counts looked frozen —
  /// the live stream was arriving and being masked.
  void clearReactions(String postId) {
    final currentData = state[postId];
    if (currentData == null) return;
    if (!currentData.containsKey('reactions') &&
        !currentData.containsKey('chosenReactions')) {
      return;
    }

    final remaining = Map<String, dynamic>.from(currentData)
      ..remove('reactions')
      ..remove('chosenReactions');

    final next = Map<String, Map<String, dynamic>>.from(state);
    // Bookmark and read overrides for this post must survive; only drop the
    // whole entry once nothing is left in it.
    if (remaining.isEmpty) {
      next.remove(postId);
    } else {
      next[postId] = remaining;
    }
    state = next;
  }

  void toggleBookmark(String postId, Post currentPost) {
    final currentData = state[postId] ?? {};
    final currentIsBookmarked = currentData['isBookmarked'] as bool? ?? currentPost.isBookmarked;

    state = {
      ...state,
      postId: {
        ...currentData,
        'isBookmarked': !currentIsBookmarked,
      },
    };
  }

  /// Posts this app has marked read, whatever Telegram's cursor says yet.
  ///
  /// A refresh uses this so a post finished seconds ago doesn't come back
  /// while its acknowledgement is still queued.
  Set<String> get readPostIds => {
        for (final entry in state.entries)
          if (entry.value['isRead'] == true) entry.key,
      };

  void markRead(String postId) {
    final currentData = state[postId] ?? {};
    state = {
      ...state,
      postId: {
        ...currentData,
        'isRead': true,
      },
    };
  }
}

final optimisticPostUpdatesProvider =
    NotifierProvider<OptimisticPostUpdatesNotifier, Map<String, Map<String, dynamic>>>(
  OptimisticPostUpdatesNotifier.new,
);

Post applyPostOverrides(Post post, Map<String, Map<String, dynamic>> overrides) {
  final data = overrides[post.id];
  if (data == null) return post;
  return post.copyWith(
    reactions: data['reactions'] as Map<String, int>? ?? post.reactions,
    chosenReactions: data['chosenReactions'] as Set<String>? ?? post.chosenReactions,
    isBookmarked: data['isBookmarked'] as bool? ?? post.isBookmarked,
    isRead: data['isRead'] as bool? ?? post.isRead,
  );
}

/// Applies the folder and hidden-channel filters to a list of posts.
///
/// Shared by the feed itself and by the pending-arrivals pill, so a tab's
/// "N new posts" count can never disagree with what that tab would show.
List<Post> filterPostsForFolder(Ref ref, List<Post> posts, String folderIdStr) {
  final mutedChannelIds = ref.watch(mutedChannelsProvider);

  var list = posts;
  if (mutedChannelIds.isNotEmpty) {
    list = list.where((p) => !_isPostMuted(p, mutedChannelIds)).toList();
  }

  final folderId = int.tryParse(folderIdStr);
  if (folderIdStr == 'All' || folderId == null) return list;

  final allowed = ref.watch(folderChannelIdsProvider(folderId)).value;
  if (allowed == null) return const [];
  if (allowed.isEmpty) return const [];

  return list
      .where((post) =>
          allowed.contains(post.channelId) ||
          allowed.contains(post.chatId.toString()))
      .toList();
}

/// Filtered posts by folder/category and excluding muted channels.
///
/// Synchronous Provider returning `AsyncValue<List<Post>>` to ensure instant 0ms
/// state updates when post actions (reactions, bookmarks) occur.
final filteredFeedPostsProvider =
    Provider.family<AsyncValue<List<Post>>, String>((ref, folderIdStr) {
  final postsAsync = ref.watch(feedPostsProvider);
  final overrides = ref.watch(optimisticPostUpdatesProvider);

  final folderId = int.tryParse(folderIdStr);
  if (folderIdStr != 'All' && folderId != null) {
    final folderChannelsAsync = ref.watch(folderChannelIdsProvider(folderId));
    if (folderChannelsAsync.isLoading && !folderChannelsAsync.hasValue) {
      return const AsyncValue.loading();
    }
    if (folderChannelsAsync.hasError && !folderChannelsAsync.hasValue) {
      return AsyncValue.error(
          folderChannelsAsync.error!, folderChannelsAsync.stackTrace!);
    }
  }

  return postsAsync.whenData((posts) => filterPostsForFolder(ref, posts, folderIdStr)
      .map((p) => applyPostOverrides(p, overrides))
      .toList());
});
