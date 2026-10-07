import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/stats/domain/channel_stats.dart';

/// One headline figure: a label, the value, and the change from the previous
/// period. The arrow is an [Icon] so it can be coloured and given a semantic
/// label.
class StatFigureTile extends StatelessWidget {
  final String label;
  final StatFigure figure;

  const StatFigureTile({super.key, required this.label, required this.figure});

  /// Formats a figure as `2.5K`, or `43.2%` for a percentage.
  static String format(StatFigure figure) {
    if (!figure.isPercentage) {
      return TimeUtils.formatCount(figure.value.round());
    }
    final rounded = figure.value.toStringAsFixed(1);
    return AppStrings.statsPercent(
      rounded.endsWith('.0')
          ? rounded.substring(0, rounded.length - 2)
          : rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final value = format(figure);
    final growth = figure.hasGrowth
        ? figure.growthPercentage!.abs().toStringAsFixed(0)
        : null;

    return Semantics(
      label: [
        AppStrings.a11yStatFigure(label, value),
        if (growth != null)
          AppStrings.a11yStatChange(
            figure.isRising
                ? AppStrings.a11yStatsRising
                : AppStrings.a11yStatsFalling,
            growth,
          ),
      ].join(' '),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: border, width: 0.5),
          borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.timestamp(color: secondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: AppTypography.heading(
                      color: theme.colorScheme.onSurface,
                    ).copyWith(fontSize: 22),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (growth != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    figure.isRising
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 12,
                    color: figure.isRising ? AppColors.repost : AppColors.error,
                  ),
                  Text(
                    AppStrings.statsGrowth(growth),
                    style: AppTypography.timestamp(
                      color: figure.isRising
                          ? AppColors.repost
                          : AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Figure tiles side by side, all as tall as the tallest. A stretched row
/// alone has no height to stretch to inside a list, and failed its layout,
/// taking everything below it on the page with it.
class StatFigureRow extends StatelessWidget {
  final List<Widget> tiles;
  final double gap;

  const StatFigureRow({
    super.key,
    required this.tiles,
    this.gap = AppSpacing.sm,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}
