import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/core/l10n/app_strings.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final bookmarksAsync = ref.watch(bookmarkedPostsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.bookmarksTitle,
          style: AppTypography.heading(color: primaryColor),
        ),
      ),
      body: bookmarksAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(
          child: Text('Error loading bookmarks: $err'),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
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
                      style: AppTypography.heading(color: primaryColor).copyWith(fontSize: 22),
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
            );
          }

          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async {
              ref.invalidate(bookmarkedPostsProvider);
            },
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return PostCard(
                  post: post,
                  onTap: () {
                    ref.read(markPostAsReadProvider(post.id));
                    context.push('/post/${post.id}');
                  },
                  onChannelTap: () => NavigationUtils.openChannel(context, post.channelId),
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
