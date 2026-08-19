import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/folders/data/folder_repository.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';

/// Stateful feed notifier that supports appending older posts (pagination)
/// and full refresh without destroying state.
class FeedNotifier extends AsyncNotifier<List<Post>> {
  final Map<int, int> _oldestMessageIds = {};
  bool _isLoadingMore = false;
  StreamSubscription<List<Post>>? _backfillSub;

  @override
  Future<List<Post>> build() async {
    final repo = ref.watch(feedRepositoryProvider);
    final syncService = ref.watch(syncServiceProvider);

    final sub = syncService.livePostUpdates.listen((update) {
      if (update is LiveReactionsUpdate) {
        updateReactionsLive(update.postId, update.reactions, update.chosenReactions);
      } else if (update is LiveInteractionUpdate) {
        updateMetadataLive(update.postId, viewCount: update.viewCount, forwardCount: update.forwardCount);
      }
    });
    ref.onDispose(() {
      sub.cancel();
      _backfillSub?.cancel();
    });

    final posts = await repo.fetchFeedPosts();
    _updateOldestIds(posts);
    _startBackfill(repo);
    return posts;
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
      onError: (Object e) => debugPrint('[Feed] Backfill error: $e'),
    );
  }

  /// Adds posts we don't already have, leaving existing entries untouched so
  /// optimistic reaction and bookmark state survives.
  void _mergeBackfilled(List<Post> incoming) {
    final current = state.value ?? [];
    final existingIds = current.map((p) => p.id).toSet();
    final additions =
        incoming.where((p) => !existingIds.contains(p.id)).toList();
    if (additions.isEmpty) return;

    _updateOldestIds(additions);
    final merged = [...current, ...additions]
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    state = AsyncData(merged);
  }

  /// Track the oldest messageId per channel for cursor-based pagination.
  void _updateOldestIds(List<Post> posts) {
    for (final post in posts) {
      final existing = _oldestMessageIds[post.chatId];
      if (existing == null || post.messageId < existing) {
        _oldestMessageIds[post.chatId] = post.messageId;
      }
    }
  }

  /// Load more (older) posts and APPEND to existing state.
  Future<void> loadMore() async {
    if (_isLoadingMore || _oldestMessageIds.isEmpty) return;
    _isLoadingMore = true;
    try {
      final repo = ref.read(feedRepositoryProvider);
      final olderPosts = await repo.fetchOlderPosts(_oldestMessageIds);
      if (olderPosts.isNotEmpty) {
        _updateOldestIds(olderPosts);
        final current = state.value ?? [];
        final existingIds = current.map((p) => p.id).toSet();
        final newPosts =
            olderPosts.where((p) => !existingIds.contains(p.id)).toList();
        if (newPosts.isNotEmpty) {
          final merged = [...current, ...newPosts]
            ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
          state = AsyncData(merged);
        }
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Full refresh: re-fetch from scratch (for pull-to-refresh).
  Future<void> refresh() async {
    _backfillSub?.cancel();
    _oldestMessageIds.clear();
    state = const AsyncLoading();
    final repo = ref.read(feedRepositoryProvider);
    state = await AsyncValue.guard(() async {
      final posts = await repo.fetchFeedPosts();
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
        final newReactions = Map<String, int>.from(p.reactions);
        final newChosen = Set<String>.from(p.chosenReactions);
        if (newChosen.contains(emoji)) {
          // User is removing their reaction
          newChosen.remove(emoji);
          final count = (newReactions[emoji] ?? 1) - 1;
          if (count <= 0) {
            newReactions.remove(emoji);
          } else {
            newReactions[emoji] = count;
          }
        } else {
          // User is adding a reaction
          newChosen.add(emoji);
          newReactions[emoji] = (newReactions[emoji] ?? 0) + 1;
        }
        return p.copyWith(reactions: newReactions, chosenReactions: newChosen);
      }
      return p;
    }).toList();
    state = AsyncData(updated);
  }

  /// Live update reactions from TDLib UpdateMessageReactions stream
  void updateReactionsLive(String postId, Map<String, int> reactions, Set<String> chosenReactions) {
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

/// Main feed posts provider — uses AsyncNotifier for stateful pagination.
final feedPostsProvider =
    AsyncNotifierProvider<FeedNotifier, List<Post>>(FeedNotifier.new);

/// Provides a single post by its composite ID (chatId_messageId).
final postDetailProvider =
    FutureProvider.family<Post?, String>((ref, postId) async {
  final parts = postId.split('_');
  if (parts.length != 2) return null;
  final chatId = int.tryParse(parts[0]);
  final messageId = int.tryParse(parts[1]);
  if (chatId == null || messageId == null) return null;

  final repo = ref.watch(feedRepositoryProvider);
  final post = await repo.fetchSinglePost(chatId, messageId);
  if (post == null) return null;

  final overrides = ref.watch(optimisticPostUpdatesProvider);
  return applyPostOverrides(post, overrides);
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

/// Provider managing muted channel IDs with local file persistence.
class MutedChannelsNotifier extends Notifier<Set<String>> {
  static const String _fileName = 'muted_channels.json';

  @override
  Set<String> build() {
    _loadFromDisk();
    return {};
  }

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> _loadFromDisk() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> list = jsonDecode(content);
        state = list.map((e) => e.toString()).toSet();
      }
    } catch (e) {
      debugPrint('[MutedChannels] Error loading from disk: $e');
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final file = await _getFile();
      await file.writeAsString(jsonEncode(state.toList()));
    } catch (e) {
      debugPrint('[MutedChannels] Error saving to disk: $e');
    }
  }

  void toggleMute(String channelId, {int? chatId, String? username}) {
    final idsToToggle = <String>{
      channelId,
      if (chatId != null) chatId.toString(),
      if (chatId != null) chatId.abs().toString(),
      if (chatId != null) '-100${chatId.abs()}',
      if (username != null && username.isNotEmpty) username,
    };

    final isCurrentlyMuted = state.any((id) => idsToToggle.contains(id));

    if (isCurrentlyMuted) {
      state = state.where((id) => !idsToToggle.contains(id)).toSet();
    } else {
      state = {...state, ...idsToToggle};
    }
    _saveToDisk();
  }

  bool isMuted(String channelId, {int? chatId, String? username}) {
    if (state.isEmpty) return false;
    final idsToCheck = <String>{
      channelId,
      if (chatId != null) chatId.toString(),
      if (chatId != null) chatId.abs().toString(),
      if (chatId != null) '-100${chatId.abs()}',
      if (username != null && username.isNotEmpty) username,
    };
    return state.any((id) => idsToCheck.contains(id));
  }
}

final mutedChannelsProvider =
    NotifierProvider<MutedChannelsNotifier, Set<String>>(
        MutedChannelsNotifier.new);

/// Bottom navigation visibility state provider
class BottomNavVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void show() => state = true;
  void hide() => state = false;
  void setVisible(bool visible) {
    if (state != visible) state = visible;
  }
}

final bottomNavVisibilityProvider =
    NotifierProvider<BottomNavVisibilityNotifier, bool>(
        BottomNavVisibilityNotifier.new);

/// Provider for real-time post comments thread
final postCommentsProvider =
    FutureProvider.family<List<Post>, String>((ref, postId) async {
  final parts = postId.split('_');
  if (parts.length != 2) return [];
  final chatId = int.tryParse(parts[0]);
  final messageId = int.tryParse(parts[1]);
  if (chatId == null || messageId == null) return [];

  final repo = ref.watch(feedRepositoryProvider);
  return repo.fetchPostComments(chatId, messageId);
});

/// Provider to mark post as read
final markPostAsReadProvider =
    FutureProvider.family<void, String>((ref, postId) async {
  final repo = ref.read(feedRepositoryProvider);
  final parts = postId.split('_');
  if (parts.length != 2) return;
  final chatId = int.tryParse(parts[0]);
  final messageId = int.tryParse(parts[1]);
  if (chatId == null || messageId == null) return;

  // Optimistic local state update
  ref.read(feedPostsProvider.notifier).markReadOptimistic(postId);

  await repo.markPostAsRead(chatId, messageId);
});

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
  final folderRepo = ref.watch(folderRepositoryProvider);
  final allowedChannelIds = await folderRepo.getFolderChannelChatIds(folderId);
  return allowedChannelIds.map((id) => id.toString()).toSet();
});

bool _isPostMuted(Post post, Set<String> mutedIds) {
  if (mutedIds.isEmpty) return false;
  final possibleIds = <String>{
    post.channelId,
    post.chatId.toString(),
    post.chatId.abs().toString(),
    '-100${post.chatId.abs()}',
    if (post.channelUsername != null) post.channelUsername!,
  };
  return possibleIds.any((id) => mutedIds.contains(id));
}

class OptimisticPostUpdatesNotifier extends Notifier<Map<String, Map<String, dynamic>>> {
  @override
  Map<String, Map<String, dynamic>> build() => {};

  void toggleReaction(String postId, String emoji, Post currentPost) {
    final currentData = state[postId] ?? {};
    final Map<String, int> reactions = Map<String, int>.from(currentData['reactions'] ?? currentPost.reactions);
    final Set<String> chosen = Set<String>.from(currentData['chosenReactions'] ?? currentPost.chosenReactions);

    if (chosen.contains(emoji)) {
      chosen.remove(emoji);
      final count = (reactions[emoji] ?? 1) - 1;
      if (count <= 0) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = count;
      }
    } else {
      chosen.add(emoji);
      reactions[emoji] = (reactions[emoji] ?? 0) + 1;
    }

    state = {
      ...state,
      postId: {
        ...currentData,
        'reactions': reactions,
        'chosenReactions': chosen,
      },
    };
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

/// Filtered posts by folder/category and excluding muted channels.
/// Synchronous Provider returning `AsyncValue<List<Post>>` to ensure instant 0ms
/// state updates when post actions (reactions, bookmarks) occur.
final filteredFeedPostsProvider =
    Provider.family<AsyncValue<List<Post>>, String>((ref, folderIdStr) {
  final postsAsync = ref.watch(feedPostsProvider);
  final mutedChannelIds = ref.watch(mutedChannelsProvider);
  final overrides = ref.watch(optimisticPostUpdatesProvider);

  if (folderIdStr == 'All') {
    return postsAsync.whenData((posts) {
      var list = posts;
      if (mutedChannelIds.isNotEmpty) {
        list = list.where((p) => !_isPostMuted(p, mutedChannelIds)).toList();
      }
      return list.map((p) => applyPostOverrides(p, overrides)).toList();
    });
  }

  final folderId = int.tryParse(folderIdStr);
  if (folderId == null) {
    return postsAsync.whenData((posts) {
      var list = posts;
      if (mutedChannelIds.isNotEmpty) {
        list = list.where((p) => !_isPostMuted(p, mutedChannelIds)).toList();
      }
      return list.map((p) => applyPostOverrides(p, overrides)).toList();
    });
  }

  final folderChannelsAsync = ref.watch(folderChannelIdsProvider(folderId));

  if (folderChannelsAsync.isLoading && !folderChannelsAsync.hasValue) {
    return const AsyncValue.loading();
  }
  if (folderChannelsAsync.hasError && !folderChannelsAsync.hasValue) {
    return AsyncValue.error(folderChannelsAsync.error!, folderChannelsAsync.stackTrace!);
  }

  final allowedChannelIdsStr = folderChannelsAsync.value ?? {};

  return postsAsync.whenData((posts) {
    var filtered = posts;
    if (mutedChannelIds.isNotEmpty) {
      filtered = filtered.where((p) => !_isPostMuted(p, mutedChannelIds)).toList();
    }
    if (allowedChannelIdsStr.isEmpty) {
      return [];
    }
    return filtered
        .where((post) =>
            allowedChannelIdsStr.contains(post.channelId) ||
            allowedChannelIdsStr.contains(post.chatId.toString()))
        .map((p) => applyPostOverrides(p, overrides))
        .toList();
  });
});
