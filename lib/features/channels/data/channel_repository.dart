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

        return TdlibMappers.mapChatToChannel(chatObj, supergroup: supergroup, fullInfo: fullInfo);
      }
    }
    return null;
  }
}

final channelRepositoryProvider = Provider<ChannelRepository>((ref) {
  return ChannelRepository(ref.watch(tdlibServiceProvider));
});
