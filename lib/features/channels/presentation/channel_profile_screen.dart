import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Notify TDLib that the user opened this chat (for unread tracking)
    final chatId = int.tryParse(widget.channelId);
    if (chatId != null) {
      ref.read(feedRepositoryProvider).openChat(chatId);
    }
  }

  @override
  void deactivate() {
    // Notify TDLib that the user closed this chat
    final chatId = int.tryParse(widget.channelId);
    if (chatId != null) {
      ref.read(feedRepositoryProvider).closeChat(chatId);
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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
    final mutedChannels = ref.watch(mutedChannelsProvider);
    final isMuted = mutedChannels.contains(widget.channelId);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final primaryColor = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          channelAsync.value?.title ?? 'Channel',
          style: AppTypography.heading(color: primaryColor),
        ),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(mutedChannelsProvider.notifier).toggleMute(widget.channelId);
              final newlyMuted = !isMuted;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(newlyMuted
                      ? 'Muted channel. Its posts will be hidden from your feed.'
                      : 'Unmuted channel.'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: Icon(
              isMuted
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_outlined,
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
                                          style: AppTypography.heading(color: primaryColor),
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
                                      style: AppTypography.username(color: secondaryColor),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.people_outline,
                                          size: 14, color: secondaryColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${TimeUtils.formatCount(channel.subscriberCount)} subscribers',
                                        style: AppTypography.body(color: secondaryColor),
                                      ),
                                    ],
                                  ),
                                ],
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
                        final isHighlighted = widget.highlightMessageId != null &&
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
