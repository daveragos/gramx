import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
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

  /// An extra control at the end of the row, such as the media viewer's
  /// "open with".
  final Widget? trailing;

  /// Opens the post's statistics. Set only where Telegram reports they exist
  /// (see `StatsRepository.canViewPostStats`); otherwise the view count is a
  /// plain figure.
  final VoidCallback? onViewsTap;

  /// How far the actions' tap areas reach above and below the icons. The bar
  /// is this much taller than its row of icons on each side, so callers take
  /// it off the space around it.
  static const double touchSlop = 10;

  const PostActionBar({
    super.key,
    required this.post,
    required this.secondaryColor,
    required this.onBookmarkTap,
    required this.onSelectReaction,
    required this.onReplyTap,
    required this.onShareTap,
    this.trailing,
    this.onViewsTap,
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
    // A guest can't act on posts, so the counts stay and the actions prompt
    // them to sign in.
    final can = ref.watch(readerCapabilitiesProvider);

    return Row(
      children: [
        Expanded(
          child: can.canComment
              ? PostActionButton(
                  icon: Icons.chat_bubble_outline,
                  count: post.replyCount,
                  color: secondaryColor,
                  activeColor: AppColors.reply,
                  semanticLabel: AppStrings.a11yReplyWithCount(post.replyCount),
                  onTap: onReplyTap,
                )
              : PostStat(
                  icon: Icons.chat_bubble_outline,
                  count: post.replyCount,
                  color: secondaryColor,
                  semanticLabel: AppStrings.a11yReplyWithCount(post.replyCount),
                ),
        ),
        Expanded(
          child: can.canForward
              ? PostActionButton(
                  icon: Icons.repeat,
                  count: post.forwardCount,
                  color: secondaryColor,
                  activeColor: AppColors.repost,
                  semanticLabel: AppStrings.a11yForward,
                  onTap: () => _forward(context),
                )
              : PostStat(
                  icon: Icons.repeat,
                  count: post.forwardCount,
                  color: secondaryColor,
                  semanticLabel: AppStrings.a11yForward,
                ),
        ),
        // Tap toggles the user's reaction, long press picks another. Guests
        // see the counts without being able to react.
        Expanded(
          child: can.canReact
              ? ReactionControl(
                  post: post,
                  color: secondaryColor,
                  onSelectReaction: onSelectReaction,
                  hitPadding: _cellPadding,
                )
              : PostStat(
                  icon: Icons.favorite_border,
                  count: post.reactions.values.fold(0, (a, b) => a + b),
                  color: secondaryColor,
                  semanticLabel: AppStrings.a11yReactionsReadOnly,
                ),
        ),
        // View count: a button only where statistics can be opened.
        Expanded(
          child: onViewsTap != null
              ? PostActionButton(
                  icon: Icons.bar_chart,
                  count: post.viewCount,
                  color: secondaryColor,
                  activeColor: AppColors.accent,
                  semanticLabel: AppStrings.a11yPostAnalytics,
                  onTap: onViewsTap,
                )
              : PostStat(
                  icon: Icons.bar_chart,
                  count: post.viewCount,
                  color: secondaryColor,
                  semanticLabel: AppStrings.a11yViews,
                ),
        ),
        if (can.canBookmark)
          _IconAction(
            icon: post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: post.isBookmarked ? AppColors.accent : secondaryColor,
            semanticLabel: post.isBookmarked
                ? AppStrings.a11yBookmarkRemove
                : AppStrings.a11yBookmarkAdd,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              touchSlop,
              AppSpacing.sm,
              touchSlop,
            ),
            onTap: onBookmarkTap,
          ),
        _IconAction(
          icon: Icons.ios_share,
          color: secondaryColor,
          semanticLabel: AppStrings.a11yCopyLink,
          // Flush with the column's edge, like the reply icon at the start.
          padding: EdgeInsets.fromLTRB(
            AppSpacing.sm,
            touchSlop,
            trailing == null ? 0 : AppSpacing.sm,
            touchSlop,
          ),
          onTap: onShareTap,
        ),
        ?trailing,
      ],
    );
  }
}

/// Bookmark and share: an icon with no count, in a tap area larger than it.
class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String semanticLabel;
  final EdgeInsets padding;
  final VoidCallback onTap;

  const _IconAction({
    required this.icon,
    required this.color,
    required this.semanticLabel,
    required this.padding,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: padding,
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

/// An action's icon and count, at the start of a cell that is all tap area.
class _CellContent extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _CellContent({
    required this.icon,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _cellPadding,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        heightFactor: 1,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  TimeUtils.formatCount(count),
                  style: AppTypography.actionCount(color: color),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// How far each action's tap area reaches above and below its icon.
const EdgeInsets _cellPadding = EdgeInsets.symmetric(
  vertical: PostActionBar.touchSlop,
);

/// A read-only figure in the action bar, with no touch feedback.
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
      label: AppStrings.a11yCountedAction(count, semanticLabel),
      excludeSemantics: true,
      child: _CellContent(icon: icon, count: count, color: color),
    );
  }
}

class PostActionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final Color activeColor;
  final VoidCallback? onTap;

  /// Screen reader label for the icon-only control.
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
      // The whole cell answers, not just the icon.
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (onTap != null) {
          HapticFeedback.lightImpact();
          onTap!();
        }
      },
      child: _CellContent(icon: icon, count: count, color: color),
    );
  }
}
