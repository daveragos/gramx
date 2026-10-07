import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';

/// The bookmarks, most recently bookmarked first, and which of them were
/// restored from Saved Messages.
final bookmarksProvider =
    FutureProvider<({List<Post> posts, Set<String> restoredIds})>(
      (ref) => ref.watch(feedRepositoryProvider).loadBookmarks(),
    );

/// The bookmarked posts as shown: with this session's changes applied, and
/// without any unbookmarked since the list loaded.
final bookmarkedPostsProvider = Provider<AsyncValue<List<Post>>>((ref) {
  final overrides = ref.watch(optimisticPostUpdatesProvider);
  return ref
      .watch(bookmarksProvider)
      .whenData(
        (bookmarks) => [
          for (final post in bookmarks.posts)
            if (applyPostOverrides(post, overrides) case final shown
                when shown.isBookmarked)
              shown,
        ],
      );
});

/// Which bookmarks the list shows.
enum BookmarkFilter {
  all,

  /// Bookmarked in gramX.
  here,

  /// Restored from Saved Messages.
  restored,
}

class BookmarkFilterNotifier extends Notifier<BookmarkFilter> {
  @override
  BookmarkFilter build() => BookmarkFilter.all;

  void set(BookmarkFilter filter) => state = filter;
}

final bookmarkFilterProvider =
    NotifierProvider<BookmarkFilterNotifier, BookmarkFilter>(
      BookmarkFilterNotifier.new,
    );

/// The bookmarks the chosen filter lets through.
List<Post> filterBookmarks(
  List<Post> posts,
  Set<String> restoredIds,
  BookmarkFilter filter,
) => switch (filter) {
  BookmarkFilter.all => posts,
  BookmarkFilter.here => [
    for (final post in posts)
      if (!restoredIds.contains(post.id)) post,
  ],
  BookmarkFilter.restored => [
    for (final post in posts)
      if (restoredIds.contains(post.id)) post,
  ],
};

/// Bookmarks and unbookmarks posts, from every bookmark button.
///
/// It sets the state the button shows the opposite of, rather than flipping
/// whatever the database holds, and shows it at once. Writes for one post
/// run one after another, so quick taps land in order. Each button used to
/// run a provider that only ever ran once per post, so a second tap did
/// nothing and a bookmark couldn't be removed.
class BookmarkController extends Notifier<void> {
  final Map<String, Future<void>> _pending = {};

  @override
  void build() {}

  /// Bookmarks [post], or removes its bookmark if it shows one.
  Future<void> toggle(Post post) {
    final shown = applyPostOverrides(
      post,
      ref.read(optimisticPostUpdatesProvider),
    ).isBookmarked;
    return set(post, bookmarked: !shown);
  }

  Future<void> set(Post post, {required bool bookmarked}) {
    ref
        .read(optimisticPostUpdatesProvider.notifier)
        .setBookmarked(post.id, bookmarked);
    ref
        .read(feedPostsProvider.notifier)
        .setBookmarkedOptimistic(post.id, bookmarked);

    final repo = ref.read(feedRepositoryProvider);
    final write = (_pending[post.id] ?? Future<void>.value()).then(
      (_) => repo.setBookmarked(
        post.chatId,
        post.messageId,
        bookmarked: bookmarked,
      ),
    );
    _pending[post.id] = write;
    return write.whenComplete(() {
      if (identical(_pending[post.id], write)) _pending.remove(post.id);
      ref.invalidate(bookmarksProvider);
    });
  }
}

final bookmarkControllerProvider = NotifierProvider<BookmarkController, void>(
  BookmarkController.new,
);
