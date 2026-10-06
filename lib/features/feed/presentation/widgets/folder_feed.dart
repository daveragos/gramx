import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/widgets/loading_skeleton.dart';
import 'package:gramx/features/feed/domain/feed_thread.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_focus_controller.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/pending_posts_provider.dart';
import 'package:gramx/features/feed/presentation/widgets/thread_card.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';

class FolderFeed extends ConsumerStatefulWidget {
  final String folderTitle;
  final String folderId;

  /// Room reserved for the sliding header, which overlays this list.
  final double topPadding;

  /// Room reserved for the bottom bar, which also overlays this list.
  final double bottomPadding;

  /// The status bar inset, where content starts once the header slides away.
  final double collapsedTopPadding;

  const FolderFeed({
    super.key,
    required this.folderTitle,
    required this.folderId,
    this.topPadding = 0,
    this.bottomPadding = 0,
    this.collapsedTopPadding = 0,
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
    // Restore the chrome for the next screen, without animating over it.
    // After the frame, since deactivate can run mid-layout, when providers
    // must not change.
    final chrome = ref.read(chromeOffsetProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => chrome.show(animate: false),
    );
    super.deactivate();
  }

  /// Commits pending arrivals and scrolls to the newest post.
  void _showNewPosts() {
    ref.read(pendingPostsProvider.notifier).accept();
    _scrollToTop();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    ref.read(chromeOffsetProvider.notifier).show();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  /// Chat ids this tab shows, or null for the "All" tab. Pagination is
  /// limited to these.
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
    // Keeps the focus controller (read tracking) alive. Listening rather than
    // watching avoids rebuilding the list whenever focus moves.
    ref.listen(feedFocusControllerProvider, (_, _) {});

    ref.listen<ScrollToTopRequest?>(feedScrollToTopProvider, (_, request) {
      if (request?.folderId == widget.folderId) _scrollToTop();
    });

    final feedAsync = ref.watch(filteredFeedPostsProvider(widget.folderId));
    final pending = ref.watch(pendingPostsForFolderProvider(widget.folderId));
    final pendingCount = pending.length;
    final backlogIds = ref.watch(backlogIdsProvider);
    final isSyncing = ref.watch(feedPostsProvider).isLoading;
    // Tell "nothing yet" apart from "nothing here".
    final isWarmingUp = ref.watch(feedWarmupProvider);
    final channelsKnown = ref.watch(channelsKnownProvider);
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
        // Groups a channel's bursts and weaves in the backlog.
        final entries = buildFeedEntries(posts, backlogOrder: backlogIds);
        if (posts.isEmpty) {
          if (isSyncing || isWarmingUp || !channelsKnown) {
            return Padding(
              padding: EdgeInsets.only(top: widget.topPadding),
              child: const FeedSkeleton(),
            );
          }
          // The feed holds only unread posts, so empty means caught up.
          final caughtUp = _hasLoadedOnce || channelsKnown;
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
              // Keeps the spinner below the header.
              edgeOffset: widget.topPadding,
              onRefresh: () async {
                // The refresh includes held arrivals, so drop them.
                ref.read(pendingPostsProvider.notifier).discard();
                await ref.read(feedPostsProvider.notifier).refresh();
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.depth == 0 &&
                      notification.metrics.pixels >=
                          notification.metrics.maxScrollExtent - 300) {
                    _loadMore();
                  }
                  return false;
                },
                // The header and bottom bar move with the scroll.
                child: ChromeScrollObserver(
                  extent: widget.topPadding,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.only(
                      top: widget.topPadding,
                      bottom: widget.bottomPadding,
                    ),
                    itemCount: entries.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == entries.length) {
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

                      final entry = entries[index];
                      return ThreadCard(
                        key: ValueKey(entry.thread.root.id),
                        thread: entry.thread,
                        onOpenPost: (post) {
                          ref.read(markPostAsReadProvider(post.id));
                          context.push('/post/${post.id}');
                        },
                        onOpenChannel: (post) => NavigationUtils.openChannel(
                          context,
                          post.channelId,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (pendingCount > 0)
              // The pill moves and fades with the header.
              ChromeMotion(
                builder: (context, hidden, child) {
                  final opacity = chromeTiedOpacity(hidden);
                  if (opacity <= 0) return const SizedBox.shrink();
                  return Positioned(
                    top: widget.topPadding * (1 - hidden) + AppSpacing.md,
                    left: 0,
                    right: 0,
                    child: Opacity(opacity: opacity, child: child),
                  );
                },
                child: Center(
                  child: _NewPostsPill(
                    count: pendingCount,
                    faces: pillAvatarPosts(pending),
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

/// The "N new posts" pill with the posting channels' avatars. Tapping it is
/// the only way arrivals enter the feed (see [PendingPostsNotifier]).
class _NewPostsPill extends StatelessWidget {
  final int count;

  /// One post per channel (see [pillAvatarPosts]); an arrow when empty.
  final List<Post> faces;

  final VoidCallback onTap;

  const _NewPostsPill({
    required this.count,
    required this.faces,
    required this.onTap,
  });

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
            padding: EdgeInsets.fromLTRB(faces.isEmpty ? 16 : 5, 5, 16, 5),
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
                if (faces.isEmpty)
                  const Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 16,
                  )
                else
                  // The pill's label already covers these.
                  ExcludeSemantics(child: _AvatarStack(posts: faces)),
                const SizedBox(width: 7),
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

/// Overlapping channel avatars, first one on top, each ringed in the pill's
/// colour so overlapping dark avatars stay distinct.
class _AvatarStack extends StatelessWidget {
  static const double _diameter = 24;

  /// Horizontal offset between avatars.
  static const double _step = 16;

  static const double _ring = 1.5;

  final List<Post> posts;

  const _AvatarStack({required this.posts});

  @override
  Widget build(BuildContext context) {
    final outer = _diameter + _ring * 2;

    return SizedBox(
      height: outer,
      width: outer + _step * (posts.length - 1),
      child: Stack(
        children: [
          // Back to front, so the newest channel is on top.
          for (var i = posts.length - 1; i >= 0; i--)
            Positioned(
              left: i * _step,
              child: Container(
                padding: const EdgeInsets.all(_ring),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: ChannelAvatar(
                  title: posts[i].channelTitle,
                  avatarPath: posts[i].channelAvatarUrl,
                  avatarFileId: posts[i].channelAvatarFileId,
                  avatarColorHex: posts[i].channelAvatarColor,
                  radius: _diameter / 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
