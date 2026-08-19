import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/core/widgets/loading_skeleton.dart';
import 'package:gramx/features/feed/domain/feed_thread.dart';
import 'package:gramx/features/feed/presentation/feed_focus_controller.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/pending_posts_provider.dart';
import 'package:gramx/features/feed/presentation/widgets/thread_card.dart';

class FolderFeed extends ConsumerStatefulWidget {
  final String folderTitle;
  final String folderId;

  /// Room reserved for the sliding header, which overlays this list.
  final double topPadding;

  const FolderFeed({
    super.key,
    required this.folderTitle,
    required this.folderId,
    this.topPadding = 0,
  });

  @override
  ConsumerState<FolderFeed> createState() => _FolderFeedState();
}

class _FolderFeedState extends ConsumerState<FolderFeed> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  /// True once this tab has shown posts, so an empty list afterwards means
  /// "caught up" rather than "nothing here".
  bool _hasLoadedOnce = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    // Leaving the feed with the bar hidden would strand it off screen on
    // whatever comes next.
    ref.read(chromeVisibleProvider.notifier).show();
    super.deactivate();
  }

  /// Commits pending arrivals, then returns to the top so the user lands on
  /// the newest post rather than wherever the insert pushed them.
  void _showNewPosts() {
    ref.read(pendingPostsProvider.notifier).accept();
    _scrollToTop();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    // Bring the chrome back too — arriving at the top with the header still
    // hidden looks like the app lost its navigation.
    ref.read(chromeVisibleProvider.notifier).show();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  /// Chat ids this tab shows, or null for the "All" tab.
  ///
  /// Pagination is scoped to these so a narrow folder doesn't page every
  /// channel the user follows just to add a couple of rows.
  Set<int>? _visibleChatIds() {
    final folderId = int.tryParse(widget.folderId);
    if (widget.folderId == 'All' || folderId == null) return null;

    final allowed = ref.read(folderChannelIdsProvider(folderId)).value;
    if (allowed == null) return null;
    return allowed.map(int.tryParse).whereType<int>().toSet();
  }

  void _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      await ref
          .read(feedPostsProvider.notifier)
          .loadMore(allowedChatIds: _visibleChatIds());
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

    // Another widget — the tab bar, usually — asking this feed to go to the top.
    ref.listen<ScrollToTopRequest?>(feedScrollToTopProvider, (_, request) {
      if (request?.folderId == widget.folderId) _scrollToTop();
    });

    final feedAsync = ref.watch(filteredFeedPostsProvider(widget.folderId));
    final pendingCount =
        ref.watch(pendingPostsForFolderProvider(widget.folderId)).length;
    final isSyncing = ref.watch(feedPostsProvider).isLoading;
    final theme = Theme.of(context);

    return feedAsync.when(
      loading: () => Padding(
        padding: EdgeInsets.only(top: widget.topPadding),
        child: const FeedSkeleton(),
      ),
      error: (err, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppStrings.feedErrorTitle,
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
        if (posts.isNotEmpty) _hasLoadedOnce = true;
        // Collapse a channel's own follow-ups so one burst takes one slot.
        final threads = groupIntoThreads(posts);
        if (posts.isEmpty) {
          if (isSyncing) {
            return const FeedSkeleton();
          }
          // An empty feed after a refresh means the reader finished
          // everything, which is a different message from "this folder has
          // nothing in it".
          final caughtUp = _hasLoadedOnce;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    caughtUp
                        ? Icons.check_circle_outline
                        : Icons.article_outlined,
                    color: theme.iconTheme.color,
                    size: 48,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    caughtUp
                        ? AppStrings.feedCaughtUpTitle
                        : AppStrings.feedEmptyTitle(widget.folderTitle),
                    style: AppTypography.subheading(
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (caughtUp) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      AppStrings.feedCaughtUpBody,
                      style: AppTypography.body(color: theme.iconTheme.color),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return Stack(
          children: [
            RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async {
            // A refresh re-fetches everything, so held-back arrivals would be
            // duplicated by it — drop them rather than showing a stale pill.
            ref.read(pendingPostsProvider.notifier).discard();
            await ref.read(feedPostsProvider.notifier).refresh();
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Scrolling down hides the tab bar, scrolling up brings it back —
              // the reading surface gets the whole screen while in motion.
              if (notification is UserScrollNotification) {
                final nav = ref.read(chromeVisibleProvider.notifier);
                if (notification.direction == ScrollDirection.reverse) {
                  nav.hide();
                } else if (notification.direction == ScrollDirection.forward) {
                  nav.show();
                }
              }
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 300) {
                _loadMore();
              }
              return false;
            },
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(top: widget.topPadding),
              itemCount: threads.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == threads.length) {
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

                final thread = threads[index];
                return ThreadCard(
                  key: ValueKey(thread.root.id),
                  thread: thread,
                  onOpenPost: (post) {
                    ref.read(markPostAsReadProvider(post.id));
                    context.push('/post/${post.id}');
                  },
                  onOpenChannel: (post) =>
                      NavigationUtils.openChannel(context, post.channelId),
                );
              },
            ),
          ),
            ),
            if (pendingCount > 0)
              Positioned(
                top: widget.topPadding + AppSpacing.md,
                left: 0,
                right: 0,
                child: Center(
                  child: _NewPostsPill(
                    count: pendingCount,
                    onTap: _showNewPosts,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The "N new posts" affordance. Tapping it is the only way arrivals enter the
/// feed — see [PendingPostsNotifier].
class _NewPostsPill extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NewPostsPill({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = AppStrings.newPostsPill(count);

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_upward_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
