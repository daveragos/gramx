import 'package:gramx/features/stats/domain/stat_graph.dart';

/// The models behind the analytics screens.
///
/// Plain classes rather than Freezed, which is the default here — for the
/// same reason `ActivityItem` and `UserProfile` are. Nothing
/// here is stored, sent, or copied with a field changed: it is read from TDLib
/// once, drawn, and dropped when the screen closes, so `copyWith` and a JSON
/// codec would be generated code with no caller.

/// One headline number, with what it was before it.
///
/// Telegram's `statisticalValue` carries the current figure, the previous
/// (`131.4K ↑315%`), so nothing here has to be computed by this app.
class StatFigure {
  final double value;

  /// The same figure over the preceding period, when Telegram sent one.
  final double? previousValue;

  /// Growth as a percentage: `315` means the figure more than quadrupled.
  ///
  /// Null when there is no earlier period to compare against — a channel in
  /// its first week has a real view count and no honest arrow to put on it.
  final double? growthPercentage;

  /// The value *is* a percentage and reads as `43%` rather than as a count.
  ///
  /// Only "notifications enabled" is one; every other figure is a tally.
  final bool isPercentage;

  const StatFigure({
    required this.value,
    this.previousValue,
    this.growthPercentage,
    this.isPercentage = false,
  });

  /// True when the arrow is worth drawing.
  ///
  /// A growth of exactly zero is the common case for a quiet week, and an
  /// arrow pointing sideways at `0%` is three pixels of nothing. Telegram also
  /// reports `0` when it simply has no previous period, which would otherwise
  /// render as "no change" — a claim this app cannot make.
  bool get hasGrowth =>
      growthPercentage != null && growthPercentage!.abs() >= 0.05;

  bool get isRising => (growthPercentage ?? 0) > 0;
}

/// The tiles across the top of the channel's Overview.
///
/// Ordered the way they are drawn. Telegram sends a few figures gramX has no
/// surface for — the story means — and those are dropped rather than shown as
/// zeroes for a feature the app does not render.
enum ChannelStatFigure {
  followers,
  notifications,
  viewsPerPost,
  sharesPerPost,
  reactionsPerPost,
}

/// The charts a channel's statistics can contain.
///
/// One per graph gramX draws, named for what it shows rather than for TDLib's
/// field. The story graphs are deliberately absent: gramX has no stories
/// surface, and a chart about a thing the app cannot show is noise on a screen
/// whose whole job is to be read.
enum ChannelStatGraph {
  growth,

  /// colours: gains up, losses down.
  followers,

  /// Notifications enabled versus muted.
  notifications,

  viewsByHour,

  /// Where views came from — followers, channels, search, URLs.
  viewsBySource,

  /// Where new followers came from.
  newFollowersBySource,

  /// The languages the audience reads in.
  languages,

  /// Views and shares per post, over time.
  interactions,

  /// Reactions per post, over time.
  reactions,

  /// Instant View opens, for channels that publish them.
  instantViews,
}

/// One post, with what Telegram counted on it.
///
/// and the message id needed to open the post itself. It carries no text —
/// `getChatStatistics` names messages by id only, and the words are fetched in
/// one batched request afterwards.
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

/// Everything `getChatStatistics` said about a channel, in this app's terms.
class ChannelStats {
  /// The window the figures describe. Telegram chooses it, not the reader.
  final DateTime periodStart;
  final DateTime periodEnd;

  /// The headline tiles, in [ChannelStatFigure] order. A figure Telegram did
  /// not send is absent rather than zero.
  final Map<ChannelStatFigure, StatFigure> figures;

  /// The charts, most of them still a token away — see [StatGraphSource].
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

/// The words and the date behind a [PostInteraction].
///
/// `getChatStatistics` names a post by id and nothing else, so a Content row
/// would otherwise be three numbers and no post. Fetched separately and
/// **locally**, which is why every field but the id is optional: a row whose
/// message TDLib no longer holds still has real counts to show.
class PostExcerpt {
  final int messageId;
  final String? text;
  final DateTime? publishedAt;

  const PostExcerpt({required this.messageId, this.text, this.publishedAt});
}
