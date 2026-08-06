import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/presentation/widgets/reaction_picker_overlay.dart';

class PostActionBar extends ConsumerWidget {
  final Post post;
  final Color secondaryColor;
  final VoidCallback onBookmarkTap;
  final ValueChanged<String> onSelectReaction;
  final VoidCallback onReplyTap;
  final VoidCallback onShareTap;

  const PostActionBar({
    super.key,
    required this.post,
    required this.secondaryColor,
    required this.onBookmarkTap,
    required this.onSelectReaction,
    required this.onReplyTap,
    required this.onShareTap,
  });

  void _showReactionPicker(BuildContext context, WidgetRef ref, GlobalKey key) async {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final offset = renderBox.localToGlobal(Offset.zero);
      final rect = offset & renderBox.size;
      
      final activeEmoji = post.reactions.entries.isEmpty ? null : post.reactions.keys.first;

      // Fetch dynamic available reactions
      final availableEmojis = await ref.read(feedRepositoryProvider).getAvailableReactions(post.chatId);
      
      if (context.mounted) {
        ReactionPickerOverlay.show(
          context: context,
          targetRect: rect,
          availableEmojis: availableEmojis,
          selectedEmoji: activeEmoji,
          onEmojiSelected: onSelectReaction,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalReactions = post.reactions.values.fold<int>(0, (a, b) => a + b);
    final activeEmoji = post.reactions.keys.isNotEmpty ? post.reactions.keys.first : null;
    final reactionKey = GlobalKey();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Reply Button
        PostActionButton(
          icon: Icons.chat_bubble_outline,
          count: post.replyCount,
          color: secondaryColor,
          activeColor: AppColors.reply,
          onTap: onReplyTap,
        ),

        // Repost Button
        PostActionButton(
          icon: Icons.repeat,
          count: post.forwardCount,
          color: secondaryColor,
          activeColor: AppColors.repost,
          onTap: onShareTap,
        ),

        // Reaction Button (Instant toggle on tap, overlay picker on long-press)
        KeyedSubtree(
          key: reactionKey,
          child: GestureDetector(
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _showReactionPicker(context, ref, reactionKey);
            },
            onTap: () {
              HapticFeedback.lightImpact();
              if (post.chosenReactions.isNotEmpty) {
                onSelectReaction(post.chosenReactions.first);
              } else {
                _showReactionPicker(context, ref, reactionKey);
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (activeEmoji != null)
                  Text(activeEmoji, style: const TextStyle(fontSize: 16))
                else
                  Icon(
                    post.chosenReactions.isNotEmpty || totalReactions > 0
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: post.chosenReactions.isNotEmpty || totalReactions > 0
                        ? AppColors.like
                        : secondaryColor,
                    size: 18,
                  ),
                if (totalReactions > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    TimeUtils.formatCount(totalReactions),
                    style: AppTypography.actionCount(
                      color: post.chosenReactions.isNotEmpty ? AppColors.like : secondaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // View Count (Stats)
        PostActionButton(
          icon: Icons.bar_chart,
          count: post.viewCount,
          color: secondaryColor,
          activeColor: secondaryColor,
        ),

        // Bookmark & Share Row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onBookmarkTap();
              },
              child: Icon(
                post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: post.isBookmarked ? AppColors.accent : secondaryColor,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onShareTap();
              },
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
      onTap: () {
        if (onTap != null) {
          HapticFeedback.lightImpact();
          onTap!();
        }
      },
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
