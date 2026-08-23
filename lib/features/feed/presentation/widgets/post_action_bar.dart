import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/forward_sheet.dart';
import 'package:gramx/features/feed/presentation/widgets/reaction_control.dart';

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

  Future<void> _forward(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final sent = await ForwardSheet.show(context, post);
    if (!sent) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(AppStrings.forwardSent(post.channelTitle)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

        // Forward. Now genuinely forwards the message rather than copying a
        // link, which is what the count beside it has always meant.
        PostActionButton(
          icon: Icons.repeat,
          count: post.forwardCount,
          color: secondaryColor,
          activeColor: AppColors.repost,
          semanticLabel: AppStrings.a11yForward,
          onTap: () => _forward(context),
        ),

        // Reaction. Tap toggles your own choice, long press picks a new one
        // — the same control comments use, so the two can't drift apart.
        ReactionControl(
          post: post,
          color: secondaryColor,
          onSelectReaction: onSelectReaction,
        ),

        // View count — also a statistic. It was rendered as a button with no
        // onTap, so it looked pressable and wasn't.
        PostStat(
          icon: Icons.bar_chart,
          count: post.viewCount,
          color: secondaryColor,
          semanticLabel: AppStrings.a11yViews,
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
