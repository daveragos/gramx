import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/core/widgets/loading_skeleton.dart';
import 'package:gramx/features/feed/presentation/feed_focus_controller.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';

class FolderFeed extends ConsumerStatefulWidget {
  final String folderTitle;
  final String folderId;

  const FolderFeed({
    super.key,
    required this.folderTitle,
    required this.folderId,
  });

  @override
  ConsumerState<FolderFeed> createState() => _FolderFeedState();
}

class _FolderFeedState extends ConsumerState<FolderFeed> {
  bool _isLoadingMore = false;

  void _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      await ref.read(feedPostsProvider.notifier).loadMore();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the focus controller alive while the feed is on screen. It owns the
    // dwell timers behind read tracking and chat focus; listening (rather than
    // watching) avoids rebuilding the whole list every time focus moves.
    ref.listen(feedFocusControllerProvider, (_, _) {});

    final feedAsync = ref.watch(filteredFeedPostsProvider(widget.folderId));
    final isSyncing = ref.watch(feedPostsProvider).isLoading;
    final theme = Theme.of(context);

    return feedAsync.when(
      loading: () => const FeedSkeleton(),
      error: (err, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Something went wrong',
              style: AppTypography.subheading(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              err.toString(),
              style: AppTypography.body(color: theme.iconTheme.color),
            ),
          ],
        ),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          if (isSyncing) {
            return const FeedSkeleton();
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.article_outlined,
                  color: theme.iconTheme.color,
                  size: 48,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No posts in ${widget.folderTitle}',
                  style: AppTypography.subheading(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async {
            // Use stateful refresh instead of invalidate
            await ref.read(feedPostsProvider.notifier).refresh();
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 300) {
                _loadMore();
              }
              return false;
            },
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: posts.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == posts.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: 2.5,
                      ),
                    ),
                  );
                }

                final post = posts[index];
                return PostVisibilityReporter(
                  postId: post.id,
                  child: PostCard(
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
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
