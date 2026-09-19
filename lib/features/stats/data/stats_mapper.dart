import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/stats/data/stat_graph_parser.dart';
import 'package:gramx/features/stats/domain/channel_stats.dart';
import 'package:gramx/features/stats/domain/post_stats.dart';
import 'package:gramx/features/stats/domain/stat_graph.dart';

/// TDLib's statistics objects, in this app's terms.
///
/// Pure and separate from `StatsRepository` for the reason `docs/CONVENTIONS.md`
/// gives: the repository owns the requests, and every decision that has a wrong
/// answer lives somewhere a test can reach without a TDLib client.
abstract class StatsMapper {
  /// How many of Telegram's recent interactions the Content tab keeps.
  ///
  /// Telegram sends up to a few hundred. Each row wants the post's own words,
  /// and those come from one batched `getMessages` — which takes at most 100
  /// ids and is a networked request whichever way it is sliced. Thirty is the
  /// depth a reader scrolls before switching to a longer view, and it keeps
  /// the batch comfortably inside the limit.
  static const int recentPostLimit = 30;

  /// A channel's statistics.
  ///
  /// Only [td.ChatStatisticsChannel] maps: the supergroup variant describes a
  /// group's senders and administrators, which is a different screen for a
  /// different thing, and gramX only ever opens this on a channel. An
  /// unexpected variant answers null so the screen can say so rather than draw
  /// a page of zeroes.
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
        // The only figure Telegram sends as a bare percentage rather than as a
        // statisticalValue, so it has no previous period and no arrow.
        ChannelStatFigure.notifications: StatFigure(
          value: statistics.enabledNotificationsPercentage,
          isPercentage: true,
        ),
        ChannelStatFigure.viewsPerPost: _figure(statistics.meanMessageViewCount),
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

  /// The recent interactions this app can draw, newest first.
  ///
  /// Stories are dropped rather than listed: gramX has no screen to open one
  /// on, so a row for one would be a row that goes nowhere — the inert control
  /// the hard rules forbid, wearing a list's clothes.
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

    // Telegram orders these newest first already; sorting on the id says so in
    // the code rather than relying on it, and message ids ascend with time.
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

  /// A TDLib graph as the three states a graph can be in.
  ///
  /// Data that arrived but cannot be read is [StatGraphMissing], not an empty
  /// [StatGraphReady] — see `StatGraphParser.parse`.
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

  /// Telegram's growth rate is already a percentage, and it is `0` both for
  /// "unchanged" and for "there was no previous period". [StatFigure.hasGrowth]
  /// is what refuses to draw an arrow on either.
  static StatFigure _figure(td.StatisticalValue value) => StatFigure(
    value: value.value,
    previousValue: value.previousValue,
    growthPercentage: value.growthRatePercentage,
  );
}
