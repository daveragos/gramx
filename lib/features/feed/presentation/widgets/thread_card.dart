import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/feed_thread.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_focus_controller.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';

/// One feed entry: a post, plus any follow-ups its channel posted in reply.
///
/// Collapsed by default. A channel that posts five related messages should take
/// one slot in the feed, not five — otherwise it buries every other channel.
/// Expanding keeps the replies inline and indented, so the relationship stays
/// visible rather than requiring a trip to another screen.
class ThreadCard extends ConsumerStatefulWidget {
  final FeedThread thread;
  final void Function(Post post) onOpenPost;
  final void Function(Post post) onOpenChannel;

  const ThreadCard({
    super.key,
    required this.thread,
    required this.onOpenPost,
    required this.onOpenChannel,
  });

  @override
  ConsumerState<ThreadCard> createState() => _ThreadCardState();
}

class _ThreadCardState extends ConsumerState<ThreadCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final thread = widget.thread;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    Widget cardFor(Post post) => PostVisibilityReporter(
          postId: post.id,
          child: PostCard(
            post: post,
            onTap: () => widget.onOpenPost(post),
            onChannelTap: () => widget.onOpenChannel(post),
          ),
        );

    // Indented under a rail, so earlier posts read as context for the one
    // below rather than as new top-level cards.
    Widget contextCardFor(Post post) => Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xl),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: secondary.withValues(alpha: 0.3)),
              ),
            ),
            child: cardFor(post),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (thread.hasReplies) ...[
          // The toggle sits above the newest post, because expanding reveals
          // what came *before* it.
          _ThreadToggle(
            count: thread.earlier.length,
            expanded: _expanded,
            color: secondary,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            for (final post in thread.earlier) contextCardFor(post),
        ],
        // The newest post is what surfaced this thread, so it is the card.
        cardFor(thread.latest),
      ],
    );
  }
}

class _ThreadToggle extends StatelessWidget {
  final int count;
  final bool expanded;
  final Color color;
  final VoidCallback onTap;

  const _ThreadToggle({
    required this.count,
    required this.expanded,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = expanded
        ? AppStrings.threadHide
        : AppStrings.threadShow(count);

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxxl + AppSpacing.md,
            0,
            AppSpacing.postPadding,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Text(
                label,
                style: AppTypography.actionCount(color: AppColors.accent)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: AppColors.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
