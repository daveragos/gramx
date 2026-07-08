import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/post_media_grid.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onChannelTap;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onLikeTap;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onChannelTap,
    this.onBookmarkTap,
    this.onLikeTap,
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final secondaryColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final primaryTextColor = colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.postPadding,
              vertical: AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                GestureDetector(
                  onTap: onChannelTap,
                  child: _buildAvatar(post),
                ),
                const SizedBox(width: AppSpacing.avatarGap),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          Flexible(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    post.channelTitle,
                                    style: AppTypography.displayName(color: primaryTextColor),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                if (post.isChannelVerified) ...[
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.verified,
                                    color: AppColors.verified,
                                    size: 18,
                                  ),
                                ],
                                const SizedBox(width: 4),
                                if (post.channelUsername != null)
                                  Flexible(
                                    child: Text(
                                      '@${post.channelUsername}',
                                      style: AppTypography.username(color: secondaryColor),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                Text(
                                  ' · ',
                                  style: AppTypography.username(color: secondaryColor),
                                ),
                                Text(
                                  TimeUtils.relativeTime(post.publishedAt),
                                  style: AppTypography.timestamp(color: secondaryColor),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.more_horiz,
                            color: secondaryColor,
                            size: 18,
                          ),
                        ],
                      ),
                      // Body text
                      if (post.text != null && post.text!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          post.text!,
                          style: AppTypography.body(color: primaryTextColor),
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
                        onBookmarkTap: onBookmarkTap,
                        onLikeTap: onLikeTap,
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
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onLikeTap;

  const _ActionBar({
    required this.post,
    required this.secondaryColor,
    this.onBookmarkTap,
    this.onLikeTap,
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
        ),
        // Repost/Forward
        _ActionButton(
          icon: Icons.repeat,
          count: post.forwardCount,
          color: secondaryColor,
          activeColor: AppColors.repost,
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
            Icon(
              Icons.ios_share,
              color: secondaryColor,
              size: 18,
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
