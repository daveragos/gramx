import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

class FolderRepository {
  final TdlibService _tdlib;
  final ChatCache _chatCache;

  List<td.ChatFolderInfo> _cachedFolders = [];

  /// Ceiling on chats read from one folder. Folders are small in practice; this
  /// only stops a pathological one from becoming a long loop.
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

  /// The channel chat ids inside a folder.
  ///
  /// Resolves each id through [ChatCache] rather than calling `GetChat` per
  /// chat. That fan-out ran once per folder tab, so a handful of folders
  /// multiplied straight into the request budget.
  Future<List<int>> getFolderChannelChatIds(int folderId) async {
    // The cache is what resolves each id below, and it is filled by the update
    // stream — so this has to wait for it. Reading too early returned nothing,
    // and a FutureProvider caches that nothing forever: every folder looked
    // empty and every folder tab disappeared.
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
        // A cache miss means "we don't know", not "not a channel". Keeping the
        // id errs towards showing the folder, which is the recoverable mistake.
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
}

final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  return FolderRepository(
    ref.watch(tdlibServiceProvider),
    ref.watch(chatCacheProvider),
  );
});
