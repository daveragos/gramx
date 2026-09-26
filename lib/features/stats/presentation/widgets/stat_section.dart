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

/// A titled chart, which fetches itself when it is looked at.
///
/// **This is where the request rule for this screen lives.** TDLib sends most
/// graphs as a token rather than as data, so resolving them all when the
/// statistics reply lands would be ten requests for ten charts on a screen
/// that shows three of them without scrolling — the same fault as loading a
/// channel's four tabs on open. A card asks for
/// its own graph the first time it is **visible**, and `StatGraphLoads` makes
/// sure it asks once however many times it crosses the viewport edge.
///
/// Visibility rather than `build` is deliberate twice over: a list builds
/// items ahead of what is on screen, and a side effect in `build` is against
/// the hard rules anyway.
class StatSection extends ConsumerWidget {
  final int chatId;
  final String title;
  final StatGraphSource source;

  /// Distinguishes this card's visibility key from every other one on screen.
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

    // A pending graph stands in for whatever came back for its token — which
    // may itself be "Telegram has no data for this".
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

/// A chart that has nothing to draw, said in a sentence rather than as an
/// empty frame — a gridded box with no line in it reads as a channel with no
/// activity, which is a claim about the channel rather than about the data.
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
