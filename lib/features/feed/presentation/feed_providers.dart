import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/folders/data/folder_repository.dart';

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

  await repo.toggleBookmark(chatId, messageId);
  // Refresh feed to reflect bookmark change
  await ref.read(feedPostsProvider.notifier).refresh();
});

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

/// Provides user's dynamic folders synced from Telegram
final foldersProvider = FutureProvider<List<td.ChatFolderInfo>>((ref) async {
  final repo = ref.watch(folderRepositoryProvider);
  return repo.getFolders();
});

/// Filtered posts by folder/category
final filteredFeedPostsProvider =
    FutureProvider.family<List<Post>, String>((ref, folderIdStr) async {
  final posts = await ref.watch(feedPostsProvider.future);

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
