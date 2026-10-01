import 'package:gramx/features/stats/domain/stat_graph.dart';

/// The models behind the analytics screens. Plain classes rather than
/// Freezed, since they are never stored, serialized or copied.

/// One headline number with its previous value and growth.
class StatFigure {
  final double value;

  /// The same figure over the preceding period, when Telegram sent one.
  final double? previousValue;

  /// Growth as a percentage: `315` means the figure more than quadrupled.
  /// Null when there is no earlier period to compare against.
  final double? growthPercentage;

  /// Whether the value is a percentage rather than a count.
  final bool isPercentage;

  const StatFigure({
    required this.value,
    this.previousValue,
    this.growthPercentage,
    this.isPercentage = false,
  });

  /// Whether to draw a growth arrow. Not for zero, which Telegram also sends
  /// when there is no previous period.
  bool get hasGrowth =>
      growthPercentage != null && growthPercentage!.abs() >= 0.05;

  bool get isRising => (growthPercentage ?? 0) > 0;
}

/// The tiles across the top of the channel's Overview, in display order.
/// Story figures are dropped since the app has no stories.
enum ChannelStatFigure {
  followers,
  notifications,
  viewsPerPost,
  sharesPerPost,
  reactionsPerPost,
}

/// The charts drawn from a channel's statistics, named for what they show.
/// Story graphs are left out.
enum ChannelStatGraph {
  /// Members over time.
  growth,

  /// Joined and left per day: gains up, losses down.
  followers,

  /// Notifications enabled versus muted.
  notifications,

  viewsByHour,

  /// Where views came from: followers, channels, search, URLs.
  viewsBySource,

  newFollowersBySource,

  languages,

  /// Views and shares per post, over time.
  interactions,

  /// Reactions per post, over time.
  reactions,

  /// Instant View opens, for channels that publish them.
  instantViews,
}

/// A Content tab row: one post's counts and its message id. The text is
/// fetched separately, since `getChatStatistics` only sends ids.
class PostInteraction {
  final int messageId;
  final int viewCount;
  final int forwardCount;
  final int reactionCount;

  const PostInteraction({
    required this.messageId,
    required this.viewCount,
    required this.forwardCount,
    required this.reactionCount,
  });
}

/// A channel's statistics from `getChatStatistics`.
class ChannelStats {
  /// The period the figures cover, chosen by Telegram.
  final DateTime periodStart;
  final DateTime periodEnd;

  /// The headline tiles, in [ChannelStatFigure] order. A figure Telegram did
  /// not send is absent rather than zero.
  final Map<ChannelStatFigure, StatFigure> figures;

  /// The charts, most of them still unresolved tokens. See [StatGraphSource].
  final Map<ChannelStatGraph, StatGraphSource> graphs;

  /// The channel's recent posts and their counts, newest first.
  final List<PostInteraction> recentPosts;

  const ChannelStats({
    required this.periodStart,
    required this.periodEnd,
    required this.figures,
    required this.graphs,
    required this.recentPosts,
  });
}

/// The text and date of a [PostInteraction]'s post. Read locally, so both
/// are null when TDLib no longer has the message.
class PostExcerpt {
  final int messageId;
  final String? text;
  final DateTime? publishedAt;

  const PostExcerpt({required this.messageId, this.text, this.publishedAt});
}
