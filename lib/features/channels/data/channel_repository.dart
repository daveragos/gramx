import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

class ChannelRepository {
  final TdlibService _tdlib;

  ChannelRepository(this._tdlib);

  /// Get all subscribed broadcast channels.
  Future<List<Channel>> getSubscribedChannels() async {
    final chatsObj = await _tdlib.sendRequest(const td.GetChats(chatList: td.ChatListMain(), limit: 200));
    if (chatsObj is! td.Chats) return [];
    
    final channels = <Channel>[];
    for (final chatId in chatsObj.chatIds) {
      final chatObj = await _tdlib.sendRequest(td.GetChat(chatId: chatId));
      if (chatObj is td.Chat) {
        final type = chatObj.type;
        if (type is td.ChatTypeSupergroup && type.isChannel) {
          td.Supergroup? supergroup;
          td.SupergroupFullInfo? fullInfo;
          
          try {
            final sgObj = await _tdlib.sendRequest(td.GetSupergroup(supergroupId: type.supergroupId));
            if (sgObj is td.Supergroup) supergroup = sgObj;
            
            final fiObj = await _tdlib.sendRequest(td.GetSupergroupFullInfo(supergroupId: type.supergroupId));
            if (fiObj is td.SupergroupFullInfo) fullInfo = fiObj;
          } catch (_) {}

          channels.add(TdlibMappers.mapChatToChannel(chatObj, supergroup: supergroup, fullInfo: fullInfo));
        }
      }
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

    // 1. If numeric string, try GetChat first
    final rawId = int.tryParse(trimmed);
    if (rawId != null) {
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
            final res = await _tdlib.sendRequest(td.CreateSupergroupChat(supergroupId: supergroupId, force: false));
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
          final res = await _tdlib.sendRequest(td.SearchPublicChat(username: cleanUsername));
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
          final sgObj = await _tdlib.sendRequest(td.GetSupergroup(supergroupId: type.supergroupId));
          if (sgObj is td.Supergroup) supergroup = sgObj;

          final fiObj = await _tdlib.sendRequest(td.GetSupergroupFullInfo(supergroupId: type.supergroupId));
          if (fiObj is td.SupergroupFullInfo) fullInfo = fiObj;
        } catch (_) {}

        return TdlibMappers.mapChatToChannel(chatObj, supergroup: supergroup, fullInfo: fullInfo);
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

  /// Search global public channels matching query
  Future<List<Channel>> searchPublicChannels(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final res = await _tdlib.sendRequest(td.SearchPublicChats(query: query));
      if (res is td.Chats) {
        final channels = <Channel>[];
        for (final chatId in res.chatIds) {
          final ch = await getChannelByChatId(chatId);
          if (ch != null) channels.add(ch);
        }
        return channels;
      }
    } catch (_) {}
    return [];
  }
}

final channelRepositoryProvider = Provider<ChannelRepository>((ref) {
  return ChannelRepository(ref.watch(tdlibServiceProvider));
});
