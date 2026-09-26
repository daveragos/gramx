import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/stats/data/stat_graph_loads.dart';
import 'package:gramx/features/stats/data/stats_repository.dart';
import 'package:gramx/features/stats/domain/channel_stats.dart';
import 'package:gramx/features/stats/domain/post_stats.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// A statistics request, keyed the way it is cached.
///
/// **Brightness is part of the key, not a detail.** Telegram picks the graph
/// colours for the theme it is told about (`getChatStatistics(isDark:)`), so a
/// reader who switches themes with the screen open is looking at a chart drawn
/// for the other one. Keying on it means the switch re-asks rather than
/// re-tinting.
typedef ChannelStatsRequest = ({int chatId, bool isDark});

typedef PostStatsRequest = ({int chatId, int messageId, bool isDark});

typedef PostRef = ({int chatId, int messageId});

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(
    ref.watch(tdlibServiceProvider),
    ref.watch(chatCacheProvider),
  );
});

/// A channel's statistics. One `getChatStatistics`, on opening the screen.
///
/// Auto-dispose, explicitly: a `.family` is **not** in Riverpod 3,
/// and statistics held for the rest of the session
/// would show yesterday's figures to somebody who reopened the screen to see
/// today's. Held alive by the screen watching it, and only by that.
final channelStatsProvider =
    FutureProvider.family<ChannelStats?, ChannelStatsRequest>((
      ref,
      request,
    ) async {
      final repo = ref.watch(statsRepositoryProvider);
      return repo.channelStats(chatId: request.chatId, isDark: request.isDark);
    }, isAutoDispose: true);

/// The words behind the Content rows.
///
/// Watched by the Content tab and by nothing else, which is what makes it
/// lazy: reading the list is what issues the reads, so a reader who never
/// leaves Overview never pays for them. They are local reads either way — see
/// `StatsRepository.postExcerpts`.
final channelStatsExcerptsProvider =
    FutureProvider.family<Map<int, PostExcerpt>, ChannelStatsRequest>((
      ref,
      request,
    ) async {
      final stats = await ref.watch(channelStatsProvider(request).future);
      if (stats == null || stats.recentPosts.isEmpty) return const {};

      final repo = ref.watch(statsRepositoryProvider);
      return repo.postExcerpts(
        chatId: request.chatId,
        messageIds: [for (final post in stats.recentPosts) post.messageId],
      );
    }, isAutoDispose: true);

/// One post's statistics.
final postStatsProvider = FutureProvider.family<PostStats?, PostStatsRequest>((
  ref,
  request,
) async {
  final repo = ref.watch(statsRepositoryProvider);
  return repo.postStats(
    chatId: request.chatId,
    messageId: request.messageId,
    isDark: request.isDark,
  );
}, isAutoDispose: true);

/// The public channels that forwarded a post.
final publicSharesProvider = FutureProvider.family<List<PublicShare>, PostRef>((
  ref,
  post,
) async {
  final repo = ref.watch(statsRepositoryProvider);
  return repo.publicShares(chatId: post.chatId, messageId: post.messageId);
}, isAutoDispose: true);

/// Whether this post has statistics to open.
///
/// One offline `getMessageProperties`, asked by the screen showing the post —
/// the same shape as the message long-press menu, and never per card in a
/// list. See `StatsRepository.canViewPostStats`.
final canViewPostStatsProvider = FutureProvider.family<bool, PostRef>((
  ref,
  post,
) async {
  final repo = ref.watch(statsRepositoryProvider);
  return repo.canViewPostStats(chatId: post.chatId, messageId: post.messageId);
}, isAutoDispose: true);

/// The graphs resolved so far for one chat.
///
/// TDLib answers `getChatStatistics` with most graphs as a token rather than
/// as data, so a screen of ten charts would be ten more requests on open —
/// the same fan-out shape as fetching a channel's four tabs before anybody
/// selects one. Instead each card calls [ensureLoaded] when it first scrolls
/// into view, and this makes sure that costs one request per chart at most.
///
/// Explicitly auto-dispose: `NotifierProvider.family` is **not** by default in
/// Riverpod 3, and holding a chat's charts for
/// the rest of the session would show yesterday's numbers to somebody who
/// reopened the screen to see today's.
final statGraphsProvider =
    NotifierProvider.family<StatGraphsNotifier, StatGraphLoads, int>(
      StatGraphsNotifier.new,
      isAutoDispose: true,
    );

class StatGraphsNotifier extends Notifier<StatGraphLoads> {
  /// The chat these graphs belong to.
  ///
  /// Held on the notifier rather than read from `build`: Riverpod 3 hands a
  /// family's argument to the *constructor*, the same as `ConversationNotifier`.
  final int chatId;

  StatGraphsNotifier(this.chatId);

  @override
  StatGraphLoads build() => const StatGraphLoads();

  /// Resolves [token] unless it is already resolved or on its way.
  ///
  /// Safe to call from a visibility callback, which fires every time a card
  /// crosses the edge of the viewport — the guard is [StatGraphLoads], where
  /// it is tested.
  Future<void> ensureLoaded(String token) async {
    if (!state.shouldRequest(token)) return;
    state = state.starting(token);

    final repo = ref.read(statsRepositoryProvider);
    final resolved = await repo.resolveGraph(chatId: chatId, token: token);

    // The screen can be gone by now; the notifier is auto-dispose and writing
    // to a disposed one throws.
    if (!ref.mounted) return;
    state = state.completed(token, resolved);
  }
}
