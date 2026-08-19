import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/channels/data/channel_repository.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
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
    if (_scrollController.hasClients) {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.85) {
        loadMoreChannelPosts(ref, widget.channelId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelAsync = ref.watch(channelDetailProvider(widget.channelId));
    final channelPostsAsync = ref.watch(channelPostsProvider(widget.channelId));
    final channel = channelAsync.value;

    // Watch the provider state to rebuild on changes
    ref.watch(mutedChannelsProvider);
    final isMuted = ref
        .read(mutedChannelsProvider.notifier)
        .isMuted(
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
            tooltip: isMuted ? 'Show posts in feed' : 'Hide posts from feed',
            onPressed: () {
              ref
                  .read(mutedChannelsProvider.notifier)
                  .toggleMute(
                    widget.channelId,
                    chatId: channel?.chatId,
                    username: channel?.username,
                  );
              final newlyMuted = !isMuted;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    newlyMuted
                        ? 'Hidden from feed. Posts from this channel are now hidden from your feed.'
                        : 'Visible in feed. Posts from this channel will appear in your feed.',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: Icon(
              isMuted
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: isMuted ? AppColors.error : primaryColor,
            ),
          ),
        ],
      ),
      body: channelAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (channel) {
          if (channel == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'This channel is private or inaccessible.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async {
              ref.invalidate(channelPostsProvider(widget.channelId));
              ref.invalidate(channelDetailProvider(widget.channelId));
            },
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
                    child: Center(child: Text('Error loading posts: $err')),
                  ),
                  data: (posts) {
                    if (posts.isEmpty) {
                      return const SliverFillRemaining(
                        child: Center(
                          child: Text('No posts found in this channel.'),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final post = posts[index];
                        final isHighlighted =
                            widget.highlightMessageId != null &&
                            post.messageId == widget.highlightMessageId;
                        return PostCard(
                          post: post,
                          isHighlighted: isHighlighted,
                          onTap: () {
                            ref.read(markPostAsReadProvider(post.id));
                            context.push('/post/${post.id}');
                          },
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
