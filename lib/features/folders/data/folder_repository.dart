import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

class FolderRepository {
  final TdlibService _tdlib;
  List<td.ChatFolderInfo> _cachedFolders = [];

  FolderRepository(this._tdlib) {
    _tdlib.updatesStream.listen((update) {
      if (update is td.UpdateChatFolders) {
        _cachedFolders = update.chatFolders;
      }
    });
  }

  Future<List<td.ChatFolderInfo>> getFolders() async {
    return _cachedFolders;
  }

  Future<List<int>> getFolderChannelChatIds(int folderId) async {
    try {
      await _tdlib.sendRequest(td.LoadChats(chatList: td.ChatListFolder(chatFolderId: folderId), limit: 200));
    } catch (_) {}
    
    final chatsObj = await _tdlib.sendRequest(td.GetChats(chatList: td.ChatListFolder(chatFolderId: folderId), limit: 200));
    if (chatsObj is td.Chats) {
      final channelChatIds = <int>[];
      for (final chatId in chatsObj.chatIds) {
        final chatObj = await _tdlib.sendRequest(td.GetChat(chatId: chatId));
        if (chatObj is td.Chat && chatObj.type is td.ChatTypeSupergroup && (chatObj.type as td.ChatTypeSupergroup).isChannel) {
          channelChatIds.add(chatId);
        }
      }
      return channelChatIds;
    }
    return [];
  }
}

final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  return FolderRepository(ref.watch(tdlibServiceProvider));
});
