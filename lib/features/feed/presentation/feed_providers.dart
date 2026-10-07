import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/core/diagnostics/startup_trace.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/feed_thread.dart';
import 'package:gramx/features/feed/domain/poll.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/domain/reaction_choice.dart';
import 'package:gramx/features/feed/presentation/mute_registry.dart';
import 'package:gramx/features/feed/presentation/read_receipt_queue.dart';
import 'package:gramx/features/feed/presentation/seen_posts_provider.dart';
import 'package:gramx/features/folders/data/folder_repository.dart';
import 'package:gramx/features/guest/data/guest_post_mapper.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:path_provider/path_provider.dart';

/// Narrows pagination cursors to a set of chats. A null [allowedChatIds]
/// passes everything through (the All tab).
Map<int, int> narrowCursors(Map<int, int> cursors, Set<int>? allowedChatIds) {
  if (allowedChatIds == null) return cursors;
  return {
    for (final entry in cursors.entries)
      if (allowedChatIds.contains(entry.key)) entry.key: entry.value,
  };
}

/// Leaves out posts behind Telegram's read cursor or in this app's record
/// of seen posts ([readHere]; see `SeenPosts`). Everything that fills the
/// feed passes through this.
List<Post> unreadOnly(List<Post> posts, {Set<String> readHere = const {}}) {
  if (posts.isEmpty) return posts;
  final kept = [
    for (final post in posts)
      if (!post.isRead && !readHere.contains(post.id)) post,
  ];
  return kept.length == posts.length ? posts : kept;
}

/// Merges [incoming] into [current], newest first, preferring [incoming]'s
/// fuller copy. Compare [mergePostsNewestFirst], where the existing copy wins.
List<Post> replacePostsNewestFirst(List<Post> current, List<Post> incoming) {
  if (incoming.isEmpty) return current;
  final replacing = {for (final post in incoming) post.id: post};
  return [
    for (final post in current)
      if (!replacing.containsKey(post.id)) post,
    ...replacing.values,
  ]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
}

/// Narrows pagination cursors to channels that have unread posts older than
/// what is loaded. Paging other channels only fetches read posts.
Map<int, int> cursorsWithUnreadBehind(
  Map<int, int> cursors,
  td.Chat? Function(int chatId) chatOf,
) {
  return {
    for (final entry in cursors.entries)
      if (chatOf(entry.key) case final chat?
          when chat.unreadCount > 0 &&
              chat.lastReadInboxMessageId < entry.value)
        entry.key: entry.value,
  };
}

/// Merges [incoming] posts into [current], newest first. Existing posts are
/// kept so optimistic state survives a refetch.
List<Post> mergePostsNewestFirst(List<Post> current, List<Post> incoming) {
  if (incoming.isEmpty) return current;

  final seen = current.map((p) => p.id).toSet();
  final additions = <Post>[];
  for (final post in incoming) {
    // An album's members can race and put one post in a batch twice.
    if (seen.add(post.id)) additions.add(post);
  }
  if (additions.isEmpty) return current;

  return [...current, ...additions]
    ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
}

/// The ordered pool of unread posts eligible for the mix. Append-only so the
/// blend stays stable while paging; cleared on refresh.
class BacklogIdsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

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

final backlogIdsProvider = NotifierProvider<BacklogIdsNotifier, List<String>>(
  BacklogIdsNotifier.new,
);

/// The feed, with paging and refresh. Only unread posts are admitted (see
/// [_admit]); posts read during a session stay until the next refresh.
class FeedNotifier extends AsyncNotifier<List<Post>> {
  final Map<int, int> _oldestMessageIds = {};

  /// Unread posts per channel found locally, so the backfill can skip them.
  final Map<int, int> _heldLocally = {};

  bool _isLoadingMore = false;
  StreamSubscription<List<Post>>? _backfillSub;

  /// Increments on every rebuild and dispose, so async work from a stale build
  /// stops writing. Riverpod keeps the notifier across rebuilds.
  int _generation = 0;

  @override
  Future<List<Post>> build() async {
    // Rebuild when sign-in completes; an earlier build gives an empty feed.
    ref.watch(authControllerProvider.select((auth) => auth.step));

    // And when the chat cache first learns about a channel.
    ref.watch(channelsKnownProvider);

    final repo = ref.watch(feedRepositoryProvider);
    final syncService = ref.watch(syncServiceProvider);
    final generation = _generation;

    final sub = syncService.livePostUpdates.listen((update) {
      if (update is LiveReactionsUpdate) {
        updateReactionsLive(
          update.postId,
          update.reactions,
          update.chosenReactions,
        );
      } else if (update is LivePollUpdate) {
        updatePollLive(update.postId, update.poll);
      } else if (update is LiveInteractionUpdate) {
        updateMetadataLive(
          update.postId,
          viewCount: update.viewCount,
          forwardCount: update.forwardCount,
        );
        // Interaction info is a user client's only source of reactions
        // (updateMessageReactions is bots-only).
        final reactions = update.reactions;
        final chosen = update.chosenReactions;
        if (reactions != null && chosen != null) {
          updateReactionsLive(update.postId, reactions, chosen);
        }
      }
    });
    ref.onDispose(() {
      _generation++;
      sub.cancel();
      _backfillSub?.cancel();
    });

    // Only the first fill shows the skeleton. Deferred because a provider
    // can't be modified while another is building.
    Future.microtask(() => ref.read(feedWarmupProvider.notifier).start());

    _oldestMessageIds.clear();
    _heldLocally.clear();

    // Load posts seen on earlier launches before admitting anything.
    await ref.read(seenPostsProvider.notifier).ready;
    if (generation != _generation) return const [];

    // The feed arrives in stages from TDLib's database, each painted by
    // assigning `state`; the return value is the last.
    var posts = const <Post>[];

    // Stage 1: one unread post per channel, from the chat list.
    try {
      final headlines = _admit(await repo.fetchHeadlinePosts());
      if (generation != _generation) return headlines;
      if (headlines.isNotEmpty) {
        posts = headlines;
        _updateOldestIds(posts);
        state = AsyncData(posts);
        StartupTrace.mark(
          'feed painted from channel headlines (${posts.length})',
        );
      }
    } catch (e) {
      debugPrint('[Feed] Headlines skipped: $e');
    }

    // Stage 2: unread posts on disk, whose fuller cards replace the headlines.
    await for (final stage in repo.fetchUnreadLocalPosts()) {
      if (generation != _generation) return posts;
      _noteHeldLocally(stage);
      final admitted = _admit(stage);
      if (admitted.isEmpty) continue;
      _updateOldestIds(admitted);
      posts = replacePostsNewestFirst(posts, admitted);
      state = AsyncData(posts);
      StartupTrace.mark('first feed posts (${posts.length})');
    }
    if (generation != _generation) return posts;

    // Seed the backlog mix early, from local data only.
    _poolBacklogCandidates(posts);
    _primeBacklogFromCache(repo, generation);
    _startBackfill(repo, generation);
    return posts;
  }

  void _noteHeldLocally(List<Post> stage) {
    for (final post in stage) {
      _heldLocally.update(post.chatId, (n) => n + 1, ifAbsent: () => 1);
    }
  }

  /// Fills the mix from TDLib's cache. Not awaited, so it doesn't delay the
  /// first paint.
  Future<void> _primeBacklogFromCache(
    FeedRepository repo,
    int generation,
  ) async {
    try {
      final cached = _admit(await repo.fetchCachedUnreadBacklog());
      if (cached.isEmpty || generation != _generation) return;

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

  /// Looks behind each channel's read cursor once the backfill is done, since
  /// it shares the request budget.
  Future<void> _sweepUnread(FeedRepository repo, int generation) async {
    try {
      final backlog = _admit(await repo.fetchUnreadBacklog());
      if (backlog.isEmpty || generation != _generation) return;

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

  /// Fetches, after the first paint, the unread posts that weren't on disk.
  void _startBackfill(FeedRepository repo, int generation) {
    _backfillSub?.cancel();
    _backfillSub = repo
        .backfillRecentHistory(heldLocally: Map.of(_heldLocally))
        .listen(
          _mergeBackfilled,
          onError: (Object e) {
            debugPrint('[Feed] Backfill error: $e');
            ref.read(feedWarmupProvider.notifier).finish();
          },
          onDone: () {
            // From here on an empty feed means caught up.
            ref.read(feedWarmupProvider.notifier).finish();
            if (generation == _generation) _sweepUnread(repo, generation);
          },
        );
  }

  /// Adds posts not already loaded, keeping existing entries.
  void _mergeBackfilled(List<Post> incoming) {
    final current = state.value ?? [];
    final existingIds = current.map((p) => p.id).toSet();
    final additions = _admit(
      incoming,
    ).where((p) => !existingIds.contains(p.id)).toList();
    if (additions.isEmpty) return;

    _updateOldestIds(additions);
    state = AsyncData(mergePostsNewestFirst(current, additions));
    ref.read(feedWarmupProvider.notifier).finish();
    _poolBacklogCandidates();
  }

  /// Offers everything unread behind the fresh window to the mix.
  void _poolBacklogCandidates([List<Post>? loaded]) {
    // Passed explicitly during `build`, where `state` isn't set yet.
    final posts = loaded ?? state.value;
    if (posts == null || posts.isEmpty) return;
    ref.read(backlogIdsProvider.notifier).add(selectBacklogCandidates(posts));
  }

  /// Adds new posts when the user taps the "new posts" pill.
  void prependPosts(List<Post> incoming) {
    final current = state.value ?? [];
    final merged = mergePostsNewestFirst(current, incoming);
    if (identical(merged, current)) return;
    state = AsyncData(merged);
  }

  /// Filters everything that fills the feed. See [unreadOnly].
  List<Post> _admit(List<Post> posts) => unreadOnly(
    posts,
    readHere: {
      ...ref.read(seenPostsProvider.notifier).postIds,
      ...ref.read(optimisticPostUpdatesProvider.notifier).readPostIds,
    },
  );

  void _updateOldestIds(List<Post> posts) {
    for (final post in posts) {
      final existing = _oldestMessageIds[post.chatId];
      if (existing == null || post.messageId < existing) {
        _oldestMessageIds[post.chatId] = post.messageId;
      }
    }
  }

  /// Loads older posts. [allowedChatIds] limits paging to one folder's
  /// channels; see also [cursorsWithUnreadBehind].
  Future<void> loadMore({Set<int>? allowedChatIds}) async {
    if (_isLoadingMore || _oldestMessageIds.isEmpty) return;

    final cursors = cursorsWithUnreadBehind(
      narrowCursors(_oldestMessageIds, allowedChatIds),
      ref.read(chatCacheProvider).chat,
    );
    if (cursors.isEmpty) return;

    _isLoadingMore = true;
    try {
      final repo = ref.read(feedRepositoryProvider);
      final older = await repo.fetchOlderPosts(cursors);
      // Move the cursor past everything fetched, read or not.
      _updateOldestIds(older);
      final olderPosts = _admit(older);
      if (olderPosts.isNotEmpty) {
        final current = state.value ?? [];
        final merged = mergePostsNewestFirst(current, olderPosts);
        if (!identical(merged, current)) state = AsyncData(merged);
        _poolBacklogCandidates();
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Pull to refresh. Posts read since the last fetch are left out.
  Future<void> refresh() async {
    _backfillSub?.cancel();
    // The blend only changes on refresh.
    ref.read(backlogIdsProvider.notifier).clear();
    _oldestMessageIds.clear();
    _heldLocally.clear();
    final generation = _generation;

    state = const AsyncLoading();
    final repo = ref.read(feedRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      var posts = const <Post>[];
      await for (final stage in repo.fetchUnreadLocalPosts()) {
        _noteHeldLocally(stage);
        posts = mergePostsNewestFirst(posts, _admit(stage));
      }
      _updateOldestIds(posts);
      return posts;
    });
    if (generation != _generation) return;
    state = result;
    if (!result.hasValue) return;

    _poolBacklogCandidates();
    _primeBacklogFromCache(repo, generation);
    _startBackfill(repo, generation);
  }

  /// Sets a post's bookmark locally without refetching.
  void setBookmarkedOptimistic(String postId, bool bookmarked) {
    final current = state.value;
    if (current == null) return;
    final updated = current.map((p) {
      if (p.id == postId) return p.copyWith(isBookmarked: bookmarked);
      return p;
    }).toList();
    state = AsyncData(updated);
  }

  /// Toggles a reaction locally without refetching.
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

  void updateReactionsLive(
    String postId,
    Map<String, int> reactions,
    Set<String> chosenReactions,
  ) {
    // The server's counts replace a reaction made here, in every view. It
    // was dropped instead, and views other than this list fell back to the
    // snapshot from before the tap.
    ref
        .read(optimisticPostUpdatesProvider.notifier)
        .refreshReactions(postId, reactions, chosenReactions);
    setReactions(postId, reactions, chosenReactions);
  }

  /// Sets a post's reactions in this list.
  void setReactions(
    String postId,
    Map<String, int> reactions,
    Set<String> chosenReactions,
  ) {
    final current = state.value;
    if (current == null) return;
    final updated = current.map((p) {
      if (p.id == postId) {
        return p.copyWith(
          reactions: reactions,
          chosenReactions: chosenReactions,
        );
      }
      return p;
    }).toList();
    state = AsyncData(updated);
  }

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

  /// Sets a post's poll in this list.
  void setPoll(String postId, Poll poll) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final p in current) p.id == postId ? p.copyWith(poll: poll) : p,
    ]);
  }

  /// A poll's real results: in every view for a poll voted on here, and in
  /// this list.
  void updatePollLive(String postId, Poll poll) {
    ref.read(optimisticPostUpdatesProvider.notifier).refreshPoll(postId, poll);
    setPoll(postId, poll);
  }

  /// Shows a saved edit without refetching. Entities are dropped, since the
  /// edit box saves plain text.
  void updateTextLive(String postId, String text) {
    final current = state.value;
    if (current == null) return;
    final updated = current.map((p) {
      if (p.id == postId) {
        return p.copyWith(text: text.isEmpty ? null : text, entities: const []);
      }
      return p;
    }).toList();
    state = AsyncData(updated);
  }

  /// Marks a post read locally without refetching.
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

/// True while the feed's first fill runs, so the feed shows a skeleton
/// rather than "no posts" while the backfill catches up.
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

final feedWarmupProvider = NotifierProvider<FeedWarmupNotifier, bool>(
  FeedWarmupNotifier.new,
);

final feedPostsProvider = AsyncNotifierProvider<FeedNotifier, List<Post>>(
  FeedNotifier.new,
);

/// Fetches a post by its `chatId_messageId` id, ignoring optimistic overrides
/// so a reaction doesn't refetch. Read [postDetailProvider] instead.
///
/// Fetched each time the post is opened; it used to keep the first copy for
/// the whole session.
final postDetailFetchProvider = FutureProvider.autoDispose
    .family<Post?, String>((ref, postId) async {
      final parts = postId.split('_');
      if (parts.length != 2) return null;
      final chatId = int.tryParse(parts[0]);
      final messageId = int.tryParse(parts[1]);
      if (chatId == null || messageId == null) return null;

      // A guest post has no TDLib message; the guest feed already holds it.
      if (GuestPostMapper.isSynthetic(chatId)) {
        final feed = await ref.watch(guestFeedProvider.future);
        return feed.posts.where((p) => p.id == postId).firstOrNull;
      }

      final repo = ref.watch(feedRepositoryProvider);
      return repo.fetchSinglePost(chatId, messageId);
    });

/// A single post with optimistic state applied.
final postDetailProvider = Provider.autoDispose
    .family<AsyncValue<Post?>, String>((ref, postId) {
      final overrides = ref.watch(optimisticPostUpdatesProvider);
      return ref
          .watch(postDetailFetchProvider(postId))
          .whenData(
            (post) => post == null ? null : applyPostOverrides(post, overrides),
          );
    });

/// The ids of channels muted right now. Rules and expiry times live in
/// [MuteRegistry].
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

  /// Mutes a channel for [duration].
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
    // A mute made where the channel's username was known is filed under it
    // too. Unmuting from a post that didn't carry it left the channel muted.
    for (final name in _usernamesOf(chatId)) {
      _registry.unmute(channelId, chatId: chatId, username: name);
    }
    _commit();
  }

  /// The channel's usernames, as TDLib knows them.
  Iterable<String> _usernamesOf(int? chatId) {
    if (chatId == null) return const [];
    final cache = ref.read(chatCacheProvider);
    final chat = cache.chat(chatId);
    if (chat == null) return const [];
    final usernames = cache.supergroupForChat(chat)?.usernames;
    return [
      ...?usernames?.activeUsernames,
      if (usernames?.editableUsername case final String name
          when name.isNotEmpty)
        name,
    ];
  }

  /// Mutes indefinitely, or unmutes.
  void toggleMute(String channelId, {int? chatId, String? username}) {
    if (isMuted(channelId, chatId: chatId, username: username)) {
      unmute(channelId, chatId: chatId, username: username);
    } else {
      mute(channelId, chatId: chatId, username: username);
    }
  }

  /// Publishes the active ids, saves them, and arms a timer for the next
  /// expiry.
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

    // A second of slack so the timer never fires just before the deadline.
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
      // Also reads the older format, a bare list of ids with no expiry.
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
      MutedChannelsNotifier.new,
    );

/// The folder tab on screen, so re-tapping Home scrolls the right feed.
class ActiveFolderNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void set(String folderId) {
    if (state != folderId) state = folderId;
  }
}

final activeFolderProvider = NotifierProvider<ActiveFolderNotifier, String>(
  ActiveFolderNotifier.new,
);

/// A request for one folder's feed to scroll to the top. The tick makes
/// repeated requests distinct.
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
      FeedScrollToTopNotifier.new,
    );

/// Fetches a post's comments. Overrides are applied by
/// [postCommentsProvider], so a reaction doesn't refetch the thread.
///
/// Fetched each time the post is opened; it used to keep the first thread
/// for the whole session.
final postCommentsFetchProvider = FutureProvider.autoDispose
    .family<List<Post>, String>((ref, postId) async {
      final parts = postId.split('_');
      if (parts.length != 2) return [];
      final chatId = int.tryParse(parts[0]);
      final messageId = int.tryParse(parts[1]);
      if (chatId == null || messageId == null) return [];

      final repo = ref.watch(feedRepositoryProvider);
      return repo.fetchPostComments(chatId, messageId);
    });

/// The comment thread with optimistic reaction state applied.
final postCommentsProvider = Provider.autoDispose
    .family<AsyncValue<List<Post>>, String>((ref, postId) {
      final overrides = ref.watch(optimisticPostUpdatesProvider);
      return ref
          .watch(postCommentsFetchProvider(postId))
          .whenData(
            (comments) =>
                comments.map((c) => applyPostOverrides(c, overrides)).toList(),
          );
    });

/// Marks a post read because the user opened it.
final markPostAsReadProvider = FutureProvider.family<void, String>((
  ref,
  postId,
) async {
  ref.read(optimisticPostUpdatesProvider.notifier).markRead(postId);
  ref.read(feedPostsProvider.notifier).markReadOptimistic(postId);

  // Batched with pending acks for the chat, then sent at once.
  final queue = ref.read(readReceiptQueueProvider.notifier);
  queue.add(postId);
  await queue.flush();
});

/// Reads a chat folder title, which TDLib gives as a String, FormattedText
/// or decoded map.
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

/// A folder to open from outside the feed, consumed once by the feed.
class RequestedFolderNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void request(String folderId) => state = folderId;

  /// Reads and clears, so the request fires once.
  String? consume() {
    final value = state;
    if (value != null) state = null;
    return value;
  }
}

final requestedFolderProvider =
    NotifierProvider<RequestedFolderNotifier, String?>(
      RequestedFolderNotifier.new,
    );

/// The user's chat folders from Telegram, updated live.
final foldersProvider = StreamProvider<List<td.ChatFolderInfo>>((ref) async* {
  final tdlib = ref.watch(tdlibServiceProvider);
  yield tdlib.chatFolders;
  await for (final update in tdlib.updatesStream) {
    if (update is td.UpdateChatFolders) {
      yield update.chatFolders;
    }
  }
});

/// The channel ids in each folder.
final folderChannelIdsProvider = FutureProvider.family<Set<String>, int>((
  ref,
  folderId,
) async {
  // Rebuild once the cache fills, or the folder looks empty.
  ref.watch(channelsKnownProvider);
  // And when a folder is edited or a channel joined or left, which can change
  // what's in it; the tab used to keep its first answer.
  ref.watch(foldersProvider);
  ref.watch(channelsProvider);

  final folderRepo = ref.watch(folderRepositoryProvider);
  final allowedChannelIds = await folderRepo.getFolderChannelChatIds(folderId);
  return allowedChannelIds.map((id) => id.toString()).toSet();
});

/// Whether folder [folderId] is an unread-style filter. See
/// `folderHasChannels` in `home_screen.dart`.
final folderExcludesReadProvider = FutureProvider.family<bool, int>((
  ref,
  folderId,
) async {
  // A folder edited in Telegram can change it.
  ref.watch(foldersProvider);
  final folderRepo = ref.watch(folderRepositoryProvider);
  return folderRepo.folderExcludesRead(folderId);
});

bool _isPostMuted(Post post, Set<String> mutedIds) {
  if (mutedIds.isEmpty) return false;
  // See MuteRegistry.aliasesOf.
  return MuteRegistry.aliasesOf(
    post.channelId,
    chatId: post.chatId,
    username: post.channelUsername,
  ).any(mutedIds.contains);
}

class OptimisticPostUpdatesNotifier
    extends Notifier<Map<String, Map<String, dynamic>>> {
  @override
  Map<String, Map<String, dynamic>> build() => {};

  void toggleReaction(String postId, String emoji, Post currentPost) {
    final currentData = state[postId] ?? {};
    final next = applyReactionChoice(
      reactions:
          (currentData['reactions'] as Map<String, int>?) ??
          currentPost.reactions,
      chosen:
          (currentData['chosenReactions'] as Set<String>?) ??
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

  /// Shows [reactions] for [postId] until the data catches up.
  void setReactions(
    String postId,
    Map<String, int> reactions,
    Set<String> chosenReactions,
  ) {
    state = {
      ...state,
      postId: {
        ...?state[postId],
        'reactions': reactions,
        'chosenReactions': chosenReactions,
      },
    };
  }

  /// Replaces a reaction made here with the server's counts, so every view
  /// shows them. Posts not reacted to here are left to their own data.
  void refreshReactions(
    String postId,
    Map<String, int> reactions,
    Set<String> chosenReactions,
  ) {
    if (state[postId]?.containsKey('reactions') ?? false) {
      setReactions(postId, reactions, chosenReactions);
    }
  }

  /// Shows [poll] for [postId] until the data catches up.
  void setPoll(String postId, Poll poll) {
    state = {
      ...state,
      postId: {...?state[postId], 'poll': poll},
    };
  }

  /// Replaces a vote made here with Telegram's results, in every view.
  void refreshPoll(String postId, Poll poll) {
    if (state[postId]?.containsKey('poll') ?? false) setPoll(postId, poll);
  }

  /// Drops the optimistic reaction guess once the server reports real counts.
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
    // Keep bookmark and read overrides for this post.
    if (remaining.isEmpty) {
      next.remove(postId);
    } else {
      next[postId] = remaining;
    }
    state = next;
  }

  /// Shows [postId] as bookmarked or not until the data catches up.
  void setBookmarked(String postId, bool bookmarked) {
    final currentData = state[postId] ?? {};
    state = {
      ...state,
      postId: {...currentData, 'isBookmarked': bookmarked},
    };
  }

  /// Posts marked read here, so a refresh doesn't bring one back while its
  /// acknowledgement is queued.
  Set<String> get readPostIds => {
    for (final entry in state.entries)
      if (entry.value['isRead'] == true) entry.key,
  };

  void markRead(String postId) {
    final currentData = state[postId] ?? {};
    state = {
      ...state,
      postId: {...currentData, 'isRead': true},
    };
  }

  /// Records an edit the user made, so it shows without refetching.
  void setText(String postId, String text) {
    final currentData = state[postId] ?? {};
    state = {
      ...state,
      postId: {...currentData, 'text': text},
    };
  }
}

final optimisticPostUpdatesProvider =
    NotifierProvider<
      OptimisticPostUpdatesNotifier,
      Map<String, Map<String, dynamic>>
    >(OptimisticPostUpdatesNotifier.new);

Post applyPostOverrides(
  Post post,
  Map<String, Map<String, dynamic>> overrides,
) {
  final data = overrides[post.id];
  if (data == null) return post;
  final text = data['text'] as String?;
  final edited = text == null
      ? post
      // The old entities would point at the wrong characters in the new text.
      : post.copyWith(text: text.isEmpty ? null : text, entities: const []);
  return edited.copyWith(
    poll: data['poll'] as Poll? ?? post.poll,
    reactions: data['reactions'] as Map<String, int>? ?? post.reactions,
    chosenReactions:
        data['chosenReactions'] as Set<String>? ?? post.chosenReactions,
    isBookmarked: data['isBookmarked'] as bool? ?? post.isBookmarked,
    isRead: data['isRead'] as bool? ?? post.isRead,
  );
}

/// Applies the folder and mute filters. Shared with the new posts pill so
/// counts match.
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
      .where(
        (post) =>
            allowed.contains(post.channelId) ||
            allowed.contains(post.chatId.toString()),
      )
      .toList();
}

/// Posts for a folder tab, filtered, with optimistic state applied.
final filteredFeedPostsProvider =
    Provider.family<AsyncValue<List<Post>>, String>((ref, folderIdStr) {
      final postsAsync = ref.watch(feedPostsProvider);
      final overrides = ref.watch(optimisticPostUpdatesProvider);

      final folderId = int.tryParse(folderIdStr);
      if (folderIdStr != 'All' && folderId != null) {
        final folderChannelsAsync = ref.watch(
          folderChannelIdsProvider(folderId),
        );
        if (folderChannelsAsync.isLoading && !folderChannelsAsync.hasValue) {
          return const AsyncValue.loading();
        }
        if (folderChannelsAsync.hasError && !folderChannelsAsync.hasValue) {
          return AsyncValue.error(
            folderChannelsAsync.error!,
            folderChannelsAsync.stackTrace!,
          );
        }
      }

      return postsAsync.whenData(
        (posts) => filterPostsForFolder(
          ref,
          posts,
          folderIdStr,
        ).map((p) => applyPostOverrides(p, overrides)).toList(),
      );
    });
