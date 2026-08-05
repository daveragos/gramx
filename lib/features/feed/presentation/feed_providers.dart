import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/folders/data/folder_repository.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// Stateful feed notifier that supports appending older posts (pagination)
/// and full refresh without destroying state.
class FeedNotifier extends AsyncNotifier<List<Post>> {
  final Map<int, int> _oldestMessageIds = {};
  bool _isLoadingMore = false;

  @override
  Future<List<Post>> build() async {
    final repo = ref.watch(feedRepositoryProvider);
    final posts = await repo.fetchFeedPosts();
    _updateOldestIds(posts);
    return posts;
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
    _oldestMessageIds.clear();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(feedRepositoryProvider);
      final posts = await repo.fetchFeedPosts();
      _updateOldestIds(posts);
      return posts;
    });
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
        if (newReactions.containsKey(emoji)) {
          final count = newReactions[emoji]! - 1;
          if (count <= 0) {
            newReactions.remove(emoji);
          } else {
            newReactions[emoji] = count;
          }
        } else {
          newReactions[emoji] = (newReactions[emoji] ?? 0) + 1;
        }
        return p.copyWith(reactions: newReactions);
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
  if (chatId == null) return null;

  final repo = ref.watch(feedRepositoryProvider);
  final posts = await repo.fetchChannelPosts(chatId);
  return posts.where((p) => p.id == postId).firstOrNull;
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

/// Provider managing muted channel IDs
class MutedChannelsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggleMute(String channelId) {
    if (state.contains(channelId)) {
      state = {...state}..remove(channelId);
    } else {
      state = {...state, channelId};
    }
  }

  bool isMuted(String channelId) => state.contains(channelId);
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

/// Filtered posts by folder/category and excluding muted channels
final filteredFeedPostsProvider =
    FutureProvider.family<List<Post>, String>((ref, folderIdStr) async {
  var posts = await ref.watch(feedPostsProvider.future);

  // Exclude muted channels
  final mutedChannelIds = ref.watch(mutedChannelsProvider);
  if (mutedChannelIds.isNotEmpty) {
    posts = posts.where((p) => !mutedChannelIds.contains(p.channelId)).toList();
  }

  if (folderIdStr == 'All') {
    return posts;
  }

  final folderId = int.tryParse(folderIdStr);
  if (folderId == null) {
    return posts;
  }

  final folderRepo = ref.watch(folderRepositoryProvider);
  final allowedChannelIds = await folderRepo.getFolderChannelChatIds(folderId);
  final allowedChannelIdsStr =
      allowedChannelIds.map((id) => id.toString()).toSet();

  return posts
      .where((post) => allowedChannelIdsStr.contains(post.channelId))
      .toList();
});
