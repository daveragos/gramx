import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/database/database_provider.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

class FeedRepository {
  final TdlibService _tdlib;
  final AppDatabase _db;

  FeedRepository(this._tdlib, this._db);

  /// Fetch feed posts from all subscribed channels.
  /// Gets recent messages from TDLib's cache, groups albums, marks bookmarks.
  Future<List<Post>> fetchFeedPosts() async {
    // 1. Get all chats from TDLib
    final chatsObj = await _tdlib.sendRequest(const td.GetChats(chatList: td.ChatListMain(), limit: 100));
    if (chatsObj is! td.Chats) return [];
    
    // 2. For each channel chat, get recent messages
    final allMessages = <td.Message>[];
    final chatMap = <int, td.Chat>{};
    for (final chatId in chatsObj.chatIds) {
      final chatObj = await _tdlib.sendRequest(td.GetChat(chatId: chatId));
      if (chatObj is td.Chat) {
        final type = chatObj.type;
        if (type is td.ChatTypeSupergroup && type.isChannel) {
          chatMap[chatId] = chatObj;
          final history = await _tdlib.sendRequest(td.GetChatHistory(
            chatId: chatId, fromMessageId: 0, offset: 0, limit: 30, onlyLocal: false,
          ));
          if (history is td.Messages) {
            allMessages.addAll(history.messages);
          }
        }
      }
    }
    
    // 3. Get bookmark keys
    final bookmarks = await _db.select(_db.bookmarkEntries).get();
    final bookmarkKeys = bookmarks.map((b) => '${b.chatId}_${b.messageId}').toSet();
    
    // 4. Group albums and map to Posts
    // Group messages by chatId first, then merge albums within each chat
    final postsByChatId = <int, List<Post>>{};
    final messagesByChatId = <int, List<td.Message>>{};
    for (final msg in allMessages) {
      messagesByChatId.putIfAbsent(msg.chatId, () => []).add(msg);
    }
    for (final entry in messagesByChatId.entries) {
      final chat = chatMap[entry.key];
      if (chat != null) {
        postsByChatId[entry.key] = TdlibMappers.mergeAlbumMessages(
          entry.value, chat, bookmarkedKeys: bookmarkKeys,
        );
      }
    }
    
    // 5. Flatten, sort by date desc
    final allPosts = postsByChatId.values.expand((e) => e).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    
    return allPosts;
  }

  /// Fetch posts for a single channel.
  Future<List<Post>> fetchChannelPosts(int chatId, {int fromMessageId = 0, int limit = 50}) async {
    final chatObj = await _tdlib.sendRequest(td.GetChat(chatId: chatId));
    if (chatObj is! td.Chat) return [];

    final history = await _tdlib.sendRequest(td.GetChatHistory(
      chatId: chatId, fromMessageId: fromMessageId, offset: 0, limit: limit, onlyLocal: false,
    ));
    if (history is! td.Messages) return [];

    final bookmarks = await _db.select(_db.bookmarkEntries).get();
    final bookmarkKeys = bookmarks.map((b) => '${b.chatId}_${b.messageId}').toSet();

    return TdlibMappers.mergeAlbumMessages(
      history.messages, chatObj, bookmarkedKeys: bookmarkKeys,
    );
  }

  /// Toggle bookmark using chatId + messageId.
  Future<void> toggleBookmark(int chatId, int messageId) async {
    final existing = await (_db.select(_db.bookmarkEntries)
          ..where((b) => b.chatId.equals(chatId) & b.messageId.equals(messageId)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.delete(_db.bookmarkEntries)
            ..where((b) => b.chatId.equals(chatId) & b.messageId.equals(messageId)))
          .go();
    } else {
      final accounts = await (_db.select(_db.accounts)..where((a) => a.isActive.equals(true))).get();
      final accountId = accounts.isNotEmpty ? accounts.first.id : 1;
      
      await _db.into(_db.bookmarkEntries).insert(BookmarkEntriesCompanion.insert(
        accountId: accountId,
        chatId: chatId,
        messageId: messageId,
      ));
    }
  }

  /// Check if a post is bookmarked.
  Future<bool> isBookmarked(int chatId, int messageId) async {
    final existing = await (_db.select(_db.bookmarkEntries)
          ..where((b) => b.chatId.equals(chatId) & b.messageId.equals(messageId)))
        .getSingleOrNull();
    return existing != null;
  }

  /// Mark post as read via TDLib.
  Future<void> markPostAsRead(int chatId, int messageId) async {
    await _tdlib.sendRequest(td.ViewMessages(
      chatId: chatId,
      messageIds: [messageId],
      forceRead: true,
    ));
  }

  /// Get available reactions for a chat
  Future<List<String>> getAvailableReactions(int chatId) async {
    final chatObj = await _tdlib.sendRequest(td.GetChat(chatId: chatId));
    if (chatObj is td.Chat) {
      final available = chatObj.availableReactions;
      if (available is td.ChatAvailableReactionsSome) {
        final emojis = <String>[];
        for (final r in available.reactions) {
          if (r is td.ReactionTypeEmoji) {
            emojis.add(r.emoji);
          }
        }
        if (emojis.isNotEmpty) return emojis;
      }
    }
    // Default fallback emojis if not specifically restricted
    return ['👍', '❤️', '🔥', '🥰', '👏'];
  }
}

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(ref.watch(tdlibServiceProvider), ref.watch(databaseProvider));
});
