import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/stats/domain/channel_stats.dart';

/// One post in the Content tab: what it said, and what it earned.
///
/// card uses for them — a reader should not have to learn a second vocabulary
/// for "views" between the feed and the analytics screen.
///
/// Hairline separator and no card, because this is a list of posts, and
/// every list in the app is divided the same way.
class StatPostRow extends StatelessWidget {
  final PostInteraction interaction;

  /// The post's own words, when TDLib still holds the message. A statistics
  /// list outlives the messages in it — a deleted post keeps its counts — so
  /// this is genuinely optional rather than merely late.
  final PostExcerpt? excerpt;

  final VoidCallback onTap;

  const StatPostRow({
    super.key,
    required this.interaction,
    required this.onTap,
    this.excerpt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final text = excerpt?.text?.trim();
    final publishedAt = excerpt?.publishedAt;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: border, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text == null || text.isEmpty ? AppStrings.statsPostFallback : text,
              style: AppTypography.body(color: theme.colorScheme.onSurface),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (publishedAt != null) ...[
                  Text(
                    TimeUtils.relativeTime(publishedAt),
                    style: AppTypography.timestamp(color: secondary),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                ],
                _Count(
                  icon: Icons.bar_chart,
                  count: interaction.viewCount,
                  label: AppStrings.a11yViews,
                  color: secondary,
                ),
                const SizedBox(width: AppSpacing.lg),
                _Count(
                  icon: Icons.repeat,
                  count: interaction.forwardCount,
                  label: AppStrings.a11yShares,
                  color: secondary,
                ),
                const SizedBox(width: AppSpacing.lg),
                _Count(
                  icon: Icons.favorite_border,
                  count: interaction.reactionCount,
                  label: AppStrings.a11yReactionsReadOnly,
                  color: secondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const _Count({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.a11yCountedAction(count, label),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            TimeUtils.formatCount(count),
            style: AppTypography.actionCount(color: color),
          ),
        ],
      ),
    );
  }
}
