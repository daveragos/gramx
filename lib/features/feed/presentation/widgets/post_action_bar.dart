import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gramx/core/l10n/app_strings.dart';
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
      
      final activeEmoji = post.chosenReactions.isNotEmpty
          ? post.chosenReactions.first
          : (post.reactions.keys.isNotEmpty ? post.reactions.keys.first : null);

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
    final activeEmoji = post.chosenReactions.isNotEmpty
        ? post.chosenReactions.first
        : (post.reactions.keys.isNotEmpty ? post.reactions.keys.first : null);
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
          semanticLabel: AppStrings.a11yReplyWithCount(post.replyCount),
          onTap: onReplyTap,
        ),

        // Forward count. A statistic, not a control: this app cannot forward a
        // post to a Telegram chat yet, and wiring the repeat icon to "copy a
        // link" made it lie about what it does. Sharing lives on the share
        // icon. See ROADMAP T5-1.
        PostStat(
          icon: Icons.repeat,
          count: post.forwardCount,
          color: secondaryColor,
          semanticLabel: 'forwards',
        ),

        // Reaction Button (Instant toggle on tap, overlay picker on long-press)
        KeyedSubtree(
          key: reactionKey,
          child: Semantics(
            button: true,
            label: post.chosenReactions.isNotEmpty
                ? AppStrings.a11yCurrentReaction(post.chosenReactions.first)
                : AppStrings.a11yReact,
            excludeSemantics: true,
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
        ),

        // View count — also a statistic. It was rendered as a button with no
        // onTap, so it looked pressable and wasn't.
        PostStat(
          icon: Icons.bar_chart,
          count: post.viewCount,
          color: secondaryColor,
          semanticLabel: 'views',
        ),

        // Bookmark & Share Row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: post.isBookmarked
                  ? AppStrings.a11yBookmarkRemove
                  : AppStrings.a11yBookmarkAdd,
              child: GestureDetector(
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
            ),
            const SizedBox(width: AppSpacing.lg),
            Semantics(
              button: true,
              label: AppStrings.a11yCopyLink,
              child: GestureDetector(
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
            ),
          ],
        ),
      ],
    );
  }
}

/// A read-only figure in the action bar.
///
/// Deliberately not a [PostActionButton]: an icon that responds to touch but
/// changes nothing is worse than one that plainly doesn't.
class PostStat extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final String semanticLabel;

  const PostStat({
    super.key,
    required this.icon,
    required this.count,
    required this.color,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count $semanticLabel',
      excludeSemantics: true,
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

class PostActionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final Color activeColor;
  final VoidCallback? onTap;

  /// Spoken description. Icon-only controls are unreachable without one.
  final String? semanticLabel;

  const PostActionButton({
    super.key,
    required this.icon,
    required this.count,
    required this.color,
    required this.activeColor,
    this.semanticLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final button = _buildButton(context);
    if (semanticLabel == null) return button;
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: button,
    );
  }

  Widget _buildButton(BuildContext context) {
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
