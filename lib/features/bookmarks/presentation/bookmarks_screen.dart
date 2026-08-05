import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';

/// Provider to filter bookmarked posts from the home feed posts stream.
final bookmarkedPostsProvider = Provider<AsyncValue<List<Post>>>((ref) {
  final postsAsync = ref.watch(feedPostsProvider);
  return postsAsync.whenData(
    (posts) => posts.where((post) => post.isBookmarked).toList(),
  );
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
          'Bookmarks',
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
                      'Save posts for later',
                      style: AppTypography.heading(color: primaryColor).copyWith(fontSize: 22),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      "Don't let the good ones fly away! Bookmark posts to easily find them again in the future.",
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
              ref.invalidate(feedPostsProvider);
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
                  onChannelTap: () => context.push('/channel/${post.channelId}'),
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
