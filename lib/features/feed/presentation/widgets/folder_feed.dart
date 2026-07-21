import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/widgets/loading_skeleton.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';

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
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() async {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoadingMore) {
        setState(() => _isLoadingMore = true);
        try {
          final channels = ref.read(channelsProvider).value ?? [];
          for (final channel in channels) {
            final channelDbId = int.tryParse(channel.id);
            if (channelDbId != null) {
              await ref.read(
                loadMoreChannelHistoryProvider((
                  channelDbId: channelDbId,
                  chatId: channel.chatId,
                )).future,
              );
            }
          }
        } catch (_) {
        } finally {
          if (mounted) setState(() => _isLoadingMore = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(filteredFeedPostsProvider(widget.folderId));
    final isSyncing = ref.watch(isSyncingProvider).value;
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
            final syncService = ref.read(syncServiceProvider);
            await syncService.syncSubscribedChannels();
            await syncService.syncFeedHistory();
            ref.invalidate(feedPostsProvider);
          },
          child: ListView.builder(
            controller: _scrollController,
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
              return PostCard(
                post: post,
                onTap: () {
                  final id = int.tryParse(post.id);
                  if (id != null) {
                    ref.read(markPostAsReadProvider(id));
                  }
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
    );
  }
}
