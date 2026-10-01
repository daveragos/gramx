import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/stats/data/stat_graph_parser.dart';
import 'package:gramx/features/stats/domain/channel_stats.dart';
import 'package:gramx/features/stats/domain/post_stats.dart';
import 'package:gramx/features/stats/domain/stat_graph.dart';

/// Maps TDLib's statistics objects to domain types.
abstract class StatsMapper {
  /// How many recent interactions the Content tab keeps. Their text comes
  /// from one batched `getMessages`, which takes at most 100 ids.
  static const int recentPostLimit = 30;

  /// A channel's statistics. Returns null for any variant other than
  /// [td.ChatStatisticsChannel], such as supergroup statistics.
  static ChannelStats? mapChannel(td.ChatStatistics statistics) {
    if (statistics is! td.ChatStatisticsChannel) return null;

    return ChannelStats(
      periodStart: DateTime.fromMillisecondsSinceEpoch(
        statistics.period.startDate * 1000,
      ),
      periodEnd: DateTime.fromMillisecondsSinceEpoch(
        statistics.period.endDate * 1000,
      ),
      figures: {
        ChannelStatFigure.followers: _figure(statistics.memberCount),
        // A bare percentage rather than a statisticalValue, so it has no
        // previous period and no growth arrow.
        ChannelStatFigure.notifications: StatFigure(
          value: statistics.enabledNotificationsPercentage,
          isPercentage: true,
        ),
        ChannelStatFigure.viewsPerPost: _figure(
          statistics.meanMessageViewCount,
        ),
        ChannelStatFigure.sharesPerPost: _figure(
          statistics.meanMessageShareCount,
        ),
        ChannelStatFigure.reactionsPerPost: _figure(
          statistics.meanMessageReactionCount,
        ),
      },
      graphs: {
        ChannelStatGraph.growth: graph(statistics.memberCountGraph),
        ChannelStatGraph.followers: graph(statistics.joinGraph),
        ChannelStatGraph.notifications: graph(statistics.muteGraph),
        ChannelStatGraph.viewsByHour: graph(statistics.viewCountByHourGraph),
        ChannelStatGraph.viewsBySource: graph(
          statistics.viewCountBySourceGraph,
        ),
        ChannelStatGraph.newFollowersBySource: graph(
          statistics.joinBySourceGraph,
        ),
        ChannelStatGraph.languages: graph(statistics.languageGraph),
        ChannelStatGraph.interactions: graph(
          statistics.messageInteractionGraph,
        ),
        ChannelStatGraph.reactions: graph(statistics.messageReactionGraph),
        ChannelStatGraph.instantViews: graph(
          statistics.instantViewInteractionGraph,
        ),
      },
      recentPosts: recentPosts(statistics.recentInteractions),
    );
  }

  /// Recent post interactions, newest first. Stories are dropped since the
  /// app has no screen to open them on.
  static List<PostInteraction> recentPosts(
    List<td.ChatStatisticsInteractionInfo> interactions,
  ) {
    final posts = <PostInteraction>[];
    for (final interaction in interactions) {
      final type = interaction.objectType;
      if (type is! td.ChatStatisticsObjectTypeMessage) continue;
      posts.add(
        PostInteraction(
          messageId: type.messageId,
          viewCount: interaction.viewCount,
          forwardCount: interaction.forwardCount,
          reactionCount: interaction.reactionCount,
        ),
      );
    }

    // Sort by id (ascending with time) rather than rely on Telegram's order.
    posts.sort((a, b) => b.messageId.compareTo(a.messageId));
    if (posts.length > recentPostLimit) {
      return posts.sublist(0, recentPostLimit);
    }
    return posts;
  }

  /// One post's statistics.
  static PostStats mapMessage(td.MessageStatistics statistics) => PostStats(
    interactionGraph: graph(statistics.messageInteractionGraph),
    reactionGraph: graph(statistics.messageReactionGraph),
  );

  /// Maps a TDLib graph to its source state. Unreadable data becomes
  /// [StatGraphMissing], not an empty [StatGraphReady].
  static StatGraphSource graph(td.StatisticalGraph source) => switch (source) {
    td.StatisticalGraphData(:final jsonData) => _parsed(jsonData),
    td.StatisticalGraphAsync(:final token) => StatGraphPending(token),
    td.StatisticalGraphError(:final errorMessage) => StatGraphMissing(
      errorMessage,
    ),
  };

  static StatGraphSource _parsed(String jsonData) {
    final parsed = StatGraphParser.parse(jsonData);
    if (parsed == null || parsed.isEmpty) return const StatGraphMissing();
    return StatGraphReady(parsed);
  }

  /// Telegram's growth rate is already a percentage, and is `0` both for no
  /// change and for no previous period. See [StatFigure.hasGrowth].
  static StatFigure _figure(td.StatisticalValue value) => StatFigure(
    value: value.value,
    previousValue: value.previousValue,
    growthPercentage: value.growthRatePercentage,
  );
}
