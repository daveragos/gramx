import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';

/// Provides the full feed of posts (all channels), sorted by publishedAt desc.
final feedPostsProvider = StreamProvider<List<Post>>((ref) {
  final repo = ref.watch(feedRepositoryProvider);
  return repo.watchFeedPosts();
});

/// Provides a single post by its database ID.
final postDetailProvider =
    FutureProvider.family<Post?, String>((ref, postId) async {
  final repo = ref.watch(feedRepositoryProvider);
  final id = int.tryParse(postId);
  if (id == null) return null;
  return repo.getPostById(id);
});

/// Toggle bookmark action — call this to flip bookmark state.
final bookmarkToggleProvider =
    FutureProvider.family<void, String>((ref, postId) async {
  final repo = ref.watch(feedRepositoryProvider);
  final id = int.tryParse(postId);
  if (id == null) return;
  await repo.toggleBookmark(id);
  // Invalidate feed to reflect change
  ref.invalidate(feedPostsProvider);
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
    NotifierProvider<BottomNavVisibilityNotifier, bool>(BottomNavVisibilityNotifier.new);

/// Provider to mark post as read
final markPostAsReadProvider =
    FutureProvider.family<void, int>((ref, postDbId) async {
  final repo = ref.watch(feedRepositoryProvider);
  await repo.markPostAsRead(postDbId, ref);
  ref.invalidate(feedPostsProvider);
});

/// Provider to trigger loading more history for pagination
final loadMoreChannelHistoryProvider =
    FutureProvider.family<void, ({int channelDbId, int chatId})>((ref, arg) async {
  final syncService = ref.read(syncServiceProvider);
  await syncService.loadMoreChannelHistory(arg.channelDbId, arg.chatId);
  ref.invalidate(feedPostsProvider);
});

/// Provides user's dynamic folders synced from Telegram
final foldersProvider = StreamProvider<List<FolderEntry>>((ref) {
  final repo = ref.watch(feedRepositoryProvider);
  return repo.db.select(repo.db.folders).watch();
});

/// Provides the mapping of folder ID to its channel database IDs
final folderChannelsMapProvider = StreamProvider<Map<int, List<int>>>((ref) {
  final repo = ref.watch(feedRepositoryProvider);
  final select = repo.db.select(repo.db.folderChannels);
  return select.watch().map((rows) {
    final map = <int, List<int>>{};
    for (final row in rows) {
      map.putIfAbsent(row.folderDbId, () => []).add(row.channelDbId);
    }
    return map;
  });
});

/// Filtered posts by folder/category (watching dynamic folder list)
final filteredFeedPostsProvider =
    Provider.family<AsyncValue<List<Post>>, String>((ref, folderIdStr) {
  final postsAsync = ref.watch(feedPostsProvider);

  if (folderIdStr == 'All') {
    return postsAsync;
  }

  final folderId = int.tryParse(folderIdStr);
  if (folderId == null) {
    return postsAsync;
  }

  final folderChannelsMapAsync = ref.watch(folderChannelsMapProvider);
  return postsAsync.when(
    data: (posts) {
      return folderChannelsMapAsync.when(
        data: (map) {
          final allowedChannelIds = map[folderId] ?? [];
          final allowedChannelIdsStr = allowedChannelIds.map((id) => id.toString()).toSet();
          return AsyncValue.data(
            posts.where((post) => allowedChannelIdsStr.contains(post.channelId)).toList(),
          );
        },
        loading: () => const AsyncValue.loading(),
        error: (err, stack) => AsyncValue.error(err, stack),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});
