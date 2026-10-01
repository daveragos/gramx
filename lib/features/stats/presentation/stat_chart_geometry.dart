import 'dart:math' as math;
import 'dart:ui';

import 'package:gramx/features/stats/domain/stat_graph.dart';

/// Where every point of a [StatGraph] lands inside a box. [size] is the plot
/// area, with the axis label gutters already removed.
class StatChartGeometry {
  final StatGraph graph;
  final Size size;

  /// The y axis range after stacking and padding.
  final double minY;
  final double maxY;

  /// Per line, per point: the value drawn. Running totals for a stacked
  /// graph and column shares for a percentage graph, not the raw values.
  final List<List<double>> plotted;

  /// Per line, per point: where the segment starts. Zero unless stacked.
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

    // Telegram sends raw counts with the `percentage` flag, so convert each
    // value to its share of the column.
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

    // The axis starts at zero, extending below only for negative values.
    if (graph.isPercentage) max = math.max(max, 100);
    // One unit of headroom avoids dividing by zero on a flat graph.
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

  /// The horizontal position of point [index]. A single point is centred.
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

  /// The column a bar occupies. Bars use equal slots rather than the line
  /// positions, so the first and last are not half outside the box.
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

  /// Indices of the timestamps to label on the x axis, at most [count].
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
