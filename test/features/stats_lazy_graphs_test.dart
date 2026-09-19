import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/stats/data/stat_graph_loads.dart';
import 'package:gramx/features/stats/domain/stat_graph.dart';

/// TDLib sends most statistics graphs as a token rather than as data, so the
/// charts on this screen are one request each. These are the rules that keep
/// that to *one* — a card crosses the edge of the viewport every time somebody
/// scrolls, and a request per crossing is aimed at an account with a rate
/// limit.
void main() {
  group('StatGraphLoads', () {
    const graph = StatGraph(timestamps: [1, 2], lines: []);

    test('a token nobody has asked for is requested', () {
      expect(const StatGraphLoads().shouldRequest('a'), isTrue);
    });

    test('a token already on its way is not requested again', () {
      final loads = const StatGraphLoads().starting('a');

      expect(loads.shouldRequest('a'), isFalse);
      expect(loads.isLoading('a'), isTrue);
    });

    test('a token that came back is not requested again', () {
      final loads = const StatGraphLoads()
          .starting('a')
          .completed('a', const StatGraphReady(graph));

      expect(loads.shouldRequest('a'), isFalse);
      expect(loads.isLoading('a'), isFalse);
      expect(loads['a'], isA<StatGraphReady>());
    });

    // "Telegram has no graph for this" is an answer, and asking again on every
    // scroll would spend a request per pass on the one chart that can never
    // fill.
    test('a token that came back unusable is still an answer', () {
      final loads = const StatGraphLoads()
          .starting('a')
          .completed('a', const StatGraphMissing('NOT_ENOUGH_DATA'));

      expect(loads.shouldRequest('a'), isFalse);
      expect(loads['a'], isA<StatGraphMissing>());
    });

    test('one chart resolving does not answer for another', () {
      final loads = const StatGraphLoads()
          .starting('a')
          .completed('a', const StatGraphReady(graph));

      expect(loads.shouldRequest('b'), isTrue);
      expect(loads['b'], isNull);
    });

    test('each step is a new value rather than a mutation', () {
      const initial = StatGraphLoads();
      final started = initial.starting('a');
      final completed = started.completed('a', const StatGraphReady(graph));

      expect(initial.inFlight, isEmpty);
      expect(started.resolved, isEmpty);
      expect(completed.inFlight, isEmpty);
      expect(completed.resolved.keys, ['a']);
    });
  });
}
