import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/channels/presentation/channel_profile_screen.dart'
    show ChannelRetry;
import 'package:gramx/features/stats/domain/channel_stats.dart';
import 'package:gramx/features/stats/presentation/post_stats_screen.dart';
import 'package:gramx/features/stats/presentation/stats_providers.dart';
import 'package:gramx/features/stats/presentation/widgets/stat_figure_tile.dart';
import 'package:gramx/features/stats/presentation/widgets/stat_post_row.dart';
import 'package:gramx/features/stats/presentation/widgets/stat_section.dart';

/// What a channel's own numbers look like, for the person who runs it.
///
/// this does not (Video, Live, Spaces) are absent rather than empty, because
/// Telegram has no equivalent to put in them and a tab that opens onto nothing
/// is the inert control the hard rules forbid.
///
/// **What it costs.** One `getChatStatistics` on open, then one
/// `getStatisticalGraph` per chart the reader actually scrolls to — see
/// `StatSection`, which is where that rule is enforced. Nothing here runs
/// without somebody looking at it.
class ChannelStatsScreen extends ConsumerStatefulWidget {
  /// The route, with the channel's chat id in it.
  static const String route = '/channel/:channelId/stats';

  static String routeFor(int chatId) => '/channel/$chatId/stats';

  final String channelId;

  const ChannelStatsScreen({super.key, required this.channelId});

  @override
  ConsumerState<ChannelStatsScreen> createState() => _ChannelStatsScreenState();
}

class _ChannelStatsScreenState extends ConsumerState<ChannelStatsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatId = int.tryParse(widget.channelId);

    final title = Text(
      AppStrings.statsTitle,
      style: AppTypography.heading(color: theme.colorScheme.onSurface),
    );

    // Nothing to ask Telegram about: a malformed link, or a guest channel,
    // whose posts come from a public preview page and have no account behind
    // them to hold statistics.
    if (chatId == null) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: const Center(child: _Unavailable()),
      );
    }

    final request = (
      chatId: chatId,
      isDark: theme.brightness == Brightness.dark,
    );
    final statsAsync = ref.watch(channelStatsProvider(request));

    return Scaffold(
      appBar: AppBar(
        title: title,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.accent,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: theme.colorScheme.onSurface,
          unselectedLabelColor: theme.brightness == Brightness.dark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
          tabs: const [
            Tab(text: AppStrings.statsTabOverview),
            Tab(text: AppStrings.statsTabAudience),
            Tab(text: AppStrings.statsTabContent),
          ],
        ),
      ),
      body: statsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (error, _) => ChannelRetry(
          message: AppStrings.statsLoadFailed,
          detail: error.toString(),
          onRetry: () async => ref.invalidate(channelStatsProvider(request)),
        ),
        data: (stats) {
          if (stats == null) return const Center(child: _Unavailable());
          return TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(chatId: chatId, stats: stats),
              _AudienceTab(chatId: chatId, stats: stats),
              _ContentTab(chatId: chatId, stats: stats, request: request),
            ],
          );
        },
      ),
    );
  }
}

/// Telegram produces statistics only for a channel past a member threshold of
/// its own, and only for somebody who administers it. The entry point is
/// hidden unless `SupergroupFullInfo.canGetStatistics` says otherwise, so this
/// covers the window where that changed under the reader.
class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(
        AppStrings.statsUnavailable,
        textAlign: TextAlign.center,
        style: AppTypography.body(
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final int chatId;
  final ChannelStats stats;

  const _OverviewTab({required this.chatId, required this.stats});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      children: [
        _PeriodHeader(stats: stats),
        _FigureGrid(figures: stats.figures),
        const SizedBox(height: AppSpacing.lg),
        for (final graph in const [
          ChannelStatGraph.growth,
          ChannelStatGraph.followers,
          ChannelStatGraph.interactions,
          ChannelStatGraph.reactions,
          ChannelStatGraph.instantViews,
        ])
          _section(chatId, stats, graph),
      ],
    );
  }
}

class _AudienceTab extends StatelessWidget {
  final int chatId;
  final ChannelStats stats;

  const _AudienceTab({required this.chatId, required this.stats});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      children: [
        for (final graph in const [
          ChannelStatGraph.viewsByHour,
          ChannelStatGraph.viewsBySource,
          ChannelStatGraph.newFollowersBySource,
          ChannelStatGraph.languages,
          ChannelStatGraph.notifications,
        ])
          _section(chatId, stats, graph),
      ],
    );
  }
}

///
/// The counts come with the statistics reply and cost nothing extra. The words
/// are fetched separately and **locally** — see `StatsRepository.postExcerpts` —
/// which is why a row draws as soon as its numbers are there and fills in its
/// text a beat later rather than holding the list back.
class _ContentTab extends ConsumerWidget {
  final int chatId;
  final ChannelStats stats;
  final ChannelStatsRequest request;

  const _ContentTab({
    required this.chatId,
    required this.stats,
    required this.request,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final excerpts = ref.watch(channelStatsExcerptsProvider(request)).value;

    if (stats.recentPosts.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            AppStrings.statsContentEmpty,
            style: AppTypography.body(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      itemCount: stats.recentPosts.length,
      itemBuilder: (context, index) {
        final interaction = stats.recentPosts[index];
        return StatPostRow(
          interaction: interaction,
          excerpt: excerpts?[interaction.messageId],
          onTap: () => context.push(
            PostStatsScreen.routeFor(chatId, interaction.messageId),
          ),
        );
      },
    );
  }
}

/// One chart, titled. Absent entirely when Telegram sent no such graph.
Widget _section(int chatId, ChannelStats stats, ChannelStatGraph graph) {
  final source = stats.graphs[graph];
  if (source == null) return const SizedBox.shrink();
  return StatSection(
    chatId: chatId,
    title: _graphTitle(graph),
    source: source,
    slug: graph.name,
  );
}

String _graphTitle(ChannelStatGraph graph) => switch (graph) {
  ChannelStatGraph.growth => AppStrings.statsGraphGrowth,
  ChannelStatGraph.followers => AppStrings.statsGraphJoins,
  ChannelStatGraph.notifications => AppStrings.statsGraphNotifications,
  ChannelStatGraph.viewsByHour => AppStrings.statsGraphViewsByHour,
  ChannelStatGraph.viewsBySource => AppStrings.statsGraphViewsBySource,
  ChannelStatGraph.newFollowersBySource =>
    AppStrings.statsGraphNewFollowersBySource,
  ChannelStatGraph.languages => AppStrings.statsGraphLanguages,
  ChannelStatGraph.interactions => AppStrings.statsGraphInteractions,
  ChannelStatGraph.reactions => AppStrings.statsGraphReactions,
  ChannelStatGraph.instantViews => AppStrings.statsGraphInstantViews,
};

String _figureLabel(ChannelStatFigure figure) => switch (figure) {
  ChannelStatFigure.followers => AppStrings.statsFollowers,
  ChannelStatFigure.notifications => AppStrings.statsNotifications,
  ChannelStatFigure.viewsPerPost => AppStrings.statsViewsPerPost,
  ChannelStatFigure.sharesPerPost => AppStrings.statsSharesPerPost,
  ChannelStatFigure.reactionsPerPost => AppStrings.statsReactionsPerPost,
};

class _PeriodHeader extends StatelessWidget {
  final ChannelStats stats;

  const _PeriodHeader({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.statsAccountOverview,
            style: AppTypography.heading(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            AppStrings.statsPeriod(
              TimeUtils.shortDate(stats.periodStart),
              TimeUtils.shortDate(stats.periodEnd),
            ),
            style: AppTypography.timestamp(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// needs to sit next to its arrow without wrapping.
class _FigureGrid extends StatelessWidget {
  final Map<ChannelStatFigure, StatFigure> figures;

  const _FigureGrid({required this.figures});

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final figure in ChannelStatFigure.values)
        if (figures[figure] != null) (figure, figures[figure]!),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: StatFigureTile(
                      label: _figureLabel(entries[i].$1),
                      figure: entries[i].$2,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: i + 1 < entries.length
                        ? StatFigureTile(
                            label: _figureLabel(entries[i + 1].$1),
                            figure: entries[i + 1].$2,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
