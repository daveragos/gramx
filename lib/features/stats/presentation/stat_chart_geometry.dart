import 'dart:math' as math;
import 'dart:ui';

import 'package:gramx/features/stats/domain/stat_graph.dart';

/// Where every point of a [StatGraph] lands inside a box.
///
/// The pure half of the chart, split out for the reason `docs/CONVENTIONS.md`
/// gives for `ChatCacheState`: the decisions with a wrong answer live here,
/// where a test can reach them, and the painter only puts ink where it is told.
/// The wrong answers this exists to pin are the arithmetic ones — a flat line
/// dividing by a zero range, a single-point graph dividing by `n - 1`, and a
/// stacked series drawn from the wrong baseline.
///
/// [size] is the **plot area** — axis labels are laid out by the painter and
/// their gutters are already taken off.
class StatChartGeometry {
  final StatGraph graph;
  final Size size;

  /// The lowest and highest values on the y axis after stacking, and after any
  /// padding the axis needs to be readable.
  final double minY;
  final double maxY;

  /// Per line, per point: the value actually drawn.
  ///
  /// Not the raw numbers — a stacked graph plots running totals and a
  /// percentage graph plots shares of each column, so a painter reading
  /// `line.values` directly would draw a different chart from the one the axis
  /// was scaled for.
  final List<List<double>> plotted;

  /// Per line, per point: where that point's segment starts.
  ///
  /// Zero everywhere except in a stacked graph, where a segment sits on top of
  /// the one below it.
  final List<List<double>> baselines;

  StatChartGeometry._({
    required this.graph,
    required this.size,
    required this.minY,
    required this.maxY,
    required this.plotted,
    required this.baselines,
  });

  factory StatChartGeometry.of(StatGraph graph, Size size) {
    final lineCount = graph.lines.length;
    final pointCount = graph.timestamps.length;

    final values = [
      for (final line in graph.lines)
        [
          for (var i = 0; i < pointCount; i++)
            i < line.values.length ? line.values[i] : 0.0,
        ],
    ];

    // A percentage graph is drawn as each series' share of its own column, not
    // as the raw counts — Telegram sends the counts and the `percentage` flag,
    // and scaling an axis to the counts of a chart that means "share of the
    // audience" produces a chart nobody can read.
    if (graph.isPercentage) {
      for (var i = 0; i < pointCount; i++) {
        var total = 0.0;
        for (var l = 0; l < lineCount; l++) {
          total += values[l][i];
        }
        if (total == 0) continue;
        for (var l = 0; l < lineCount; l++) {
          values[l][i] = values[l][i] / total * 100;
        }
      }
    }

    final baselines = [
      for (var l = 0; l < lineCount; l++) List<double>.filled(pointCount, 0),
    ];

    if (graph.isStacked || graph.isPercentage) {
      for (var i = 0; i < pointCount; i++) {
        var running = 0.0;
        for (var l = 0; l < lineCount; l++) {
          baselines[l][i] = running;
          running += values[l][i];
          values[l][i] = running;
        }
      }
    }

    var min = 0.0;
    var max = 0.0;
    for (final line in values) {
      for (final value in line) {
        min = math.min(min, value);
        max = math.max(max, value);
      }
    }

    // Every count graph starts at zero, so a bar's height reads as its value.
    // Negatives only appear where Telegram sends them, and then the axis opens
    // downwards to hold them rather than clipping them off.
    if (graph.isPercentage) max = math.max(max, 100);
    // A flat graph — a channel with the same member count all month — has a
    // zero range, and every division by it is an infinity. One unit of headroom
    // draws the line along the bottom of the box, which is what it is.
    if (max - min < 1e-9) max = min + 1;

    return StatChartGeometry._(
      graph: graph,
      size: size,
      minY: min,
      maxY: max,
      plotted: values,
      baselines: baselines,
    );
  }

  int get pointCount => graph.timestamps.length;

  int get lineCount => graph.lines.length;

  bool get isEmpty => pointCount == 0 || lineCount == 0;

  /// The horizontal position of point [index].
  ///
  /// A single-point graph is centred: the usual `index / (count - 1)` divides
  /// by zero there, and a channel one day old is a real thing to open this
  /// screen on.
  double xAt(int index) {
    if (pointCount <= 1) return size.width / 2;
    return index / (pointCount - 1) * size.width;
  }

  /// The vertical position of [value], with the axis growing upwards.
  double yFor(double value) {
    final range = maxY - minY;
    final fraction = (value - minY) / range;
    return size.height - fraction * size.height;
  }

  Offset pointAt(int line, int index) =>
      Offset(xAt(index), yFor(plotted[line][index]));

  /// The column a bar occupies. Bars divide the width into equal slots rather
  /// than sitting on the line positions, so the first and last are fully drawn
  /// instead of half outside the box.
  Rect barRect(int line, int index, {double gap = 0}) {
    final slot = size.width / math.max(pointCount, 1);
    final left = index * slot + gap / 2;
    final width = math.max(slot - gap, 1.0);
    final top = yFor(plotted[line][index]);
    final bottom = yFor(baselines[line][index]);
    return Rect.fromLTRB(
      left,
      math.min(top, bottom),
      left + width,
      math.max(top, bottom),
    );
  }

  /// The values the horizontal gridlines sit on, bottom to top.
  List<double> gridValues({int count = 4}) {
    if (count < 1) return [minY];
    final step = (maxY - minY) / count;
    return [for (var i = 0; i <= count; i++) minY + step * i];
  }

  /// The timestamps to label the x axis with, as indices into the graph.
  ///
  /// per day on a three-month graph is a grey smear.
  List<int> labelIndices({int count = 4}) {
    if (pointCount == 0) return const [];
    if (pointCount <= count) {
      return [for (var i = 0; i < pointCount; i++) i];
    }
    final step = (pointCount - 1) / (count - 1);
    return [for (var i = 0; i < count; i++) (i * step).round()];
  }

  DateTime dateAt(int index) =>
      DateTime.fromMillisecondsSinceEpoch(graph.timestamps[index]);
}
