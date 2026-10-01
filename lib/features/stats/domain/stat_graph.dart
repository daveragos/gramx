import 'dart:ui';

/// How a statistics series is drawn, as Telegram declares it.
enum StatGraphShape {
  line,
  bar,
  area,
  step;

  /// True for shapes drawn as filled columns rather than a stroke.
  bool get isColumnar => this == StatGraphShape.bar;

  /// The shape named in Telegram's `types` map, or [line] for unknown types.
  static StatGraphShape parse(String? raw) => switch (raw) {
    'bar' => StatGraphShape.bar,
    'area' => StatGraphShape.area,
    'step' => StatGraphShape.step,
    _ => StatGraphShape.line,
  };
}

/// One series inside a [StatGraph].
class StatGraphLine {
  /// The column key (`y0`, `y1`, …).
  final String key;

  /// Telegram's label for the series, such as "Members". Shown untranslated.
  final String name;

  /// The colour Telegram chose for the series, if any. Used as is, so joins
  /// stay green and leaves red.
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

/// A parsed Telegram statistics graph: a shared x axis of timestamps and one
/// or more series over it. See `StatGraphParser`.
class StatGraph {
  /// Milliseconds since the epoch, ascending. The x axis of every series.
  final List<int> timestamps;

  final List<StatGraphLine> lines;

  /// Whether the series are drawn as shares summing to 100.
  final bool isPercentage;

  /// Whether the series are stacked rather than side by side.
  final bool isStacked;

  const StatGraph({
    required this.timestamps,
    required this.lines,
    this.isPercentage = false,
    this.isStacked = false,
  });

  /// True when there is no x axis, no series, or every series is empty.
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

/// A graph's load state: ready, pending a `getStatisticalGraph` call, or
/// missing. `getChatStatistics` returns most graphs as tokens.
sealed class StatGraphSource {
  const StatGraphSource();
}

/// The data came with the statistics reply.
class StatGraphReady extends StatGraphSource {
  final StatGraph graph;

  const StatGraphReady(this.graph);
}

/// Telegram has the graph but did not send it. [token] fetches it with a
/// networked `getStatisticalGraph`, so these resolve as they scroll into view.
class StatGraphPending extends StatGraphSource {
  final String token;

  const StatGraphPending(this.token);
}

/// Telegram answered with an error or something unreadable. [reason] is the
/// raw error, for logging only.
class StatGraphMissing extends StatGraphSource {
  final String? reason;

  const StatGraphMissing([this.reason]);
}
