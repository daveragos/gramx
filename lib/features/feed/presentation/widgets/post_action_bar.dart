import 'package:flutter/material.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/feed/domain/post.dart';

class PostActionBar extends StatelessWidget {
  final Post post;
  final Color secondaryColor;
  final VoidCallback onBookmarkTap;
  final VoidCallback onLikeTap;
  final VoidCallback onReplyTap;
  final VoidCallback onShareTap;

  const PostActionBar({
    super.key,
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
        PostActionButton(
          icon: Icons.chat_bubble_outline,
          count: post.replyCount,
          color: secondaryColor,
          activeColor: AppColors.reply,
          onTap: onReplyTap,
        ),
        PostActionButton(
          icon: Icons.repeat,
          count: post.forwardCount,
          color: secondaryColor,
          activeColor: AppColors.repost,
          onTap: onShareTap,
        ),
        PostActionButton(
          icon: totalReactions > 0 ? Icons.favorite : Icons.favorite_border,
          count: totalReactions,
          color: totalReactions > 0 ? AppColors.like : secondaryColor,
          activeColor: AppColors.like,
          onTap: onLikeTap,
        ),
        PostActionButton(
          icon: Icons.bar_chart,
          count: post.viewCount,
          color: secondaryColor,
          activeColor: secondaryColor,
        ),
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

class PostActionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final Color activeColor;
  final VoidCallback? onTap;

  const PostActionButton({
    super.key,
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
