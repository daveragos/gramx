import 'package:gramx/features/stats/domain/stat_graph.dart';

/// Which graphs have been asked for, which are in flight, and which came back.
///
/// The pure half of lazy chart loading, split out for the same reason as
/// `ChatCacheState` and `ConversationState`: every rule here has a wrong answer
/// that costs a TDLib request, and a request per rebuild aimed at an account
/// with a rate limit is not a bug that shows up in a screenshot.
///
/// The rules, all of which a test can reach:
///
/// - a token is requested **once**, however many times the chart is scrolled
///   past — a `CustomScrollView` builds and unbuilds a card freely;
/// - a token already in flight is not requested again;
/// - a token that came back — including one that came back unusable — is never
///   re-requested, because "Telegram has no graph for this" is an answer.
class StatGraphLoads {
  final Map<String, StatGraphSource> resolved;
  final Set<String> inFlight;

  const StatGraphLoads({this.resolved = const {}, this.inFlight = const {}});

  /// True when this token needs a `getStatisticalGraph` and does not have one
  /// on the way.
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
