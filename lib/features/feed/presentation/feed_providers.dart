import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';

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

/// Filtered posts by folder/category
final filteredFeedPostsProvider =
    Provider.family<AsyncValue<List<Post>>, String>((ref, folder) {
  final postsAsync = ref.watch(feedPostsProvider);
  return postsAsync.whenData((posts) {
    if (folder == 'All') return posts;
    final folderLower = folder.toLowerCase();
    return posts.where((post) {
      final title = post.channelTitle.toLowerCase();
      final username = post.channelUsername?.toLowerCase() ?? '';
      
      if (folderLower == 'tech') {
        return title.contains('tech') ||
            title.contains('flutter') ||
            username.contains('tech') ||
            username.contains('flutter');
      } else if (folderLower == 'crypto') {
        return title.contains('crypto') || username.contains('crypto');
      } else if (folderLower == 'news') {
        return title.contains('news') || username.contains('news');
      } else if (folderLower == 'design') {
        return title.contains('design') || username.contains('design');
      }
      return false;
    }).toList();
  });
});

