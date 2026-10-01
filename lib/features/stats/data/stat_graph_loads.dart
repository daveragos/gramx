import 'package:gramx/features/stats/domain/stat_graph.dart';

/// Tracks which lazy stat graphs are in flight and which have resolved.
///
/// Each token is requested at most once, however often its card is rebuilt
/// while scrolling. A resolved token is never re-requested, even when it came
/// back unusable, since that is Telegram's answer.
class StatGraphLoads {
  final Map<String, StatGraphSource> resolved;
  final Set<String> inFlight;

  const StatGraphLoads({this.resolved = const {}, this.inFlight = const {}});

  /// True when this token needs a `getStatisticalGraph` call.
  bool shouldRequest(String token) =>
      !resolved.containsKey(token) && !inFlight.contains(token);

  bool isLoading(String token) => inFlight.contains(token);

  StatGraphSource? operator [](String token) => resolved[token];

  StatGraphLoads starting(String token) =>
      StatGraphLoads(resolved: resolved, inFlight: {...inFlight, token});

  StatGraphLoads completed(String token, StatGraphSource source) =>
      StatGraphLoads(
        resolved: {...resolved, token: source},
        inFlight: {...inFlight}..remove(token),
      );
}
