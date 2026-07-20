import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/post_media_grid.dart';
import 'package:gramx/features/feed/presentation/widgets/poll_card.dart';
import 'package:gramx/features/feed/presentation/widgets/link_preview_card.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';

class PostCard extends ConsumerWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onChannelTap;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onShareTap;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onChannelTap,
    this.onBookmarkTap,
    this.onLikeTap,
    this.onShareTap,
  });

  Widget _buildAvatar(Post post) {
    if (post.channelAvatarUrl != null && post.channelAvatarUrl!.isNotEmpty) {
      final file = File(post.channelAvatarUrl!);
      if (file.existsSync()) {
        return CircleAvatar(
          radius: AppSpacing.avatarSize / 2,
          backgroundImage: FileImage(file),
        );
      }
    }
    return CircleAvatar(
      radius: AppSpacing.avatarSize / 2,
      backgroundColor: post.channelAvatarColor != null
          ? _parseColor(post.channelAvatarColor!)
          : AppColors.accent,
      child: Text(
        post.channelTitle.isNotEmpty ? post.channelTitle[0].toUpperCase() : '?',
        style: AppTypography.displayName(color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final defaultBookmarkHandler = onBookmarkTap ?? () {
      final dbId = int.tryParse(post.id);
      if (dbId != null) {
        ref.read(syncServiceProvider).toggleBookmark(dbId, post.isBookmarked);
      }
    };

    final defaultLikeHandler = onLikeTap ?? () {
      final channel = ref.read(channelDetailProvider(post.channelId)).value;
      if (channel != null) {
        ref.read(syncServiceProvider).togglePostReaction(
          chatId: channel.chatId,
          messageId: post.messageId,
          reactionEmoji: '👍',
          isCurrentlyLiked: post.reactions.containsKey('👍'),
        );
      }
    };

    void defaultReplyHandler() {
      context.push('/post/${post.id}');
    }

    final defaultShareHandler = onShareTap ?? () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post link copied to clipboard.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    };

    return InkWell(
      onTap: onTap ?? defaultReplyHandler,
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.postPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Channel Avatar
                  GestureDetector(
                    onTap: onChannelTap ?? () => context.push('/channel/${post.channelId}'),
                    child: _buildAvatar(post),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Content column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Post Header
                        Row(
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: onChannelTap ?? () => context.push('/channel/${post.channelId}'),
                                child: Text(
                                  post.channelTitle,
                                  style: AppTypography.displayName(color: primaryTextColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (post.isChannelVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified,
                                color: AppColors.verified,
                                size: 16,
                              ),
                            ],
                            const SizedBox(width: 4),
                            if (post.channelUsername != null) ...[
                              Flexible(
                                child: Text(
                                  '@${post.channelUsername}',
                                  style: AppTypography.username(color: secondaryColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              '·',
                              style: AppTypography.username(color: secondaryColor),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              TimeUtils.relativeTime(post.publishedAt),
                              style: AppTypography.timestamp(color: secondaryColor),
                            ),
                          ],
                        ),
                        // Forwarded banner
                        if (post.forwardedFromTitle != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.repeat, size: 12, color: secondaryColor),
                              const SizedBox(width: 4),
                              Text(
                                'Forwarded from ${post.forwardedFromTitle}',
                                style: AppTypography.actionCount(color: secondaryColor),
                              ),
                            ],
                          ),
                        ],
                        // Post Text Body
                        if (post.text != null && post.text!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          TextEntityRenderer(
                            text: post.text!,
                            entities: post.entities,
                            style: AppTypography.body(color: primaryTextColor),
                          ),
                        ],
                        // Link Preview Card
                        if (post.linkPreviewUrl != null && post.linkPreviewUrl!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          LinkPreviewCard(
                            url: post.linkPreviewUrl!,
                            title: post.linkPreviewTitle,
                            description: post.linkPreviewDescription,
                            imageUrl: post.linkPreviewImageUrl,
                          ),
                        ],
                        // Poll display
                        if (post.poll != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          PollCard(
                            poll: post.poll!,
                            channelId: post.channelId,
                            messageId: post.messageId,
                          ),
                        ],
                        // Media
                        if (post.media.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          PostMediaGrid(media: post.media),
                        ],
                        // Action bar
                        const SizedBox(height: AppSpacing.md),
                        _ActionBar(
                          post: post,
                          secondaryColor: secondaryColor,
                          onBookmarkTap: defaultBookmarkHandler,
                          onLikeTap: defaultLikeHandler,
                          onReplyTap: defaultReplyHandler,
                          onShareTap: defaultShareHandler,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: theme.dividerTheme.color, height: 0.5, thickness: 0.5),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}

class _ActionBar extends StatelessWidget {
  final Post post;
  final Color secondaryColor;
  final VoidCallback onBookmarkTap;
  final VoidCallback onLikeTap;
  final VoidCallback onReplyTap;
  final VoidCallback onShareTap;

  const _ActionBar({
    required this.post,
    required this.secondaryColor,
    required this.onBookmarkTap,
    required this.onLikeTap,
    required this.onReplyTap,
    required this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalReactions = post.reactions.values.fold<int>(0, (a, b) => a + b);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Reply
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          count: post.replyCount,
          color: secondaryColor,
          activeColor: AppColors.reply,
          onTap: onReplyTap,
        ),
        // Repost/Forward
        _ActionButton(
          icon: Icons.repeat,
          count: post.forwardCount,
          color: secondaryColor,
          activeColor: AppColors.repost,
          onTap: onShareTap,
        ),
        // Like
        _ActionButton(
          icon: totalReactions > 0 ? Icons.favorite : Icons.favorite_border,
          count: totalReactions,
          color: totalReactions > 0 ? AppColors.like : secondaryColor,
          activeColor: AppColors.like,
          onTap: onLikeTap,
        ),
        // Views
        _ActionButton(
          icon: Icons.bar_chart,
          count: post.viewCount,
          color: secondaryColor,
          activeColor: secondaryColor,
        ),
        // Bookmark + Share row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onBookmarkTap,
              child: Icon(
                post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: post.isBookmarked ? AppColors.accent : secondaryColor,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            GestureDetector(
              onTap: onShareTap,
              child: Icon(
                Icons.ios_share,
                color: secondaryColor,
                size: 18,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final Color activeColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.count,
    required this.color,
    required this.activeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(
              TimeUtils.formatCount(count),
              style: AppTypography.actionCount(color: color),
            ),
          ],
        ],
      ),
    );
  }
}
