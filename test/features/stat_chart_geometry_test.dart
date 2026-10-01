import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/stats/domain/stat_graph.dart';
import 'package:gramx/features/stats/presentation/stat_chart_geometry.dart';

StatGraph _graph({
  List<int>? timestamps,
  required List<List<double>> series,
  StatGraphShape shape = StatGraphShape.line,
  bool stacked = false,
  bool percentage = false,
}) {
  final length = series.first.length;
  return StatGraph(
    timestamps:
        timestamps ??
        [for (var i = 0; i < length; i++) 1719792000000 + i * 86400000],
    lines: [
      for (var i = 0; i < series.length; i++)
        StatGraphLine(key: 'y$i', name: 'y$i', shape: shape, values: series[i]),
    ],
    isStacked: stacked,
    isPercentage: percentage,
  );
}

const _size = Size(100, 100);

/// The chart's arithmetic, tested away from the canvas.
void main() {
  group('StatChartGeometry', () {
    test('scales a series between zero and its highest value', () {
      final geometry = StatChartGeometry.of(
        _graph(
          series: [
            [0, 50, 100],
          ],
        ),
        _size,
      );

      expect(geometry.minY, 0);
      expect(geometry.maxY, 100);
      expect(geometry.yFor(100), 0);
      expect(geometry.yFor(0), 100);
      expect(geometry.yFor(50), 50);
    });

    // Without a zero baseline, a small change would fill the whole chart.
    test('the axis starts at zero even when no value is near it', () {
      final geometry = StatChartGeometry.of(
        _graph(
          series: [
            [900, 950, 1000],
          ],
        ),
        _size,
      );

      expect(geometry.minY, 0);
      expect(geometry.yFor(1000), 0);
    });

    test('opens downwards for a series that goes negative', () {
      final geometry = StatChartGeometry.of(
        _graph(
          series: [
            [-20, 0, 40],
          ],
        ),
        _size,
      );

      expect(geometry.minY, -20);
      expect(geometry.maxY, 40);
      expect(geometry.yFor(-20), 100);
    });

    test('a flat series does not divide by a zero range', () {
      final geometry = StatChartGeometry.of(
        _graph(
          series: [
            [7, 7, 7],
          ],
        ),
        _size,
      );

      expect(geometry.maxY, greaterThan(geometry.minY));
      expect(geometry.yFor(7).isFinite, isTrue);
      expect(geometry.pointAt(0, 1).dy.isFinite, isTrue);
    });

    // Layout divides by `count - 1`; a channel one day old has one sample.
    test('a single-sample graph is centred rather than infinite', () {
      final geometry = StatChartGeometry.of(
        _graph(
          series: [
            [5],
          ],
        ),
        _size,
      );

      expect(geometry.xAt(0), 50);
      expect(geometry.pointAt(0, 0).dx, 50);
    });

    test('the first and last points sit on the edges of the box', () {
      final geometry = StatChartGeometry.of(
        _graph(
          series: [
            [1, 2, 3],
          ],
        ),
        _size,
      );

      expect(geometry.xAt(0), 0);
      expect(geometry.xAt(2), 100);
    });

    group('stacking', () {
      test(
        'plots running totals and scales the axis to the tallest column',
        () {
          final geometry = StatChartGeometry.of(
            _graph(
              series: [
                [10, 10],
                [30, 5],
              ],
              stacked: true,
            ),
            _size,
          );

          expect(geometry.plotted[0], [10, 10]);
          expect(geometry.plotted[1], [40, 15]);
          expect(geometry.maxY, 40);
        },
      );

      test('each segment starts where the one below it ended', () {
        final geometry = StatChartGeometry.of(
          _graph(
            series: [
              [10],
              [30],
            ],
            shape: StatGraphShape.bar,
            stacked: true,
          ),
          _size,
        );

        expect(geometry.baselines[0].single, 0);
        expect(geometry.baselines[1].single, 10);

        final lower = geometry.barRect(0, 0);
        final upper = geometry.barRect(1, 0);
        expect(lower.top, upper.bottom);
      });

      test('an unstacked graph has no baselines', () {
        final geometry = StatChartGeometry.of(
          _graph(
            series: [
              [10, 10],
              [30, 5],
            ],
          ),
          _size,
        );

        expect(geometry.plotted[1], [30, 5]);
        expect(geometry.baselines[1], [0, 0]);
        expect(geometry.maxY, 30);
      });
    });

    group('percentage graphs', () {
      test('are drawn as shares of their own column, not as counts', () {
        final geometry = StatChartGeometry.of(
          _graph(
            series: [
              [1, 30],
              [3, 10],
            ],
            percentage: true,
          ),
          _size,
        );

        // 1 of 4 is a quarter, whatever the second column's counts are.
        expect(geometry.plotted[0].first, closeTo(25, 1e-9));
        expect(geometry.plotted[1].first, closeTo(100, 1e-9));
        expect(geometry.maxY, 100);
      });

      test('a column of nothing does not divide by zero', () {
        final geometry = StatChartGeometry.of(
          _graph(
            series: [
              [0],
              [0],
            ],
            percentage: true,
          ),
          _size,
        );

        expect(geometry.plotted[0].single, 0);
        expect(geometry.plotted[1].single, 0);
      });
    });

    group('bars', () {
      test('divide the width into equal slots', () {
        final geometry = StatChartGeometry.of(
          _graph(
            series: [
              [1, 2, 3, 4],
            ],
            shape: StatGraphShape.bar,
          ),
          _size,
        );

        expect(geometry.barRect(0, 0).left, 0);
        expect(geometry.barRect(0, 3).right, 100);
        expect(geometry.barRect(0, 1).width, 25);
      });

      test('a gap narrows the bar without moving the slot', () {
        final geometry = StatChartGeometry.of(
          _graph(
            series: [
              [1, 2],
            ],
            shape: StatGraphShape.bar,
          ),
          _size,
        );

        final bar = geometry.barRect(0, 0, gap: 10);
        expect(bar.left, 5);
        expect(bar.width, 40);
      });
    });

    group('axis labels', () {
      test('are thinned to four on a long axis', () {
        final geometry = StatChartGeometry.of(
          _graph(series: [List.filled(90, 1)]),
          _size,
        );

        final indices = geometry.labelIndices();
        expect(indices.length, 4);
        expect(indices.first, 0);
        expect(indices.last, 89);
      });

      test('a short axis is labelled in full', () {
        final geometry = StatChartGeometry.of(
          _graph(
            series: [
              [1, 2],
            ],
          ),
          _size,
        );

        expect(geometry.labelIndices(), [0, 1]);
      });

      test('gridlines span the axis from bottom to top', () {
        final geometry = StatChartGeometry.of(
          _graph(
            series: [
              [0, 100],
            ],
          ),
          _size,
        );

        final values = geometry.gridValues();
        expect(values.first, 0);
        expect(values.last, 100);
        expect(values.length, 5);
      });
    });
  });

  // Telegram sends every statistics axis as millisecond timestamps, even the
  // hour-of-day one, so the label unit comes from the span.
  group('TimeUtils.axisLabel', () {
    final at = DateTime(2026, 6, 7, 14, 30);

    test('names the hour on an axis that covers a day', () {
      expect(TimeUtils.axisLabel(at, const Duration(hours: 23)), '14:30');
    });

    test('names the date on an axis that covers months', () {
      expect(
        TimeUtils.axisLabel(
          at,
          const Duration(days: 90),
          now: DateTime(2026, 9, 7),
        ),
        'Jun 7',
      );
    });

    test('carries the year once the axis leaves this one', () {
      expect(
        TimeUtils.axisLabel(
          at,
          const Duration(days: 400),
          now: DateTime(2026, 9, 7),
        ),
        'Jun 2026',
      );
    });

    test('a date in another year says so', () {
      expect(
        TimeUtils.shortDate(DateTime(2024, 6, 7), now: DateTime(2026, 9, 7)),
        'Jun 7, 2024',
      );
    });
  });
}
