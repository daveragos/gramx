import 'dart:ui';

/// The shape a statistics line is drawn in, as the graph itself declares it.
///
/// Telegram sends the shape with the data — a member count is a line, a day's
/// joins are bars, a language split is a filled area — so the chart draws what
/// it was told rather than what the calling screen guessed.
enum StatGraphShape {
  line,
  bar,
  area,
  step;

  /// True for the shapes drawn as filled columns rather than as a stroke.
  bool get isColumnar => this == StatGraphShape.bar;

  /// The shape named by Telegram's own `types` map, or [line] for anything
  /// this app has no drawing for. An unknown shape is still real data, and a
  /// stroke through it says more than an empty box.
  static StatGraphShape parse(String? raw) => switch (raw) {
    'bar' => StatGraphShape.bar,
    'area' => StatGraphShape.area,
    'step' => StatGraphShape.step,
    _ => StatGraphShape.line,
  };
}

/// One series inside a [StatGraph] — the numbers, and what Telegram calls them.
class StatGraphLine {
  /// The column key (`y0`, `y1`, …). Kept because `names` and `colors` are
  /// keyed on it and a graph can arrive with either of them missing.
  final String key;

  /// Telegram's own label for the series — "Members", "Left", "Shared".
  ///
  /// It is user-facing text that this app did not write and cannot translate;
  /// it is also the only thing that distinguishes two lines of the same chart.
  final String name;

  /// The colour Telegram chose for the series, when it sent one.
  ///
  /// Worth honouring rather than overriding: joins are green and leaves are
  /// red in every Telegram client, and a chart that recoloured both to the
  /// accent would need a legend to say which was which.
  final Color? color;

  final StatGraphShape shape;

  /// One value per entry in [StatGraph.timestamps].
  final List<double> values;

  const StatGraphLine({
    required this.key,
    required this.name,
    required this.shape,
    required this.values,
    this.color,
  });
}

/// A parsed Telegram statistics graph: a shared x axis of timestamps, and one
/// or more series over it.
///
/// TDLib hands these over as a JSON string in a format of Telegram's own —
/// see `StatGraphParser`, which is where the reading of it lives.
class StatGraph {
  /// Milliseconds since the epoch, ascending. The x axis of every series.
  final List<int> timestamps;

  final List<StatGraphLine> lines;

  /// The series sum to 100 at every point and are drawn as proportions.
  final bool isPercentage;

  /// The series sit on top of each other rather than beside each other.
  final bool isStacked;

  const StatGraph({
    required this.timestamps,
    required this.lines,
    this.isPercentage = false,
    this.isStacked = false,
  });

  /// Nothing to draw: no x axis, no series, or every series empty.
  bool get isEmpty =>
      timestamps.isEmpty ||
      lines.isEmpty ||
      lines.every((line) => line.values.isEmpty);

  bool get isNotEmpty => !isEmpty;

  /// The first and last timestamps as dates, or null for an empty graph.
  DateTime? get startsAt => timestamps.isEmpty
      ? null
      : DateTime.fromMillisecondsSinceEpoch(timestamps.first);

  DateTime? get endsAt => timestamps.isEmpty
      ? null
      : DateTime.fromMillisecondsSinceEpoch(timestamps.last);
}

/// Where a graph currently is, which is not always "here".
///
/// TDLib answers `getChatStatistics` with most graphs **unresolved** — a token
/// to call `getStatisticalGraph` with, rather than the data. So a graph has
/// three states and the screen has to be able to draw all of them: one that
/// arrived with the reply, one that is a request away, and one Telegram
/// declined to produce at all.
sealed class StatGraphSource {
  const StatGraphSource();
}

/// The data came with the statistics reply. Nothing more to ask for.
class StatGraphReady extends StatGraphSource {
  final StatGraph graph;

  const StatGraphReady(this.graph);
}

/// Telegram has the graph but did not send it. [token] fetches it.
///
/// One networked `getStatisticalGraph` each, which is why a screen full of
/// these resolves them as they are scrolled to rather than all at once — see
/// `StatGraphsNotifier`.
class StatGraphPending extends StatGraphSource {
  final String token;

  const StatGraphPending(this.token);
}

/// Telegram answered with an error, or with something unreadable.
///
/// [reason] is Telegram's raw string and is for the log, not for the reader —
/// the screen says a graph is unavailable in its own words.
class StatGraphMissing extends StatGraphSource {
  final String? reason;

  const StatGraphMissing([this.reason]);
}
