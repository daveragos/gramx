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

/// Telegram's statistics for a channel the user administers. Every call is
/// networked and on demand; graphs sent as tokens are resolved one at a time
/// through [resolveGraph] as they scroll into view.
class StatsRepository {
  final TdlibService _tdlib;
  final ChatCache _chatCache;

  /// Public forwards requested. Only the first page is shown.
  static const int publicSharesLimit = 50;

  /// How many pages of reposts to read, so a viral post can't keep it going.
  static const int maxPublicSharePages = 10;

  StatsRepository(this._tdlib, this._chatCache);

  /// A channel's statistics, or null if Telegram will not produce them.
  /// Telegram picks the series colours for the theme given by [isDark].
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

  /// Resolves one graph Telegram sent as a token. `x: 0` asks for the whole
  /// period; any other x returns a zoomed slice of one day.
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

  /// The text of the Content rows, keyed by message id. Uses local reads per
  /// id rather than one `getMessages`, whose reply has `null` for a deleted
  /// post and fails `handy_tdlib`'s non-nullable cast.
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

  /// Whether this post has statistics, from the offline
  /// `getMessageProperties`. A failed lookup answers false.
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

  /// The public channels that reposted this post, most viewed first. Names
  /// come from [ChatCache], which TDLib fills before it replies; a chat not
  /// there yet is asked for, since TDLib already holds it.
  Future<List<PublicShare>> publicShares({
    required int chatId,
    required int messageId,
    int limit = publicSharesLimit,
  }) async {
    try {
      // TDLib picks the page size, so follow the offset to the end.
      final forwards = <td.PublicForward>[];
      var offset = '';
      for (var page = 0; page < maxPublicSharePages; page++) {
        final res = await _tdlib.sendRequest(
          td.GetMessagePublicForwards(
            chatId: chatId,
            messageId: messageId,
            offset: offset,
            limit: limit,
          ),
        );
        if (res is! td.PublicForwards) break;
        forwards.addAll(res.forwards);
        offset = res.nextOffset;
        if (offset.isEmpty || res.forwards.isEmpty) break;
      }

      final shares = <PublicShare>[];
      for (final forward in forwards) {
        // Story forwards are dropped: the app has no screen for stories.
        if (forward is! td.PublicForwardMessage) continue;

        final message = forward.message;
        final chat =
            _chatCache.chat(message.chatId) ??
            await _chatFromTdlib(message.chatId);
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

  Future<td.Chat?> _chatFromTdlib(int chatId) async {
    try {
      final chat = await _tdlib.sendRequest(td.GetChat(chatId: chatId));
      return chat is td.Chat ? chat : null;
    } catch (_) {
      return null;
    }
  }
}
