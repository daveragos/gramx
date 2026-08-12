import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/database/database_provider.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

class FeedRepository {
  final TdlibService _tdlib;
  final AppDatabase _db;
  final SyncService _syncService;

  FeedRepository(this._tdlib, this._db, this._syncService);

  /// Fetch feed posts from all subscribed channels.
  /// Uses parallel fetching and local-first loading for speed.
  Future<List<Post>> fetchFeedPosts() async {
    // 1. Get all chats from TDLib
    final chatsObj = await _tdlib.sendRequest(
      const td.GetChats(chatList: td.ChatListMain(), limit: 100),
    );
    if (chatsObj is! td.Chats) return [];

    // 2. Fetch all chat objects in PARALLEL
    final chatFutures = chatsObj.chatIds.map(
      (chatId) => _tdlib.sendRequest(td.GetChat(chatId: chatId)),
    );
    final chatResults = await Future.wait(chatFutures);

    // 3. Filter to channel chats only and trigger avatar downloads
    final channelChats = <td.Chat>[];
    for (final result in chatResults) {
      if (result is td.Chat) {
        final type = result.type;
        if (type is td.ChatTypeSupergroup && type.isChannel) {
          channelChats.add(result);
          _syncService.downloadChatAvatar(result);
        }
      }
    }

    if (channelChats.isEmpty) return [];

    // 4. Fetch channel histories (local first, then remote for unread posts)
    final historyFutures = channelChats.map((chat) async {
      final localRes = await _tdlib.sendRequest(td.GetChatHistory(
        chatId: chat.id,
        fromMessageId: 0,
        offset: 0,
        limit: 30,
        onlyLocal: true,
      ));
      if (localRes is td.Messages && localRes.messages.length >= 5 && chat.unreadCount == 0) {
        return localRes;
      }
      // Fetch remote history from Telegram server for unread posts
      final remoteRes = await _tdlib.sendRequest(td.GetChatHistory(
        chatId: chat.id,
        fromMessageId: 0,
        offset: 0,
        limit: 30,
        onlyLocal: false,
      ));
      return remoteRes is td.Messages ? remoteRes : localRes;
    });
    final historyResults = await Future.wait(historyFutures);

    // 5. Collect all messages and build chat map
    final allMessages = <td.Message>[];
    final chatMap = <int, td.Chat>{};
    final knownChatTitles = <int, String>{};

    for (int i = 0; i < channelChats.length; i++) {
      chatMap[channelChats[i].id] = channelChats[i];
      knownChatTitles[channelChats[i].id] = channelChats[i].title;
      if (historyResults[i] is td.Messages) {
        allMessages.addAll((historyResults[i] as td.Messages).messages);
      }
    }

    // Resolve forwarded channel names in parallel
    final unresolvedFwdChatIds = <int>{};
    for (final msg in allMessages) {
      final fwd = msg.forwardInfo?.origin;
      if (fwd is td.MessageOriginChannel && !knownChatTitles.containsKey(fwd.chatId)) {
        unresolvedFwdChatIds.add(fwd.chatId);
      } else if (fwd is td.MessageOriginChat && !knownChatTitles.containsKey(fwd.senderChatId)) {
        unresolvedFwdChatIds.add(fwd.senderChatId);
      }
    }

    if (unresolvedFwdChatIds.isNotEmpty) {
      final fwdResults = await Future.wait(
        unresolvedFwdChatIds.map((id) => _tdlib.sendRequest(td.GetChat(chatId: id))),
      );
      for (final res in fwdResults) {
        if (res is td.Chat) {
          knownChatTitles[res.id] = res.title;
        }
      }
    }

    // 6. Get bookmark keys
    final bookmarks = await _db.select(_db.bookmarkEntries).get();
    final bookmarkKeys =
        bookmarks.map((b) => '${b.chatId}_${b.messageId}').toSet();

    // 7. Group albums and map to Posts
    final postsByChatId = <int, List<Post>>{};
    final messagesByChatId = <int, List<td.Message>>{};
    for (final msg in allMessages) {
      messagesByChatId.putIfAbsent(msg.chatId, () => []).add(msg);
    }
    for (final entry in messagesByChatId.entries) {
      final chat = chatMap[entry.key];
      if (chat != null) {
        postsByChatId[entry.key] = TdlibMappers.mergeAlbumMessages(
          entry.value,
          chat,
          bookmarkedKeys: bookmarkKeys,
          knownChatTitles: knownChatTitles,
        );
      }
    }

    // 8. Flatten, sort by date desc
    final allPosts = postsByChatId.values.expand((e) => e).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return allPosts;
  }

  /// Fetch older posts for pagination.
  /// Takes a map of chatId -> oldestMessageId to continue from.
  Future<List<Post>> fetchOlderPosts(Map<int, int> oldestMessageIds) async {
    if (oldestMessageIds.isEmpty) return [];

    final bookmarks = await _db.select(_db.bookmarkEntries).get();
    final bookmarkKeys =
        bookmarks.map((b) => '${b.chatId}_${b.messageId}').toSet();

    // Fetch older history for each channel in PARALLEL
    final futures = oldestMessageIds.entries.map((entry) async {
      final chatObj =
          await _tdlib.sendRequest(td.GetChat(chatId: entry.key));
      if (chatObj is! td.Chat) return <Post>[];

      final history = await _tdlib.sendRequest(td.GetChatHistory(
        chatId: entry.key,
        fromMessageId: entry.value,
        offset: 0,
        limit: 30,
        onlyLocal: false,
      ));
      if (history is! td.Messages || history.messages.isEmpty) return <Post>[];

      return TdlibMappers.mergeAlbumMessages(
        history.messages,
        chatObj,
        bookmarkedKeys: bookmarkKeys,
      );
    });

    final results = await Future.wait(futures);
    final allPosts = results.expand((e) => e).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return allPosts;
  }

  /// Fetch posts for a single channel (local-first fallback).
  Future<List<Post>> fetchChannelPosts(int chatId,
      {int fromMessageId = 0, int limit = 50}) async {
    final chatObj = await _tdlib.sendRequest(td.GetChat(chatId: chatId));
    if (chatObj is! td.Chat) return [];

    // 1. Try local history first for instant rendering
    td.TdObject history = await _tdlib.sendRequest(td.GetChatHistory(
      chatId: chatId,
      fromMessageId: fromMessageId,
      offset: 0,
      limit: limit,
      onlyLocal: true,
    ));

    // For initial loads, require at least 5 local messages before skipping
    // remote fetch. For pagination loads, always fetch remote.
    final minExpected = fromMessageId == 0 ? 5 : 1;
    if (history is! td.Messages || history.messages.length < minExpected) {
      history = await _tdlib.sendRequest(td.GetChatHistory(
        chatId: chatId,
        fromMessageId: fromMessageId,
        offset: 0,
        limit: limit,
        onlyLocal: false,
      ));
    }
    if (history is! td.Messages) return [];

    final bookmarks = await _db.select(_db.bookmarkEntries).get();
    final bookmarkKeys =
        bookmarks.map((b) => '${b.chatId}_${b.messageId}').toSet();

    return TdlibMappers.mergeAlbumMessages(
      history.messages,
      chatObj,
      bookmarkedKeys: bookmarkKeys,
    );
  }

  /// Toggle bookmark using chatId + messageId.
  Future<void> toggleBookmark(int chatId, int messageId) async {
    final existing = await (_db.select(_db.bookmarkEntries)
          ..where(
              (b) => b.chatId.equals(chatId) & b.messageId.equals(messageId)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.delete(_db.bookmarkEntries)
            ..where(
                (b) => b.chatId.equals(chatId) & b.messageId.equals(messageId)))
          .go();
    } else {
      final accounts = await (_db.select(_db.accounts)
            ..where((a) => a.isActive.equals(true)))
          .get();
      final accountId = accounts.isNotEmpty ? accounts.first.id : 1;

      await _db.into(_db.bookmarkEntries).insert(
            BookmarkEntriesCompanion.insert(
              accountId: accountId,
              chatId: chatId,
              messageId: messageId,
            ),
          );
    }
  }

  /// Check if a post is bookmarked.
  Future<bool> isBookmarked(int chatId, int messageId) async {
    final existing = await (_db.select(_db.bookmarkEntries)
          ..where(
              (b) => b.chatId.equals(chatId) & b.messageId.equals(messageId)))
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

  /// Notify TDLib that the user has opened a chat.
  /// Required for proper unread count tracking across clients.
  Future<void> openChat(int chatId) async {
    try {
      await _tdlib.sendRequest(td.OpenChat(chatId: chatId));
    } catch (e) {
      debugPrint('[FeedRepo] openChat error: $e');
    }
  }

  /// Notify TDLib that the user has closed a chat.
  Future<void> closeChat(int chatId) async {
    try {
      await _tdlib.sendRequest(td.CloseChat(chatId: chatId));
    } catch (e) {
      debugPrint('[FeedRepo] closeChat error: $e');
    }
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
        return emojis;
      }
    }
    // Default fallback emojis if all reactions are allowed
    return ['👍', '❤️', '🔥', '🥰', '👏'];
  }

  /// Fetch comments (message thread history) for a channel post
  Future<List<Post>> fetchPostComments(int chatId, int messageId) async {
    try {
      final res = await _tdlib.sendRequest(td.GetMessageThreadHistory(
        chatId: chatId,
        messageId: messageId,
        fromMessageId: 0,
        offset: 0,
        limit: 50,
      ));

      if (res is td.Messages && res.messages.isNotEmpty) {
        final chatObj = await _tdlib.sendRequest(td.GetChat(chatId: chatId));
        if (chatObj is! td.Chat) return [];

        // Collect all unique userIds and senderChatIds
        final userIds = <int>{};
        final chatIds = <int>{};
        for (final m in res.messages) {
          final sender = m.senderId;
          if (sender is td.MessageSenderUser) {
            userIds.add(sender.userId);
          } else if (sender is td.MessageSenderChat) {
            chatIds.add(sender.chatId);
          }
        }

        // Fetch user and chat sender details in parallel
        final userResults = await Future.wait(
          userIds.map((id) => _tdlib.sendRequest(td.GetUser(userId: id))),
        );
        final chatResults = await Future.wait(
          chatIds.map((id) => _tdlib.sendRequest(td.GetChat(chatId: id))),
        );

        final senderTitles = <String, String>{};
        final senderAvatarUrls = <String, String>{};
        final senderAvatarFileIds = <String, int>{};

        for (final r in userResults) {
          if (r is td.User) {
            final fullName = '${r.firstName} ${r.lastName}'.trim();
            final key = 'user_${r.id}';
            senderTitles[key] = fullName.isNotEmpty ? fullName : 'User';
            final photo = r.profilePhoto;
            if (photo != null) {
              senderAvatarFileIds[key] = photo.small.id;
              final path = photo.small.local.path;
              if (path.isNotEmpty) {
                senderAvatarUrls[key] = path;
              } else if (photo.small.remote.id.isNotEmpty) {
                senderAvatarUrls[key] = photo.small.remote.id;
              }
              _syncService.downloadFileWithPriority(photo.small.id);
            }
          }
        }

        for (final r in chatResults) {
          if (r is td.Chat) {
            final key = 'chat_${r.id}';
            senderTitles[key] = r.title;
            final photo = r.photo;
            if (photo != null) {
              senderAvatarFileIds[key] = photo.small.id;
              final path = photo.small.local.path;
              if (path.isNotEmpty) {
                senderAvatarUrls[key] = path;
              } else if (photo.small.remote.id.isNotEmpty) {
                senderAvatarUrls[key] = photo.small.remote.id;
              }
              _syncService.downloadFileWithPriority(photo.small.id);
            }
          }
        }

        final posts = <Post>[];
        for (final m in res.messages) {
          final sender = m.senderId;
          String key = '';
          if (sender is td.MessageSenderUser) {
            key = 'user_${sender.userId}';
          } else if (sender is td.MessageSenderChat) {
            key = 'chat_${sender.chatId}';
          }

          final post = TdlibMappers.mapMessageToPost(
            m,
            chatObj,
            overrideSenderTitle: senderTitles[key],
            overrideSenderAvatarUrl: senderAvatarUrls[key],
            overrideSenderAvatarFileId: senderAvatarFileIds[key],
          );
          posts.add(post);
        }

        return posts;
      }
    } catch (e) {
      debugPrint('[FeedRepo] Failed to fetch comments thread: $e');
    }
    return [];
  }

  /// Post a new comment reply to a post thread
  Future<void> sendComment(int chatId, int messageId, String text, {int? replyToMessageId}) async {
    try {
      await _tdlib.sendRequest(td.SendMessage(
        chatId: chatId,
        messageThreadId: messageId,
        replyTo: td.InputMessageReplyToMessage(messageId: replyToMessageId ?? messageId),
        options: const td.MessageSendOptions(
          disableNotification: false,
          fromBackground: false,
          protectContent: false,
          updateOrderOfInstalledStickerSets: false,
          effectId: 0,
          sendingId: 0,
          onlyPreview: false,
        ),
        inputMessageContent: td.InputMessageText(
          text: td.FormattedText(text: text, entities: []),
          clearDraft: false,
        ),
      ));
    } catch (e) {
      debugPrint('[FeedRepo] Failed to send comment: $e');
      rethrow;
    }
  }
}

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(
    ref.watch(tdlibServiceProvider),
    ref.watch(databaseProvider),
    ref.watch(syncServiceProvider),
  );
});
