import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/stats/domain/stat_graph.dart';
import 'package:gramx/features/stats/presentation/stats_providers.dart';
import 'package:gramx/features/stats/presentation/widgets/stat_chart.dart';

/// A titled chart that loads its graph the first time it becomes visible,
/// rather than in `build`, since lists build items ahead of the screen.
/// `StatGraphLoads` ensures each token is requested once.
class StatSection extends ConsumerWidget {
  final int chatId;
  final String title;
  final StatGraphSource source;

  /// Makes this card's visibility key unique on screen.
  final String slug;

  const StatSection({
    super.key,
    required this.chatId,
    required this.title,
    required this.source,
    required this.slug,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final loads = source is StatGraphPending
        ? ref.watch(statGraphsProvider(chatId))
        : null;

    // A pending graph shows whatever its token resolved to.
    final resolved = switch (source) {
      StatGraphPending(:final token) => loads?[token] ?? source,
      _ => source,
    };

    Widget body = switch (resolved) {
      StatGraphReady(:final graph) when graph.isNotEmpty => StatChart(
        graph: graph,
        semanticLabel: AppStrings.a11yStatChart(title),
      ),
      StatGraphReady() => _Message(text: AppStrings.statsGraphEmpty),
      StatGraphMissing() => _Message(text: AppStrings.statsGraphUnavailable),
      StatGraphPending() => const _ChartSkeleton(),
    };

    if (source case StatGraphPending(:final token)) {
      body = VisibilityDetector(
        key: Key('stat-graph-$chatId-$slug'),
        onVisibilityChanged: (info) {
          if (info.visibleFraction <= 0) return;
          ref.read(statGraphsProvider(chatId).notifier).ensureLoaded(token);
        },
        child: body,
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.subheading(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.md),
          body,
        ],
      ),
    );
  }
}

/// A message in place of a chart with nothing to draw, since an empty frame
/// would read as no activity.
class _Message extends StatelessWidget {
  final String text;

  const _Message({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Text(
        text,
        style: AppTypography.body(
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      highlightColor: isDark
          ? AppColors.darkSurfaceVariant
          : AppColors.lightSurfaceVariant,
      child: Container(
        height: 168,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
      ),
    );
  }
}
