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

  /// Ceiling on `GetSupergroup` calls issued while building the channel list.
  ///
  /// The cache normally answers every one of these for free; this only covers
  /// supergroups whose `UpdateSupergroup` we somehow missed, and exists so a
  /// gap in the cache degrades into slightly stale rows rather than a fan-out.
  static const int _maxSupergroupLookups = 15;

  ChannelRepository(this._tdlib, this._chatCache);

  /// Channels Telegram thinks this reader would want, given the ones they
  /// already follow.
  ///
  ///
  /// **One request, and the names are free.** `getRecommendedChats` answers
  /// with chat *ids*, and TDLib always pushes `updateNewChat` for a chat before
  /// it names it in a reply — so `ChatCache` already holds every one of them by
  /// the time this returns. That is the same property the cold start leans on, and it is
  /// what keeps this off the per-chat fan-out the rules forbid: there is no
  /// `GetChat` per result, because there does not need to be.
  ///
  /// Channels the reader is already in are dropped. Telegram usually excludes
  /// them itself, but a suggestion to follow something you follow is the kind
  /// of thing that reads as the app not knowing you.
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

  /// Every subscribed broadcast channel, most recently active first.
  ///
  /// Reads entirely from [ChatCache] — chats and supergroups both arrive on the
  /// update stream, so the common path costs zero requests.
  ///
  /// Deliberately does **not** fetch `SupergroupFullInfo` here. That call is
  /// networked (TDLib caches it for about a minute), it was previously issued
  /// once per channel, and the only field it contributes is the description,
  /// which this list does not show. The channel profile fetches it on demand.
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
            // Fall through — the row renders without member count or username.
          }
        }
      }

      channels.add(TdlibMappers.mapChatToChannel(chat, supergroup: supergroup));
    }

    return channels;
  }

  /// Get a channel by its TDLib chatId.
  Future<Channel?> getChannelByChatId(int chatId) async {
    return getChannelByIdentifier(chatId.toString());
  }

  /// Get a channel by identifier (chatId, supergroupId, username, or link).
  Future<Channel?> getChannelByIdentifier(String identifier) async {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) return null;

    td.Chat? chatObj;

    // 1. If numeric string, check the cache, then try GetChat.
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

      // If GetChat failed (e.g. non-joined channel not in local chat list), try CreateSupergroupChat
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

    // 2. If not numeric or GetChat/CreateSupergroupChat failed, try resolving as username
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

  /// Join a channel by chatId.
  Future<bool> joinChannel(int chatId) async {
    try {
      final res = await _tdlib.sendRequest(td.JoinChat(chatId: chatId));
      return res is td.Ok;
    } catch (_) {
      return false;
    }
  }

  /// Leave a channel by chatId.
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

  /// Public channels matching [query], searched across all of Telegram.
  ///
  /// Capped at [maxSearchResults]. This used to call `getChannelByIdentifier`
  /// per hit, which meant `GetChat` + `GetSupergroup` + `GetSupergroupFullInfo`
  /// for every result — three networked requests each, on a path the user
  /// triggers by typing. Search rows only need the title, avatar, username and
  /// member count, so full info is left for the profile screen.
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
