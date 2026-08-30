import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/guest/presentation/widgets/guest_bookmarks_placeholder.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';

import 'package:gramx/features/feed/data/feed_repository.dart';

/// Provider to fetch bookmarked posts directly from database and TDLib.
final bookmarkedPostsProvider = FutureProvider<List<Post>>((ref) async {
  final repo = ref.watch(feedRepositoryProvider);
  final posts = await repo.fetchBookmarkedPosts();
  final overrides = ref.watch(optimisticPostUpdatesProvider);
  return posts.map((p) => applyPostOverrides(p, overrides)).toList();
});

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  /// Reads the bookmarks back out of Saved Messages.
  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final added = await ref.read(feedRepositoryProvider).restoreBookmarks();
    if (added > 0) ref.invalidate(bookmarkedPostsProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(AppStrings.bookmarksRestored(added)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Bookmarks are stored against the signed-in account, so a guest has none
    // and never will. Saying so beats an empty list that looks broken.
    if (!ref.watch(readerCapabilitiesProvider).canBookmark) {
      return const GuestBookmarksPlaceholder();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final bookmarksAsync = ref.watch(bookmarkedPostsProvider);

    return ChromeScaffold(
      header: ChromeHeaderRow(
        title: AppStrings.bookmarksTitle,
        actions: [
          // A bookmark is mirrored into Saved Messages so it survives a
          // reinstall; this is the way back in. Offered rather than run
          // automatically: a reader who cleared their bookmarks should not
          // have them reappear because the app decided to be helpful.
          IconButton(
            icon: const Icon(Icons.restore_rounded),
            tooltip: AppStrings.bookmarksRestore,
            onPressed: () => _restore(context, ref),
          ),
        ],
      ),
      body: (context, topPadding, bottomPadding) => bookmarksAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: Text(AppStrings.bookmarksError(err)),
          ),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.bookmark_outline,
                        color: AppColors.accent,
                        size: 80,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        AppStrings.bookmarksEmptyTitle,
                        style: AppTypography.heading(color: primaryColor)
                            .copyWith(fontSize: 22),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        AppStrings.bookmarksEmptyBody,
                        style: AppTypography.body(color: secondaryColor),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.accent,
            edgeOffset: topPadding,
            onRefresh: () async {
              ref.invalidate(bookmarkedPostsProvider);
            },
            child: ListView.builder(
              padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return PostCard(
                  post: post,
                  onTap: () {
                    ref.read(markPostAsReadProvider(post.id));
                    context.push('/post/${post.id}');
                  },
                  onChannelTap: () =>
                      NavigationUtils.openChannel(context, post.channelId),
                  onBookmarkTap: () {
                    ref.read(bookmarkToggleProvider(post.id));
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
