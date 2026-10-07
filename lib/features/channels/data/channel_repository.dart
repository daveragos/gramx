import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/core/telegram/telegram_ids.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

class ChannelRepository {
  final TdlibService _tdlib;
  final ChatCache _chatCache;

  /// Cap on `GetSupergroup` calls while building the channel list. The cache
  /// normally has every supergroup; this bounds the cost of any it missed.
  static const int _maxSupergroupLookups = 15;

  ChannelRepository(this._tdlib, this._chatCache);

  /// Telegram's recommended channels, minus any already followed. One
  /// request: TDLib pushes `updateNewChat` before naming a chat, so
  /// [ChatCache] already has every result.
  Future<List<Channel>> recommendedChannels() async {
    try {
      final res = await _tdlib.sendRequest(const td.GetRecommendedChats());
      if (res is! td.Chats) return const [];

      final channels = <Channel>[];
      for (final chatId in res.chatIds) {
        final chat = _chatCache.chat(chatId);
        if (chat == null) continue;

        final supergroupId = TelegramIds.supergroupId(chatId);
        final supergroup = supergroupId == null
            ? null
            : _chatCache.supergroup(supergroupId);

        final channel = TdlibMappers.mapChatToChannel(
          chat,
          supergroup: supergroup,
        );
        if (channel.isJoined) continue;
        channels.add(channel);
      }
      return channels;
    } catch (e) {
      debugPrint('[ChannelRepo] recommendations unavailable: $e');
      return const [];
    }
  }

  /// The most similar channels listed, each with full info for its
  /// description. Telegram itself sends no more than a handful.
  static const int maxSimilarChannels = 20;

  /// The channels Telegram finds like [chatId], as its own apps list them
  /// under a channel, with descriptions. TDLib pushes each chat before
  /// naming it, so only the descriptions are asked for.
  Future<List<Channel>> similarChannels(int chatId) async {
    try {
      final res = await _tdlib.sendRequest(
        td.GetChatSimilarChats(chatId: chatId),
      );
      if (res is! td.Chats) return const [];

      final channels = <Channel>[];
      for (final similarId in res.chatIds.take(maxSimilarChannels)) {
        final chat = _chatCache.chat(similarId) ?? await _fetchChat(similarId);
        if (chat == null) continue;
        final type = chat.type;
        if (type is! td.ChatTypeSupergroup) continue;

        var supergroup = _chatCache.supergroupForChat(chat);
        td.SupergroupFullInfo? fullInfo;
        try {
          if (supergroup == null) {
            final sg = await _tdlib.sendRequest(
              td.GetSupergroup(supergroupId: type.supergroupId),
            );
            if (sg is td.Supergroup) supergroup = sg;
          }
          final info = await _tdlib.sendRequest(
            td.GetSupergroupFullInfo(supergroupId: type.supergroupId),
          );
          if (info is td.SupergroupFullInfo) fullInfo = info;
        } catch (_) {
          // The row still shows, without a description.
        }

        channels.add(
          TdlibMappers.mapChatToChannel(
            chat,
            supergroup: supergroup,
            fullInfo: fullInfo,
          ),
        );
      }
      return channels;
    } catch (e) {
      debugPrint('[ChannelRepo] similar channels unavailable: $e');
      return const [];
    }
  }

  /// How many similar channels Telegram has for [chatId], 0 when none or
  /// unknown.
  Future<int> similarChannelCount(int chatId) async {
    try {
      final res = await _tdlib.sendRequest(
        td.GetChatSimilarChatCount(chatId: chatId, returnLocal: false),
      );
      return res is td.Count ? res.count : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Tells Telegram a similar channel was opened from [chatId]'s list, as
  /// its own apps do.
  Future<void> openedSimilarChannel(int chatId, int openedChatId) async {
    try {
      await _tdlib.sendRequest(
        td.OpenChatSimilarChat(chatId: chatId, openedChatId: openedChatId),
      );
    } catch (_) {}
  }

  /// Every subscribed broadcast channel, most recently active first, read
  /// from [ChatCache]. Full info is networked, so the profile fetches it.
  Future<List<Channel>> getSubscribedChannels() async {
    await _chatCache.ensureLoaded();
    final channelChats = _chatCache.channels;
    if (channelChats.isEmpty) return [];

    var lookups = 0;
    final channels = <Channel>[];

    for (final chat in channelChats) {
      var supergroup = _chatCache.supergroupForChat(chat);

      if (supergroup == null && lookups < _maxSupergroupLookups) {
        final type = chat.type;
        if (type is td.ChatTypeSupergroup) {
          lookups++;
          try {
            final res = await _tdlib.sendRequest(
              td.GetSupergroup(supergroupId: type.supergroupId),
            );
            if (res is td.Supergroup) supergroup = res;
          } catch (_) {
            // The row renders without member count or username.
          }
        }
      }

      channels.add(TdlibMappers.mapChatToChannel(chat, supergroup: supergroup));
    }

    return channels;
  }

  /// A channel by its TDLib chat id.
  Future<Channel?> getChannelByChatId(int chatId) async {
    return getChannelByIdentifier(chatId.toString());
  }

  /// A channel by chat id, supergroup id, username or link.
  Future<Channel?> getChannelByIdentifier(String identifier) async {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) return null;

    td.Chat? chatObj;

    // A numeric id: the cache first, then GetChat.
    final rawId = int.tryParse(trimmed);
    if (rawId != null) {
      chatObj = _chatCache.chat(rawId);
    }
    if (rawId != null && chatObj == null) {
      try {
        final res = await _tdlib.sendRequest(td.GetChat(chatId: rawId));
        if (res is td.Chat) {
          chatObj = res;
        }
      } catch (_) {}

      // GetChat can fail for a channel the user hasn't joined.
      if (chatObj == null) {
        final supergroupId = _extractSupergroupId(rawId);
        if (supergroupId != null) {
          try {
            final res = await _tdlib.sendRequest(
              td.CreateSupergroupChat(supergroupId: supergroupId, force: false),
            );
            if (res is td.Chat) {
              chatObj = res;
            }
          } catch (_) {}
        }
      }
    }

    // Not numeric, or not found by id: resolve it as a username or link.
    if (chatObj == null) {
      final cleanUsername = trimmed
          .replaceAll(RegExp(r'^(https?://)?(t\.me/)?@?'), '')
          .split('/')
          .first
          .trim();

      if (cleanUsername.isNotEmpty) {
        try {
          final res = await _tdlib.sendRequest(
            td.SearchPublicChat(username: cleanUsername),
          );
          if (res is td.Chat) {
            chatObj = res;
          }
        } catch (_) {}
      }
    }

    if (chatObj != null) {
      final type = chatObj.type;
      if (type is td.ChatTypeSupergroup) {
        td.Supergroup? supergroup;
        td.SupergroupFullInfo? fullInfo;

        try {
          final sgObj = await _tdlib.sendRequest(
            td.GetSupergroup(supergroupId: type.supergroupId),
          );
          if (sgObj is td.Supergroup) supergroup = sgObj;

          final fiObj = await _tdlib.sendRequest(
            td.GetSupergroupFullInfo(supergroupId: type.supergroupId),
          );
          if (fiObj is td.SupergroupFullInfo) fullInfo = fiObj;
        } catch (_) {}

        return TdlibMappers.mapChatToChannel(
          chatObj,
          supergroup: supergroup,
          fullInfo: fullInfo,
        );
      }
    }

    return null;
  }

  /// Joins a channel.
  Future<bool> joinChannel(int chatId) async {
    try {
      final res = await _tdlib.sendRequest(td.JoinChat(chatId: chatId));
      return res is td.Ok;
    } catch (_) {
      return false;
    }
  }

  /// Leaves a channel.
  Future<bool> leaveChannel(int chatId) async {
    try {
      final res = await _tdlib.sendRequest(td.LeaveChat(chatId: chatId));
      return res is td.Ok;
    } catch (_) {
      return false;
    }
  }

  static int? _extractSupergroupId(int rawId) {
    if (rawId > 0) return rawId;
    final str = rawId.toString();
    if (str.startsWith('-100')) {
      return int.tryParse(str.substring(4));
    }
    return null;
  }

  /// The most results a channel search returns. Rows skip full info, which
  /// is networked, and leave it to the profile screen.
  static const int maxSearchResults = 20;

  Future<List<Channel>> searchPublicChannels(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final res = await _tdlib.sendRequest(td.SearchPublicChats(query: query));
      if (res is! td.Chats) return [];

      final channels = <Channel>[];
      for (final chatId in res.chatIds.take(maxSearchResults)) {
        final chat = _chatCache.chat(chatId) ?? await _fetchChat(chatId);
        if (chat == null) continue;

        final type = chat.type;
        if (type is! td.ChatTypeSupergroup || !type.isChannel) continue;

        var supergroup = _chatCache.supergroupForChat(chat);
        if (supergroup == null) {
          try {
            final sg = await _tdlib.sendRequest(
              td.GetSupergroup(supergroupId: type.supergroupId),
            );
            if (sg is td.Supergroup) supergroup = sg;
          } catch (_) {
            // Row still renders, just without the member count.
          }
        }

        channels.add(
          TdlibMappers.mapChatToChannel(chat, supergroup: supergroup),
        );
      }
      return channels;
    } catch (_) {}
    return [];
  }

  Future<td.Chat?> _fetchChat(int chatId) async {
    try {
      final res = await _tdlib.sendRequest(td.GetChat(chatId: chatId));
      return res is td.Chat ? res : null;
    } catch (_) {
      return null;
    }
  }
}

final channelRepositoryProvider = Provider<ChannelRepository>((ref) {
  return ChannelRepository(
    ref.watch(tdlibServiceProvider),
    ref.watch(chatCacheProvider),
  );
});
