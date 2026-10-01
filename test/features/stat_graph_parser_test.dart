import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/stats/data/stat_graph_parser.dart';
import 'package:gramx/features/stats/domain/stat_graph.dart';

import '../support/td_fixtures.dart';

/// `statisticalGraphData.json_data` is an unchecked JSON string, so these
/// tests catch a change in its shape.
void main() {
  group('StatGraphParser', () {
    test('reads the axis, the series, the names and the colours', () {
      final graph = StatGraphParser.parse(
        TdFixtures.chartJson(
          timestamps: [1719792000000, 1719878400000, 1719964800000],
          series: {
            'y0': [10, 20, 30],
            'y1': [1, 2, 3],
          },
          types: {'y0': 'line', 'y1': 'bar'},
          names: {'y0': 'Members', 'y1': 'Left'},
          colors: {'y0': '#4BC7C1', 'y1': 'rgb(255, 0, 0)'},
        ),
      );

      expect(graph, isNotNull);
      expect(graph!.timestamps.length, 3);
      expect(graph.lines.length, 2);
      expect(graph.lines.first.name, 'Members');
      expect(graph.lines.first.shape, StatGraphShape.line);
      expect(graph.lines.first.color, const Color(0xFF4BC7C1));
      expect(graph.lines.last.shape, StatGraphShape.bar);
      expect(graph.lines.last.color, const Color(0xFFFF0000));
      expect(graph.lines.last.values, [1, 2, 3]);
    });

    test('carries the percentage and stacked flags', () {
      final graph = StatGraphParser.parse(
        TdFixtures.chartJson(percentage: true, stacked: true),
      );

      expect(graph!.isPercentage, isTrue);
      expect(graph.isStacked, isTrue);
    });

    test('a series with no name keeps its column key', () {
      final graph = StatGraphParser.parse(
        TdFixtures.chartJson(names: const {}, colors: const {}),
      );

      expect(graph!.lines.single.name, 'y0');
      expect(graph.lines.single.color, isNull);
    });

    test('an unknown shape is drawn as a line rather than dropped', () {
      final graph = StatGraphParser.parse(
        TdFixtures.chartJson(types: const {'y0': 'candlestick'}),
      );

      expect(graph!.lines.single.shape, StatGraphShape.line);
    });

    // Telegram sends null for a day with no data, which reads as zero.
    test('a null sample is zero', () {
      final graph = StatGraphParser.parse(
        jsonEncode({
          'columns': [
            ['x', 1, 2],
            ['y0', null, 5],
          ],
          'types': {'x': 'x', 'y0': 'line'},
        }),
      );

      expect(graph!.lines.single.values, [0, 5]);
    });

    // A longer y column would draw a point at a date that does not exist.
    test('columns of different lengths are cut to the shortest', () {
      final graph = StatGraphParser.parse(
        jsonEncode({
          'columns': [
            ['x', 1, 2, 3],
            ['y0', 10, 20],
          ],
          'types': {'x': 'x', 'y0': 'line'},
        }),
      );

      expect(graph!.timestamps, [1, 2]);
      expect(graph.lines.single.values, [10, 20]);
    });

    test('the x column is found by type, not only by name', () {
      final graph = StatGraphParser.parse(
        jsonEncode({
          'columns': [
            ['t', 1, 2],
            ['y0', 10, 20],
          ],
          'types': {'t': 'x', 'y0': 'line'},
        }),
      );

      expect(graph!.timestamps, [1, 2]);
      expect(graph.lines.single.key, 'y0');
    });

    test('a payload with no types at all still finds x by name', () {
      final graph = StatGraphParser.parse(
        jsonEncode({
          'columns': [
            ['x', 1, 2],
            ['y0', 10, 20],
          ],
        }),
      );

      expect(graph!.timestamps, [1, 2]);
      expect(graph.lines.single.values, [10, 20]);
    });

    group('answers null rather than an empty chart', () {
      // An empty graph would read as a channel with no activity.
      test('for text that is not JSON', () {
        expect(StatGraphParser.parse('not json'), isNull);
      });

      test('for an empty string', () {
        expect(StatGraphParser.parse(''), isNull);
      });

      test('for JSON that is not an object', () {
        expect(StatGraphParser.parse('[1, 2, 3]'), isNull);
      });

      test('for a payload with no columns', () {
        expect(StatGraphParser.parse('{"types":{}}'), isNull);
      });

      test('for a payload with an x axis and no series', () {
        expect(
          StatGraphParser.parse(
            jsonEncode({
              'columns': [
                ['x', 1, 2],
              ],
              'types': {'x': 'x'},
            }),
          ),
          isNull,
        );
      });

      test('for a payload with series and no x axis', () {
        expect(
          StatGraphParser.parse(
            jsonEncode({
              'columns': [
                ['y0', 1, 2],
              ],
              'types': {'y0': 'line'},
            }),
          ),
          isNull,
        );
      });

      test('for an x axis with no samples on it', () {
        expect(
          StatGraphParser.parse(
            jsonEncode({
              'columns': [
                ['x'],
                ['y0'],
              ],
              'types': {'x': 'x', 'y0': 'line'},
            }),
          ),
          isNull,
        );
      });

      test('for a non-numeric timestamp', () {
        expect(
          StatGraphParser.parse(
            jsonEncode({
              'columns': [
                ['x', 'yesterday'],
                ['y0', 1],
              ],
              'types': {'x': 'x', 'y0': 'line'},
            }),
          ),
          isNull,
        );
      });
    });

    group('parseColor', () {
      test('reads the six-digit and three-digit hex forms', () {
        expect(StatGraphParser.parseColor('#4BC7C1'), const Color(0xFF4BC7C1));
        expect(StatGraphParser.parseColor('#F00'), const Color(0xFFFF0000));
      });

      test('reads the rgb() form Telegram\'s older charts use', () {
        expect(
          StatGraphParser.parseColor('rgb(75,199,193)'),
          const Color(0xFF4BC7C1),
        );
      });

      test(
        'answers null for anything else, so the chart keeps its palette',
        () {
          expect(StatGraphParser.parseColor(null), isNull);
          expect(StatGraphParser.parseColor(''), isNull);
          expect(StatGraphParser.parseColor('teal'), isNull);
          expect(StatGraphParser.parseColor('#12345'), isNull);
          expect(StatGraphParser.parseColor('#GGGGGG'), isNull);
        },
      );
    });
  });
}
