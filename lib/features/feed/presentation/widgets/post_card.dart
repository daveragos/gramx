import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/link_preview_card.dart';
import 'package:gramx/features/feed/presentation/widgets/poll_card.dart';
import 'package:gramx/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:gramx/features/feed/presentation/widgets/post_media_grid.dart';
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
                  ChannelAvatar(
                    title: post.channelTitle,
                    avatarPath: post.channelAvatarUrl,
                    avatarColorHex: post.channelAvatarColor,
                    onTap: onChannelTap ?? () => context.push('/channel/${post.channelId}'),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        if (post.text != null && post.text!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          TextEntityRenderer(
                            text: post.text!,
                            entities: post.entities,
                            style: AppTypography.body(color: primaryTextColor),
                          ),
                        ],
                        if (post.linkPreviewUrl != null && post.linkPreviewUrl!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          LinkPreviewCard(
                            url: post.linkPreviewUrl!,
                            title: post.linkPreviewTitle,
                            description: post.linkPreviewDescription,
                            imageUrl: post.linkPreviewImageUrl,
                          ),
                        ],
                        if (post.poll != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          PollCard(
                            poll: post.poll!,
                            channelId: post.channelId,
                            messageId: post.messageId,
                          ),
                        ],
                        if (post.media.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          PostMediaGrid(media: post.media),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        PostActionBar(
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
}
