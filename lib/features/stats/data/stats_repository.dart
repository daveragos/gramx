import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/core/telegram/telegram_ids.dart';
import 'package:gramx/features/stats/data/stats_mapper.dart';
import 'package:gramx/features/stats/domain/channel_stats.dart';
import 'package:gramx/features/stats/domain/post_stats.dart';
import 'package:gramx/features/stats/domain/stat_graph.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// Telegram's own statistics for a channel the reader administers.
///
/// **What this costs, and why it is allowed.** Every call here is networked and
/// every one of them is a tap: opening the Analytics screen, scrolling a chart
/// into view, opening one post's numbers. That is the on-demand shape
/// `docs/TDLIB.md` permits, and it is deliberately *not* the shape the rest of
/// the app avoids — nothing here runs on a timer, in a loop over chats, or
/// while the screen that would show it is closed.
///
/// The one place that could have become a fan-out is the graphs: TDLib answers
/// `getChatStatistics` with most of them unresolved, and resolving all ten on
/// open would be ten requests for charts nobody has scrolled to yet — the same
/// fault as fetching a channel's four tabs eagerly. So [resolveGraph] is called
/// one chart at a time, from visibility, and never from the reply.
class StatsRepository {
  final TdlibService _tdlib;
  final ChatCache _chatCache;

  /// Public forwards asked for in one page. Telegram pages this; gramX shows
  /// the first page and says how many there are in total, because a reader
  /// looking at one post's numbers wants the shape of the sharing, not a
  /// directory of it.
  static const int publicSharesLimit = 20;

  StatsRepository(this._tdlib, this._chatCache);

  /// A channel's statistics, or null if Telegram will not produce them.
  ///
  /// [isDark] is not cosmetic. Telegram picks the **series colours** for the
  /// graphs it returns, and it picks them for the theme it is told about — ask
  /// with the wrong one and a channel's growth line comes back in a colour
  /// chosen to sit on the opposite background. It is why the provider behind
  /// this is keyed on brightness rather than on the chat alone.
  Future<ChannelStats?> channelStats({
    required int chatId,
    required bool isDark,
  }) async {
    final res = await _tdlib.sendRequest(
      td.GetChatStatistics(chatId: chatId, isDark: isDark),
    );
    if (res is! td.ChatStatistics) return null;
    return StatsMapper.mapChannel(res);
  }

  /// Resolves one graph Telegram sent as a token.
  ///
  /// `x: 0` asks for the whole period rather than a zoomed slice — the zoom is
  /// a second interaction Telegram's own clients offer and gramX does not, and
  /// passing a real x here would silently return one day of a three-month
  /// chart.
  Future<StatGraphSource> resolveGraph({
    required int chatId,
    required String token,
  }) async {
    try {
      final res = await _tdlib.sendRequest(
        td.GetStatisticalGraph(chatId: chatId, token: token, x: 0),
      );
      if (res is! td.StatisticalGraph) return const StatGraphMissing();
      return StatsMapper.graph(res);
    } catch (e) {
      debugPrint('[StatsRepo] graph $token failed: $e');
      return StatGraphMissing(e.toString());
    }
  }

  /// The words behind the Content rows, keyed by message id.
  ///
  /// **`getMessageLocally`, once per id, and deliberately not one batched
  /// `getMessages`.** The batch is a single request and looks like the obvious
  /// win, but TDLib answers a message it cannot find with `null` *in the
  /// array*, and `handy_tdlib` decodes the array with a non-nullable cast — so
  /// one deleted post, which statistics still counts and still lists, throws
  /// away the whole page of excerpts. These are local reads: off the request
  /// budget, exempt from the flood gate (`TdlibService._isLocalOnlyRequest`),
  /// and a miss costs exactly the one row it belongs to.
  Future<Map<int, PostExcerpt>> postExcerpts({
    required int chatId,
    required List<int> messageIds,
  }) async {
    final excerpts = <int, PostExcerpt>{};

    for (final messageId in messageIds) {
      try {
        final res = await _tdlib.sendRequest(
          td.GetMessageLocally(chatId: chatId, messageId: messageId),
        );
        if (res is! td.Message) continue;
        excerpts[messageId] = PostExcerpt(
          messageId: messageId,
          text: TdlibMappers.excerptOf(res),
          publishedAt: DateTime.fromMillisecondsSinceEpoch(res.date * 1000),
        );
      } catch (_) {
        // Not in the local database. The row still has its counts.
      }
    }

    return excerpts;
  }

  /// One post's statistics, or null if Telegram declines them.
  Future<PostStats?> postStats({
    required int chatId,
    required int messageId,
    required bool isDark,
  }) async {
    final res = await _tdlib.sendRequest(
      td.GetMessageStatistics(
        chatId: chatId,
        messageId: messageId,
        isDark: isDark,
      ),
    );
    if (res is! td.MessageStatistics) return null;
    return StatsMapper.mapMessage(res);
  }

  /// Whether this post has statistics to open at all.
  ///
  /// Asked per post, from the screen showing that post — the same rule as
  /// `ChatsRepository.messageActions`, and the same request, which TDLib
  /// documents as offline. Working the answer out locally was the alternative
  /// ("is this my channel, is it big enough, is the post recent enough") and it
  /// produces a control that opens onto an error.
  ///
  /// A failed lookup answers **no**: an absent entry point is a smaller fault
  /// than one that leads nowhere.
  Future<bool> canViewPostStats({
    required int chatId,
    required int messageId,
  }) async {
    try {
      final res = await _tdlib.sendRequest(
        td.GetMessageProperties(chatId: chatId, messageId: messageId),
      );
      if (res is! td.MessageProperties) return false;
      return res.canGetStatistics;
    } catch (e) {
      debugPrint('[StatsRepo] properties for $chatId/$messageId failed: $e');
      return false;
    }
  }

  /// The public channels that forwarded this post.
  ///
  /// **The names are free.** TDLib pushes `updateNewChat` for a chat before it
  /// names one in a reply, so `ChatCache` already holds every channel in this
  /// list — the same property `getRecommendedChats` leans on, and what keeps
  /// this to one request instead of one per row. A chat the cache somehow does
  /// not have is dropped rather than fetched: a row per miss is exactly the
  /// per-chat fan-out the rules forbid, and this is a list you glance at.
  Future<List<PublicShare>> publicShares({
    required int chatId,
    required int messageId,
    int limit = publicSharesLimit,
  }) async {
    try {
      final res = await _tdlib.sendRequest(
        td.GetMessagePublicForwards(
          chatId: chatId,
          messageId: messageId,
          offset: '',
          limit: limit,
        ),
      );
      if (res is! td.PublicForwards) return const [];

      final shares = <PublicShare>[];
      for (final forward in res.forwards) {
        // A story forward has no post to open and no screen in gramX to open
        // it on. Dropped for the same reason story statistics are.
        if (forward is! td.PublicForwardMessage) continue;

        final message = forward.message;
        final chat = _chatCache.chat(message.chatId);
        if (chat == null) continue;

        final supergroupId = TelegramIds.supergroupId(message.chatId);
        final supergroup = supergroupId == null
            ? null
            : _chatCache.supergroup(supergroupId);
        final photo = chat.photo?.small;

        shares.add(
          PublicShare(
            chatId: message.chatId,
            messageId: message.id,
            title: chat.title,
            username: supergroup?.usernames?.activeUsernames.firstOrNull,
            avatarPath: photo?.local.path.isNotEmpty == true
                ? photo!.local.path
                : null,
            avatarFileId: photo?.id,
            isVerified: supergroup?.isVerified ?? false,
            viewCount: message.interactionInfo?.viewCount ?? 0,
          ),
        );
      }

      shares.sort((a, b) => b.viewCount.compareTo(a.viewCount));
      return shares;
    } catch (e) {
      debugPrint('[StatsRepo] public forwards for $messageId failed: $e');
      return const [];
    }
  }
}
