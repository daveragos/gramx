import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

class FolderRepository {
  final TdlibService _tdlib;
  final ChatCache _chatCache;

  List<td.ChatFolderInfo> _cachedFolders = [];

  /// Upper bound on chats read from one folder.
  static const int _folderChatLimit = 200;

  FolderRepository(this._tdlib, this._chatCache) {
    _tdlib.updatesStream.listen((update) {
      if (update is td.UpdateChatFolders) {
        _cachedFolders = update.chatFolders;
      }
    });
  }

  Future<List<td.ChatFolderInfo>> getFolders() async {
    if (_cachedFolders.isNotEmpty) return _cachedFolders;
    return _tdlib.chatFolders;
  }

  /// The channel chat ids inside a folder, resolved through [ChatCache] to
  /// avoid a `GetChat` per chat.
  Future<List<int>> getFolderChannelChatIds(int folderId) async {
    // Wait for the cache to fill; an early empty result would be cached by
    // the FutureProvider and hide every folder tab.
    await _chatCache.ensureLoaded();

    final chatList = td.ChatListFolder(chatFolderId: folderId);

    try {
      await _tdlib.sendRequest(
        td.LoadChats(chatList: chatList, limit: _folderChatLimit),
      );
    } catch (_) {
      // 404 means the folder is already fully loaded, which is the common case.
    }

    try {
      final res = await _tdlib.sendRequest(
        td.GetChats(chatList: chatList, limit: _folderChatLimit),
      );
      if (res is! td.Chats) return const [];

      final channelIds = <int>[];
      for (final chatId in res.chatIds) {
        final chat = _chatCache.chat(chatId);
        // Keep ids the cache doesn't know, erring towards showing the folder.
        if (chat == null || ChatCacheState.isChannel(chat)) {
          channelIds.add(chatId);
        }
      }
      return channelIds;
    } catch (e) {
      debugPrint('[Folders] Could not read folder $folderId: $e');
      return const [];
    }
  }

  /// Whether folder [folderId] shows only unread chats. Such a folder empties
  /// when everything is read, but its tab should stay.
  Future<bool> folderExcludesRead(int folderId) async {
    try {
      final res = await _tdlib.sendRequest(
        td.GetChatFolder(chatFolderId: folderId),
      );
      return res is td.ChatFolder && res.excludeRead;
    } catch (e) {
      debugPrint('[Folders] Could not read folder filter $folderId: $e');
      return false;
    }
  }
}

final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  return FolderRepository(
    ref.watch(tdlibServiceProvider),
    ref.watch(chatCacheProvider),
  );
});
