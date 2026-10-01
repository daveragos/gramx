import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/stats/data/stat_graph_loads.dart';
import 'package:gramx/features/stats/data/stats_repository.dart';
import 'package:gramx/features/stats/domain/channel_stats.dart';
import 'package:gramx/features/stats/domain/post_stats.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// A statistics request key. Includes brightness because Telegram picks graph
/// colours for the given theme, so a theme switch refetches.
typedef ChannelStatsRequest = ({int chatId, bool isDark});

typedef PostStatsRequest = ({int chatId, int messageId, bool isDark});

typedef PostRef = ({int chatId, int messageId});

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(
    ref.watch(tdlibServiceProvider),
    ref.watch(chatCacheProvider),
  );
});

/// A channel's statistics, from one `getChatStatistics` on opening the
/// screen. Auto-dispose so reopening the screen fetches fresh figures.
final channelStatsProvider =
    FutureProvider.family<ChannelStats?, ChannelStatsRequest>((
      ref,
      request,
    ) async {
      final repo = ref.watch(statsRepositoryProvider);
      return repo.channelStats(chatId: request.chatId, isDark: request.isDark);
    }, isAutoDispose: true);

/// The text of the Content rows. Only the Content tab watches it, so the
/// local reads happen only when that tab is opened.
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

/// Whether this post has statistics to open. Asked only from the post's own
/// screen, never per card in a list.
final canViewPostStatsProvider = FutureProvider.family<bool, PostRef>((
  ref,
  post,
) async {
  final repo = ref.watch(statsRepositoryProvider);
  return repo.canViewPostStats(chatId: post.chatId, messageId: post.messageId);
}, isAutoDispose: true);

/// The graphs resolved so far for one chat. Each card calls
/// [StatGraphsNotifier.ensureLoaded] as it scrolls into view. Auto-dispose
/// (not a family default in Riverpod 3), so reopening fetches fresh numbers.
final statGraphsProvider =
    NotifierProvider.family<StatGraphsNotifier, StatGraphLoads, int>(
      StatGraphsNotifier.new,
      isAutoDispose: true,
    );

class StatGraphsNotifier extends Notifier<StatGraphLoads> {
  /// The chat these graphs belong to (the family argument).
  final int chatId;

  StatGraphsNotifier(this.chatId);

  @override
  StatGraphLoads build() => const StatGraphLoads();

  /// Resolves [token] unless it is already resolved or in flight. Safe to
  /// call on every visibility change.
  Future<void> ensureLoaded(String token) async {
    if (!state.shouldRequest(token)) return;
    state = state.starting(token);

    final repo = ref.read(statsRepositoryProvider);
    final resolved = await repo.resolveGraph(chatId: chatId, token: token);

    // The screen may have closed, and writing to a disposed notifier throws.
    if (!ref.mounted) return;
    state = state.completed(token, resolved);
  }
}
