import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/channels/data/channel_repository.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/channels/presentation/widgets/mute_sheet.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/presentation/feed_focus_controller.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';

class ChannelProfileScreen extends ConsumerStatefulWidget {
  final String channelId;
  final int? highlightMessageId;

  const ChannelProfileScreen({
    super.key,
    required this.channelId,
    this.highlightMessageId,
  });

  @override
  ConsumerState<ChannelProfileScreen> createState() =>
      _ChannelProfileScreenState();
}

class _ChannelProfileScreenState extends ConsumerState<ChannelProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  late final FeedRepository _feedRepository;
  bool _isActionLoading = false;
  int? _openedChatId;

  /// Bounds the auto-fill above, so a channel that keeps answering with a
  /// short page can't turn into a request loop.
  static const int _maxAutoFills = 3;
  int _autoFills = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _feedRepository = ref.read(feedRepositoryProvider);

    // Opening a chat is a TDLib request, so it must not happen as a side effect
    // of rendering. listenManual belongs in initState and fireImmediately
    // covers the case where the channel is already cached.
    ref.listenManual<AsyncValue<Channel?>>(
      channelDetailProvider(widget.channelId),
      (_, next) => _syncOpenChat(next.value?.chatId),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    // Notify TDLib that the user closed this chat
    if (_openedChatId != null) {
      _feedRepository.closeChat(_openedChatId!);
    }

    super.dispose();
  }

  /// Keeps this screen's open chat in step with the channel it is showing.
  void _syncOpenChat(int? chatId) {
    if (chatId == null || chatId == _openedChatId) return;
    final previous = _openedChatId;
    if (previous != null) _feedRepository.closeChat(previous);
    _openedChatId = chatId;
    _feedRepository.openChat(chatId);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent * 0.85) {
      ref.read(olderChannelPostsProvider.notifier).loadMore(widget.channelId);
    }
  }

  /// Loads another page when the first one doesn't fill the screen.
  ///
  /// Pagination hangs off the scroll listener, and a list too short to scroll
  /// never fires it — so a channel that opened with two posts had no way to
  /// show a third. Bounded, and it stops as soon as the channel says it has
  /// nothing older.
  void _fillViewport() {
    if (_autoFills >= _maxAutoFills) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent > 0) return;

    final older = ref.read(olderChannelPostsProvider.notifier);
    if (older.isLoading(widget.channelId) ||
        older.isExhausted(widget.channelId)) {
      return;
    }

    _autoFills++;
    older.loadMore(widget.channelId).then((added) {
      if (added && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fillViewport());
      }
    });
  }

  Future<void> _refresh() => refreshChannel(ref, widget.channelId);

  @override
  Widget build(BuildContext context) {
    final channelAsync = ref.watch(channelDetailProvider(widget.channelId));
    final channelPostsAsync = ref.watch(channelPostsProvider(widget.channelId));

    // After the frame, never during it: this can spend a TDLib request.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fillViewport();
    });
    final channel = channelAsync.value;

    // Watch the provider state to rebuild on changes
    // Keeps the focus controller alive while this screen is open; it owns the
    // dwell timers behind read tracking.
    ref.listen(feedFocusControllerProvider, (_, _) {});

    ref.watch(mutedChannelsProvider);
    final mutes = ref.read(mutedChannelsProvider.notifier);
    final isMuted = mutes.isMuted(
      widget.channelId,
      chatId: channel?.chatId,
      username: channel?.username,
    );
    final mutedUntil = mutes.mutedUntil(
      widget.channelId,
      chatId: channel?.chatId,
      username: channel?.username,
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final primaryColor = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          channel?.title ?? 'Channel',
          style: AppTypography.heading(color: primaryColor),
        ),
        actions: [
          IconButton(
            tooltip: isMuted
                ? (mutedUntil != null
                    ? AppStrings.channelsMutedUntil(
                        TimeUtils.untilWhen(mutedUntil))
                    : AppStrings.channelsUnmuteAction)
                : AppStrings.channelsMuteAction,
            // Asks for how long, rather than muting forever by default —
            // see MuteSheet.
            onPressed: () => MuteSheet.show(
              context,
              ref,
              channelId: widget.channelId,
              chatId: channel?.chatId,
              username: channel?.username,
            ),
            icon: Icon(
              isMuted
                  ? Icons.notifications_off_rounded
                  : Icons.notifications_none_rounded,
              color: isMuted ? AppColors.error : primaryColor,
            ),
          ),
        ],
      ),
      body: channelAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => _Retry(
          message: AppStrings.channelLoadFailed,
          detail: err.toString(),
          onRetry: _refresh,
        ),
        data: (channel) {
          if (channel == null) {
            return _Retry(
              message: AppStrings.channelUnavailable,
              onRetry: _refresh,
            );
          }

          return RefreshIndicator(
            color: AppColors.accent,
            // channelPostsProvider is derived; invalidating it recomputed the
            // same cached fetch and the pull did nothing at all. The refresh
            // has to reach the future that does the work.
            onRefresh: _refresh,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Profile Details Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.postPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ChannelAvatar(
                              title: channel.title,
                              avatarPath: channel.avatarUrl,
                              avatarFileId: channel.avatarFileId,
                              avatarColorHex: channel.avatarColor,
                              radius: 36,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          channel.title,
                                          style: AppTypography.heading(
                                            color: primaryColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (channel.isVerified) ...[
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.verified,
                                          color: AppColors.verified,
                                          size: 20,
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (channel.username != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '@${channel.username}',
                                      style: AppTypography.username(
                                        color: secondaryColor,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.people_outline,
                                        size: 14,
                                        color: secondaryColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${TimeUtils.formatCount(channel.subscriberCount)} subscribers',
                                        style: AppTypography.body(
                                          color: secondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: channel.isJoined
                                    ? Colors.transparent
                                    : AppColors.accent,
                                foregroundColor: channel.isJoined
                                    ? primaryColor
                                    : Colors.white,
                                elevation: channel.isJoined ? 0 : 2,
                                side: channel.isJoined
                                    ? BorderSide(
                                        color: secondaryColor.withValues(
                                          alpha: 0.5,
                                        ),
                                      )
                                    : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              onPressed: _isActionLoading
                                  ? null
                                  : () async {
                                      setState(() => _isActionLoading = true);
                                      final channelRepo = ref.read(
                                        channelRepositoryProvider,
                                      );
                                      if (channel.isJoined) {
                                        final success = await channelRepo
                                            .leaveChannel(channel.chatId);
                                        if (context.mounted && success) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Left ${channel.title}',
                                              ),
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        final success = await channelRepo
                                            .joinChannel(channel.chatId);
                                        if (context.mounted && success) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Joined ${channel.title}',
                                              ),
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                      ref.invalidate(
                                        channelDetailProvider(widget.channelId),
                                      );
                                      ref.invalidate(channelsProvider);
                                      ref.invalidate(feedPostsProvider);
                                      if (mounted) {
                                        setState(
                                          () => _isActionLoading = false,
                                        );
                                      }
                                    },
                              child: _isActionLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      channel.isJoined ? 'Joined' : 'Join',
                                      style: AppTypography.button(),
                                    ),
                            ),
                          ],
                        ),

                        // Description
                        if (channel.description != null &&
                            channel.description!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            channel.description!,
                            style: AppTypography.body(color: primaryColor),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: Divider(height: 1)),

                // Channel Posts List
                channelPostsAsync.when(
                  loading: () => const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  ),
                  error: (err, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Retry(
                      message: AppStrings.channelPostsFailed,
                      detail: err.toString(),
                      onRetry: _refresh,
                    ),
                  ),
                  data: (posts) {
                    if (posts.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _Retry(
                          message: AppStrings.channelNoPosts,
                          onRetry: _refresh,
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final post = posts[index];
                        final isHighlighted =
                            widget.highlightMessageId != null &&
                            post.messageId == widget.highlightMessageId;
                        // Same dwell-based read tracking as the main feed —
                        // reading a post here counts just as much.
                        return PostVisibilityReporter(
                          postId: post.id,
                          child: PostCard(
                            post: post,
                            isHighlighted: isHighlighted,
                            onTap: () {
                              ref.read(markPostAsReadProvider(post.id));
                              context.push('/post/${post.id}');
                            },
                          ),
                        );
                      }, childCount: posts.length),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A dead end with a way out of it.
///
/// Every failure on this screen used to end in a line of text: no retry, and
/// no scrollable to pull down on either, so a channel that failed to load was
/// simply stuck until the reader backed out.
class _Retry extends StatelessWidget {
  final String message;
  final String? detail;
  final Future<void> Function() onRetry;

  const _Retry({required this.message, this.detail, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: secondary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              style: AppTypography.subheading(color: theme.colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
            if (detail != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                detail!,
                style: AppTypography.actionCount(color: secondary),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}
