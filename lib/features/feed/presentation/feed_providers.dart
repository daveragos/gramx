import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/folders/data/folder_repository.dart';

/// Provides the full feed of posts (all channels), sorted by publishedAt desc.
final feedPostsProvider = FutureProvider<List<Post>>((ref) async {
  final repo = ref.watch(feedRepositoryProvider);
  return repo.fetchFeedPosts();
});

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
    FutureProvider.family<void, String>((ref, postId) async {
  final repo = ref.read(feedRepositoryProvider);
  final parts = postId.split('_');
  if (parts.length != 2) return;
  final chatId = int.tryParse(parts[0]);
  final messageId = int.tryParse(parts[1]);
  if (chatId == null || messageId == null) return;
  
  await repo.markPostAsRead(chatId, messageId);
  ref.invalidate(feedPostsProvider);
});

/// Provider to trigger loading more history for pagination
final loadMoreChannelHistoryProvider =
    FutureProvider.family<void, ({int chatId, int fromMessageId})>((ref, arg) async {
  final repo = ref.read(feedRepositoryProvider);
  await repo.fetchChannelPosts(arg.chatId, fromMessageId: arg.fromMessageId);
  ref.invalidate(feedPostsProvider);
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
  final allowedChannelIdsStr = allowedChannelIds.map((id) => id.toString()).toSet();
  
  return posts.where((post) => allowedChannelIdsStr.contains(post.channelId)).toList();
});
