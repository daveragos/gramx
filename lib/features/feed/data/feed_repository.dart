import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/core/telegram/telegram_ids.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/database/database_provider.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

class FeedRepository {
  final TdlibService _tdlib;
  final AppDatabase _db;
  final SyncService _syncService;
  final ChatCache _chatCache;

  /// How many posts we aim to hold per channel in the merged feed.
  static const int postsPerChannel = 30;

  /// Channels the throttled backfill will fetch real history for, busiest first.
  ///
  /// Telegram caps `GetChatHistory` at roughly 30 requests per 30 seconds
  /// sustained, so this number and [backfillThrottle] are a matched pair. Don't
  /// raise one without the other — see `docs/TDLIB.md`.
  static const int backfillTopChannels = 30;

  /// Gap between backfill requests. Just over one second keeps us under the cap
  /// with headroom for the requests the user's own taps generate.
  static const Duration backfillThrottle = Duration(milliseconds: 1100);

  /// Channels one "load older" page will reach back into. Pagination is a
  /// user-driven path, but it repeats on every scroll to the bottom, so it is
  /// bounded too.
  static const int paginationChannelsPerPage = 10;

  /// Cap on how many unknown forwarded-from channels we will name per feed
  /// build. Bounded so a feed full of forwards can't become a fan-out.
  static const int _maxForwardLookups = 10;

  FeedRepository(this._tdlib, this._db, this._syncService, this._chatCache);

  /// Composite keys (`chatId_messageId`) of every bookmarked post.
  Future<Set<String>> _bookmarkKeys() async {
    final bookmarks = await _db.select(_db.bookmarkEntries).get();
    return bookmarks.map((b) => '${b.chatId}_${b.messageId}').toSet();
  }

  /// Reads a chat's history from TDLib's local database only.
  ///
  /// `onlyLocal: true` never reaches the server, so this is outside the flood
  /// budget and safe to run across every channel at once. It can legitimately
  /// return nothing on a cold cache.
  Future<List<td.Message>> _localHistory(int chatId, {int limit = 30}) async {
    try {
      final res = await _tdlib.sendRequest(td.GetChatHistory(
        chatId: chatId,
        fromMessageId: 0,
        offset: 0,
        limit: limit,
        onlyLocal: true,
      ));
      return res is td.Messages ? res.messages : const [];
    } catch (e) {
      debugPrint('[FeedRepo] Local history failed for $chatId: $e');
      return const [];
    }
  }

  static List<td.Message> _dedupeMessages(List<td.Message> messages) {
    final byId = <int, td.Message>{};
    for (final m in messages) {
      byId[m.id] = m;
    }
    final list = byId.values.toList()..sort((a, b) => b.id.compareTo(a.id));
    return list;
  }

  /// Builds the merged feed with **no per-channel network requests**.
  ///
  /// Two cheap phases: the chat cache's `lastMessage` (already delivered by the
  /// update stream, so free) and a local-only history read (never touches the
  /// server). Real history for the busiest channels arrives afterwards via
  /// [backfillRecentHistory], which is throttled.
  ///
  /// This deliberately does not call `GetChat` or a networked `GetChatHistory`
  /// per channel. Doing so over a 200-channel list is an instant account-global
  /// FLOOD_WAIT — see `docs/TDLIB.md`.
  Future<List<Post>> fetchFeedPosts() async {
    await _chatCache.ensureLoaded();
    final channelChats = _chatCache.channels;
    if (channelChats.isEmpty) return [];

    for (final chat in channelChats) {
      _syncService.downloadChatAvatar(chat);
    }

    final messagesByChatId = <int, List<td.Message>>{};

    // Phase 1 — one free post per channel, straight off the update stream.
    for (final chat in channelChats) {
      final last = chat.lastMessage;
      if (last != null) messagesByChatId[chat.id] = [last];
    }

    // Phase 2 — whatever TDLib already has on disk.
    final localHistories = await Future.wait(
      channelChats.map((chat) => _localHistory(chat.id, limit: postsPerChannel)),
    );
    for (var i = 0; i < channelChats.length; i++) {
      final chatId = channelChats[i].id;
      messagesByChatId[chatId] = _dedupeMessages([
        ...?messagesByChatId[chatId],
        ...localHistories[i],
      ]);
    }

    return _buildPosts(messagesByChatId, channelChats);
  }

  /// Fetches real history for the busiest channels, one request at a time.
  ///
  /// Yields the growing post list after each channel so the feed fills in
  /// progressively instead of stalling on a batch. Throttled to
  /// [backfillThrottle] and abandoned on the first rate-limit — the penalty for
  /// overrunning is applied to the user's Telegram account, not to this app.
  Stream<List<Post>> backfillRecentHistory() async* {
    final channelChats = _chatCache.channels;
    if (channelChats.isEmpty) return;

    final targets = channelChats.take(backfillTopChannels).toList();
    final messagesByChatId = <int, List<td.Message>>{};
    var produced = false;

    for (final chat in targets) {
      try {
        final res = await _tdlib.sendRequest(td.GetChatHistory(
          chatId: chat.id,
          fromMessageId: 0,
          offset: 0,
          limit: postsPerChannel,
          onlyLocal: false,
        ));
        if (res is td.Messages && res.messages.isNotEmpty) {
          messagesByChatId[chat.id] = _dedupeMessages(res.messages);
          produced = true;
        }
      } on TdlibRequestException catch (e) {
        if (e.isFloodWait) {
          debugPrint('[FeedRepo] Backfill stopped — rate limited: $e');
          break;
        }
        debugPrint('[FeedRepo] Backfill skipped ${chat.id}: $e');
      } catch (e) {
        debugPrint('[FeedRepo] Backfill skipped ${chat.id}: $e');
      }

      if (produced) {
        yield await _buildPosts(messagesByChatId, targets);
      }
      await Future<void>.delayed(backfillThrottle);
    }
  }

  /// Loads one page of older posts, reaching back into a bounded set of channels.
  ///
  /// Only the channels whose oldest loaded post is *newest* can extend the
  /// merged feed backwards — the others already reach further back than the
  /// current frontier. Fetching just those keeps a scroll-to-bottom at
  /// [paginationChannelsPerPage] requests instead of one per subscription.
  Future<List<Post>> fetchOlderPosts(Map<int, int> oldestMessageIds) async {
    if (oldestMessageIds.isEmpty) return [];

    final frontier = oldestMessageIds.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final page = frontier.take(paginationChannelsPerPage);

    final chats = <td.Chat>[];
    final messagesByChatId = <int, List<td.Message>>{};

    for (final entry in page) {
      final chat = _chatCache.chat(entry.key);
      if (chat == null) continue;
      chats.add(chat);

      try {
        final history = await _tdlib.sendRequest(td.GetChatHistory(
          chatId: entry.key,
          fromMessageId: entry.value,
          offset: 0,
          limit: postsPerChannel,
          onlyLocal: false,
        ));
        if (history is td.Messages && history.messages.isNotEmpty) {
          messagesByChatId[entry.key] = _dedupeMessages(history.messages);
        }
      } on TdlibRequestException catch (e) {
        if (e.isFloodWait) {
          debugPrint('[FeedRepo] Pagination stopped — rate limited: $e');
          break;
        }
        debugPrint('[FeedRepo] Pagination skipped ${entry.key}: $e');
      } catch (e) {
        debugPrint('[FeedRepo] Pagination skipped ${entry.key}: $e');
      }
    }

    if (messagesByChatId.isEmpty) return [];
    return _buildPosts(messagesByChatId, chats);
  }

  /// Maps raw messages into sorted [Post]s, resolving forwarded-channel names.
  Future<List<Post>> _buildPosts(
    Map<int, List<td.Message>> messagesByChatId,
    List<td.Chat> chats,
  ) async {
    final chatMap = {for (final c in chats) c.id: c};
    final bookmarkKeys = await _bookmarkKeys();

    final knownChatTitles = <int, String>{};
    for (final chat in chats) {
      knownChatTitles[chat.id] = chat.title;
    }

    // Name forwarded-from channels. The cache answers most of these for free;
    // only genuinely unknown chats cost a request, and that is capped.
    final unresolved = <int>{};
    for (final messages in messagesByChatId.values) {
      for (final msg in messages) {
        final origin = msg.forwardInfo?.origin;
        final originId = switch (origin) {
          td.MessageOriginChannel() => origin.chatId,
          td.MessageOriginChat() => origin.senderChatId,
          _ => null,
        };
        if (originId == null || knownChatTitles.containsKey(originId)) continue;

        final cached = _chatCache.chat(originId);
        if (cached != null) {
          knownChatTitles[originId] = cached.title;
        } else {
          unresolved.add(originId);
        }
      }
    }

    for (final id in unresolved.take(_maxForwardLookups)) {
      try {
        final res = await _tdlib.sendRequest(td.GetChat(chatId: id));
        if (res is td.Chat) knownChatTitles[res.id] = res.title;
      } catch (_) {
        // A private or deleted origin channel; the card falls back to the
        // author signature.
      }
    }

    final posts = <Post>[];
    for (final entry in messagesByChatId.entries) {
      final chat = chatMap[entry.key];
      if (chat == null) continue;
      posts.addAll(TdlibMappers.mergeAlbumMessages(
        entry.value,
        chat,
        bookmarkedKeys: bookmarkKeys,
        knownChatTitles: knownChatTitles,
      ));
    }

    posts.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return posts;
  }

  /// Fetch posts for a single channel (local-first fallback).
  Future<List<Post>> fetchChannelPosts(int chatId,
      {int fromMessageId = 0, int limit = 50}) async {
    td.TdObject chatObj = await _tdlib.sendRequest(td.GetChat(chatId: chatId));
    if (chatObj is! td.Chat) {
      final strId = chatId.toString();
      int? supergroupId;
      if (chatId > 0) {
        supergroupId = chatId;
      } else if (strId.startsWith('-100')) {
        supergroupId = int.tryParse(strId.substring(4));
      }
      if (supergroupId != null) {
        try {
          final res = await _tdlib.sendRequest(td.CreateSupergroupChat(supergroupId: supergroupId, force: false));
          if (res is td.Chat) chatObj = res;
        } catch (_) {}
      }
    }
    if (chatObj is! td.Chat) return [];

    final resolvedChatId = chatObj.id;

    // 1. Try local history first for instant rendering
    td.TdObject history = await _tdlib.sendRequest(td.GetChatHistory(
      chatId: resolvedChatId,
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
        chatId: resolvedChatId,
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

  /// How many search hits one page returns.
  static const int searchPageSize = 40;

  /// Searches posts across every channel the user follows.
  ///
  /// This is a real server-side search. The previous behaviour was a substring
  /// match over whatever happened to be in memory — roughly the last 30 posts
  /// per channel — so anything read last week simply wasn't findable.
  ///
  /// `onlyInChannels` keeps group and private chats out of a channel reader's
  /// results.
  Future<List<Post>> searchPosts(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final res = await _tdlib.sendRequest(td.SearchMessages(
        chatList: const td.ChatListMain(),
        onlyInChannels: true,
        query: trimmed,
        offset: '',
        limit: searchPageSize,
        minDate: 0,
        maxDate: 0,
      ));

      if (res is! td.FoundMessages) return [];
      return await mapIncomingMessages(res.messages);
    } on TdlibRequestException catch (e) {
      debugPrint('[FeedRepo] searchPosts failed: $e');
      rethrow;
    } catch (e) {
      debugPrint('[FeedRepo] searchPosts failed: $e');
      return [];
    }
  }

  /// Maps messages that arrived on the update stream into posts.
  ///
  /// Costs nothing beyond the bookmark lookup — the messages are already in
  /// hand and the chats come from the cache. Messages from chats we don't
  /// follow, or that aren't channels, are dropped.
  Future<List<Post>> mapIncomingMessages(List<td.Message> messages) async {
    if (messages.isEmpty) return [];

    final chats = <td.Chat>[];
    final messagesByChatId = <int, List<td.Message>>{};

    for (final message in messages) {
      final chat = _chatCache.chat(message.chatId);
      if (chat == null || !ChatCacheState.isChannel(chat)) continue;
      if (!messagesByChatId.containsKey(chat.id)) chats.add(chat);
      messagesByChatId.putIfAbsent(chat.id, () => []).add(message);
    }

    if (messagesByChatId.isEmpty) return [];

    for (final entry in messagesByChatId.entries) {
      messagesByChatId[entry.key] = _dedupeMessages(entry.value);
    }

    return _buildPosts(messagesByChatId, chats);
  }

  /// A shareable t.me link for a post.
  ///
  /// Asks TDLib for the canonical link first — it knows about usernames,
  /// albums and thread context. Falls back to building one locally if the
  /// request fails, so sharing still works offline or for a channel TDLib
  /// declines to link.
  Future<String?> postLink(Post post) async {
    try {
      final res = await _tdlib.sendRequest(td.GetMessageLink(
        chatId: post.chatId,
        messageId: post.messageId,
        mediaTimestamp: 0,
        forAlbum: post.media.length > 1,
        inMessageThread: false,
      ));
      if (res is td.MessageLink && res.link.isNotEmpty) return res.link;
    } catch (e) {
      debugPrint('[FeedRepo] GetMessageLink failed, building locally: $e');
    }

    return TelegramIds.postLink(
      chatId: post.chatId,
      messageId: post.messageId,
      username: post.channelUsername,
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

  /// Fetch a single post by chatId and messageId via TDLib GetMessages.
  Future<Post?> fetchSinglePost(int chatId, int messageId) async {
    try {
      final res = await _tdlib.sendRequest(td.GetMessages(
        chatId: chatId,
        messageIds: [messageId],
      ));
      if (res is td.Messages && res.messages.isNotEmpty) {
        final msg = res.messages.first;
        if (msg.id != 0) {
          final chatObj = await _tdlib.sendRequest(td.GetChat(chatId: chatId));
          if (chatObj is td.Chat) {
            final bookmarks = await _db.select(_db.bookmarkEntries).get();
            final bookmarkKeys =
                bookmarks.map((b) => '${b.chatId}_${b.messageId}').toSet();
            final posts = TdlibMappers.mergeAlbumMessages(
              [msg],
              chatObj,
              bookmarkedKeys: bookmarkKeys,
            );
            if (posts.isNotEmpty) return posts.first;
          }
        }
      }
    } catch (e) {
      debugPrint('[FeedRepo] fetchSinglePost error: $e');
    }

    final fallbackPosts =
        await fetchChannelPosts(chatId, fromMessageId: messageId, limit: 20);
    return fallbackPosts.where((p) => p.messageId == messageId).firstOrNull;
  }

  /// Fetch all bookmarked posts stored in the local SQLite database.
  Future<List<Post>> fetchBookmarkedPosts() async {
    final bookmarks = await _db.select(_db.bookmarkEntries).get();
    if (bookmarks.isEmpty) return [];

    final bookmarkKeys =
        bookmarks.map((b) => '${b.chatId}_${b.messageId}').toSet();

    final messagesByChatId = <int, List<int>>{};
    for (final b in bookmarks) {
      messagesByChatId.putIfAbsent(b.chatId, () => []).add(b.messageId);
    }

    final bookmarkedPosts = <Post>[];

    for (final entry in messagesByChatId.entries) {
      final chatId = entry.key;
      final messageIds = entry.value;

      try {
        final chatObj = await _tdlib.sendRequest(td.GetChat(chatId: chatId));
        if (chatObj is! td.Chat) continue;

        final res = await _tdlib.sendRequest(td.GetMessages(
          chatId: chatId,
          messageIds: messageIds,
        ));

        if (res is td.Messages && res.messages.isNotEmpty) {
          final validMsgs = res.messages.whereType<td.Message>().toList();
          final posts = TdlibMappers.mergeAlbumMessages(
            validMsgs,
            chatObj,
            bookmarkedKeys: bookmarkKeys,
          );
          bookmarkedPosts.addAll(posts);
        }
      } catch (e) {
        debugPrint('[FeedRepo] Failed to fetch bookmarked messages for chat $chatId: $e');
      }
    }

    bookmarkedPosts.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return bookmarkedPosts;
  }

  /// Acknowledges a post as read with Telegram.
  ///
  /// [postId] is the composite `"<chatId>_<messageId>"` form.
  ///
  /// [forceRead] tells TDLib to write the read state through even though the
  /// chat isn't open. Pass false while the chat *is* open — then the ack is the
  /// canonical "the user is reading this" signal rather than an assertion.
  /// This is not cosmetic: read state propagates to every Telegram client the
  /// user owns, so an over-eager true marks posts read on their phone too.
  Future<void> markPostAsRead(String postId, {bool forceRead = true}) async {
    final parts = postId.split('_');
    if (parts.length != 2) return;
    final chatId = int.tryParse(parts[0]);
    final messageId = int.tryParse(parts[1]);
    if (chatId == null || messageId == null) return;

    try {
      await _tdlib.sendRequest(td.ViewMessages(
        chatId: chatId,
        messageIds: [messageId],
        forceRead: forceRead,
      ));
    } catch (e) {
      debugPrint('[FeedRepo] markPostAsRead failed for $postId: $e');
    }
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
      int targetChatId = chatId;
      int targetThreadId = messageId;

      final threadInfo = await _tdlib.sendRequest(td.GetMessageThread(chatId: chatId, messageId: messageId));
      if (threadInfo is td.MessageThreadInfo) {
        targetChatId = threadInfo.chatId;
        targetThreadId = threadInfo.messageThreadId;
      }

      await _tdlib.sendRequest(td.SendMessage(
        chatId: targetChatId,
        messageThreadId: targetThreadId,
        replyTo: td.InputMessageReplyToMessage(messageId: replyToMessageId ?? targetThreadId),
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
    ref.watch(chatCacheProvider),
  );
});
