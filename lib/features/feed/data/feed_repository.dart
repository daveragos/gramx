import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/search/domain/search_filters.dart';
import 'package:gramx/core/async/ui_yield.dart';
import 'package:gramx/core/telegram/telegram_ids.dart';
import 'package:gramx/features/compose/data/compose_repository.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/compose_remote_media.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/domain/post_sender.dart';
import 'package:gramx/features/feed/domain/seen_posts.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/database/database_provider.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/message_content_support.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// A channel post found in Saved Messages that could be a bookmark.
typedef RestorableBookmark = ({int chatId, int messageId, int savedMessageId});

class FeedRepository {
  final TdlibService _tdlib;
  final AppDatabase _db;
  final SyncService _syncService;
  final ChatCache _chatCache;

  /// How many posts the merged feed aims to hold per channel.
  static const int postsPerChannel = 30;

  /// Channels the backfill fetches history for. Telegram allows about 30
  /// `GetChatHistory` calls per 30 seconds; change with [backfillThrottle].
  static const int backfillTopChannels = 30;

  /// Gap between backfill requests, leaving headroom for the user's own taps.
  static const Duration backfillThrottle = Duration(milliseconds: 1100);

  /// Server requests opening a channel may make to fill the first page, since
  /// TDLib can return fewer messages than asked while more history remains.
  static const int channelHistoryMaxRequests = 4;

  /// Channels the unread sweep reaches behind the read cursor for, on the
  /// backfill's budget.
  static const int unreadSweepTopChannels = 30;

  /// Unread posts lifted per channel per sweep.
  static const int unreadPerChannel = 5;

  /// Channels one "load older" page reaches into.
  static const int paginationChannelsPerPage = 10;

  /// Cap on unknown forwarded-from channels looked up per feed build.
  static const int _maxForwardLookups = 10;

  FeedRepository(this._tdlib, this._db, this._syncService, this._chatCache);

  /// Picks the channels whose oldest loaded post is newest, the only ones that
  /// can extend the merged feed backwards.
  static List<MapEntry<int, int>> selectPaginationFrontier(
    Map<int, int> oldestMessageIds, {
    required int limit,
  }) {
    final entries = oldestMessageIds.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  /// Composite keys (`chatId_messageId`) of every bookmarked post.
  Future<Set<String>> _bookmarkKeys() async {
    final bookmarks = await _db.select(_db.bookmarkEntries).get();
    return bookmarks.map((b) => '${b.chatId}_${b.messageId}').toSet();
  }

  /// Reads a chat's history from TDLib's local database only, outside the
  /// flood budget. May return nothing on a cold cache.
  Future<List<td.Message>> _localHistory(int chatId, {int limit = 30}) async {
    try {
      final res = await _tdlib.sendRequest(
        td.GetChatHistory(
          chatId: chatId,
          fromMessageId: 0,
          offset: 0,
          limit: limit,
          onlyLocal: true,
        ),
      );
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

  /// Whether [message] is unread, by the same rule as `Post.isRead`. Checked
  /// before mapping so read messages are skipped.
  static bool isUnreadIn(td.Chat chat, td.Message message) =>
      !message.isOutgoing && message.id > chat.lastReadInboxMessageId;

  /// How many of a channel's newest messages can be unread.
  static int unreadWanted(td.Chat chat) =>
      chat.unreadCount < postsPerChannel ? chat.unreadCount : postsPerChannel;

  /// Subscribed channels with anything unread, most recently active first.
  List<td.Chat> _channelsWithUnread() => [
    for (final chat in _chatCache.channels)
      if (chat.unreadCount > 0) chat,
  ];

  /// One unread post per channel, from each chat's `lastMessage`. Costs no
  /// request, so it can show while [fetchUnreadLocalPosts] is still reading.
  Future<List<Post>> fetchHeadlinePosts() async {
    await _chatCache.ensureFirstPage();
    final channelChats = _chatCache.channels;
    final messagesByChatId = <int, List<td.Message>>{
      for (final chat in channelChats)
        if (chat.lastMessage case final last? when isUnreadIn(chat, last))
          chat.id: [last],
    };
    if (messagesByChatId.isEmpty) return [];
    return _buildPosts(messagesByChatId, channelChats, quick: true);
  }

  /// The unread posts TDLib holds on disk, in stages of [firstStageChannels]
  /// channels, most recently active first. Local reads only; the rest comes
  /// from [backfillRecentHistory]. Each yield holds only that stage's posts.
  Stream<List<Post>> fetchUnreadLocalPosts() async* {
    await _chatCache.ensureFirstPage();
    final done = <int>{};

    // Repeat as each round of the chat list lands, until the whole list is in.
    while (true) {
      final wholeList = !_chatCache.isLoading;
      final fresh = [
        for (final chat in _channelsWithUnread())
          if (done.add(chat.id)) chat,
      ];
      for (var start = 0; start < fresh.length; start += firstStageChannels) {
        yield await _unreadLocalStage(
          fresh.skip(start).take(firstStageChannels).toList(),
        );
      }
      if (wholeList) return;
      await _chatCache.nextRound();
    }
  }

  /// How many channels one local stage covers.
  static const int firstStageChannels = 20;

  Future<List<Post>> _unreadLocalStage(List<td.Chat> chats) async {
    for (final chat in chats) {
      _syncService.downloadChatAvatar(chat);
    }

    // A few channels at a time, yielding a frame between batches.
    final messagesByChatId = <int, List<td.Message>>{};

    // A channel with one unread post needs no read: that post is its last
    // message, which came with the chat list.
    final toRead = <td.Chat>[];
    for (final chat in chats) {
      final last = chat.lastMessage;
      if (chat.unreadCount == 1 && last != null && isUnreadIn(chat, last)) {
        messagesByChatId[chat.id] = [last];
      } else {
        toRead.add(chat);
      }
    }

    for (var start = 0; start < toRead.length; start += localReadBatch) {
      final batch = toRead.skip(start).take(localReadBatch).toList();
      final histories = await Future.wait(
        batch.map((chat) => _localHistory(chat.id, limit: unreadWanted(chat))),
      );
      for (var i = 0; i < batch.length; i++) {
        final chat = batch[i];
        final unread = [
          for (final message in [?chat.lastMessage, ...histories[i]])
            if (isUnreadIn(chat, message)) message,
        ];
        if (unread.isNotEmpty) {
          messagesByChatId[chat.id] = _dedupeMessages(unread);
        }
      }
      await yieldToUi();
    }

    if (messagesByChatId.isEmpty) return const [];
    return _buildPosts(messagesByChatId, chats);
  }

  /// How many channels' local histories are read at once.
  static const int localReadBatch = 6;

  /// How many messages [_buildPosts] maps before letting a frame through.
  static const int mapYieldEvery = 60;

  /// Fetches unread history not on disk, one channel at a time, yielding each
  /// channel's posts as they arrive. Channels covered by [heldLocally] are
  /// skipped. Stops on the first rate limit, since Telegram penalises the
  /// account.
  Stream<List<Post>> backfillRecentHistory({
    Map<int, int> heldLocally = const {},
  }) async* {
    final targets = [
      for (final chat in _channelsWithUnread())
        if ((heldLocally[chat.id] ?? 0) < unreadWanted(chat)) chat,
    ].take(backfillTopChannels).toList();

    for (var i = 0; i < targets.length; i++) {
      if (i > 0) await Future<void>.delayed(backfillThrottle);
      final chat = targets[i];

      List<td.Message> unread = const [];
      try {
        final res = await _tdlib.sendRequest(
          td.GetChatHistory(
            chatId: chat.id,
            fromMessageId: 0,
            offset: 0,
            limit: unreadWanted(chat),
            onlyLocal: false,
          ),
        );
        if (res is td.Messages) {
          unread = [
            for (final message in res.messages)
              if (isUnreadIn(chat, message)) message,
          ];
        }
      } on TdlibRequestException catch (e) {
        if (e.isFloodWait) {
          debugPrint('[FeedRepo] Backfill stopped — rate limited: $e');
          return;
        }
        debugPrint('[FeedRepo] Backfill skipped ${chat.id}: $e');
      } catch (e) {
        debugPrint('[FeedRepo] Backfill skipped ${chat.id}: $e');
      }

      if (unread.isNotEmpty) {
        yield await _buildPosts({chat.id: _dedupeMessages(unread)}, [chat]);
      }
    }
  }

  /// Unread posts behind each channel's read cursor that TDLib already holds
  /// locally, so the first paint can include a backlog mix.
  Future<List<Post>> fetchCachedUnreadBacklog() async {
    final targets = _chatCache.channels
        .where((chat) => chat.unreadCount > 0)
        .take(unreadSweepTopChannels)
        .toList();
    if (targets.isEmpty) return const [];

    // Batched with a frame between, since this runs right after first paint.
    final messagesByChatId = <int, List<td.Message>>{};
    for (var start = 0; start < targets.length; start += localReadBatch) {
      final batch = targets.skip(start).take(localReadBatch).toList();
      final histories = await Future.wait(batch.map(_localUnread));
      for (var i = 0; i < batch.length; i++) {
        if (histories[i].isEmpty) continue;
        messagesByChatId[batch[i].id] = _dedupeMessages(histories[i]);
      }
      await yieldToUi();
    }
    if (messagesByChatId.isEmpty) return const [];

    return _buildPosts(messagesByChatId, targets);
  }

  /// The oldest unread messages of one chat, from TDLib's own database.
  Future<List<td.Message>> _localUnread(td.Chat chat) async {
    try {
      final res = await _tdlib.sendRequest(
        td.GetChatHistory(
          chatId: chat.id,
          // A negative offset from the read cursor returns the messages after
          // it: the oldest unread rather than the newest.
          fromMessageId: chat.lastReadInboxMessageId,
          offset: -unreadPerChannel,
          limit: unreadPerChannel,
          onlyLocal: true,
        ),
      );
      if (res is! td.Messages) return const [];
      return res.messages
          .where((m) => m.id > chat.lastReadInboxMessageId)
          .toList();
    } catch (e) {
      debugPrint('[FeedRepo] Local unread failed for ${chat.id}: $e');
      return const [];
    }
  }

  /// The oldest unread posts behind each channel's read cursor, for the feed
  /// to weave in (see `buildFeedEntries`). Same budget rules as
  /// [backfillRecentHistory].
  Future<List<Post>> fetchUnreadBacklog() async {
    final targets = _chatCache.channels
        .where((chat) => chat.unreadCount > 0)
        .take(unreadSweepTopChannels)
        .toList();
    if (targets.isEmpty) return const [];

    final messagesByChatId = <int, List<td.Message>>{};

    for (final chat in targets) {
      try {
        final res = await _tdlib.sendRequest(
          td.GetChatHistory(
            chatId: chat.id,
            // A negative offset from the read cursor returns the oldest unread.
            fromMessageId: chat.lastReadInboxMessageId,
            offset: -unreadPerChannel,
            limit: unreadPerChannel,
            onlyLocal: false,
          ),
        );
        if (res is td.Messages && res.messages.isNotEmpty) {
          final unread = res.messages
              .where((m) => m.id > chat.lastReadInboxMessageId)
              .toList();
          if (unread.isNotEmpty) {
            messagesByChatId[chat.id] = _dedupeMessages(unread);
          }
        }
      } on TdlibRequestException catch (e) {
        if (e.isFloodWait) {
          debugPrint('[FeedRepo] Unread sweep stopped — rate limited: $e');
          break;
        }
        debugPrint('[FeedRepo] Unread sweep skipped ${chat.id}: $e');
      } catch (e) {
        debugPrint('[FeedRepo] Unread sweep skipped ${chat.id}: $e');
      }

      await Future<void>.delayed(backfillThrottle);
    }

    if (messagesByChatId.isEmpty) return const [];
    return _buildPosts(messagesByChatId, targets);
  }

  /// Loads one page of older posts. See [selectPaginationFrontier].
  Future<List<Post>> fetchOlderPosts(Map<int, int> oldestMessageIds) async {
    if (oldestMessageIds.isEmpty) return [];

    final page = selectPaginationFrontier(
      oldestMessageIds,
      limit: paginationChannelsPerPage,
    );

    final chats = <td.Chat>[];
    final messagesByChatId = <int, List<td.Message>>{};

    for (final entry in page) {
      final chat = _chatCache.chat(entry.key);
      if (chat == null) continue;
      chats.add(chat);

      try {
        final history = await _tdlib.sendRequest(
          td.GetChatHistory(
            chatId: entry.key,
            fromMessageId: entry.value,
            offset: 0,
            limit: postsPerChannel,
            onlyLocal: false,
          ),
        );
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

  /// Fetches the messages that posts in this batch reply to. TDLib only
  /// inlines `replyTo.content` for cross-chat replies and quotes.
  Future<Map<String, String>> _resolveReplyExcerpts(
    Map<int, List<td.Message>> messagesByChatId,
  ) async {
    final wanted = <int, Set<int>>{};

    for (final entry in messagesByChatId.entries) {
      for (final message in entry.value) {
        final replyTo = message.replyTo;
        if (replyTo is! td.MessageReplyToMessage) continue;
        // Already inlined by TDLib, or the reply quotes specific text.
        if (replyTo.content != null || replyTo.quote != null) continue;
        if (replyTo.messageId == 0) continue;
        wanted.putIfAbsent(entry.key, () => {}).add(replyTo.messageId);
      }
    }

    if (wanted.isEmpty) return const {};

    final excerpts = <String, String>{};
    await Future.wait(
      wanted.entries.map((entry) async {
        try {
          final res = await _tdlib.sendRequest(
            td.GetMessages(chatId: entry.key, messageIds: entry.value.toList()),
          );
          if (res is! td.Messages) return;
          for (final message in res.messages) {
            // GetMessages returns id 0 for messages it doesn't have.
            if (message.id == 0) continue;
            final excerpt = TdlibMappers.excerptOf(message);
            if (excerpt != null) {
              excerpts['${entry.key}_${message.id}'] = excerpt;
            }
          }
        } catch (e) {
          debugPrint(
            '[FeedRepo] Reply excerpt lookup failed for ${entry.key}: $e',
          );
        }
      }),
    );
    return excerpts;
  }

  /// Names the channels the cache doesn't know. A private or deleted origin
  /// is left out, and the card falls back to the author signature.
  Future<Map<int, String>> _lookupOriginTitles(Iterable<int> chatIds) async {
    final titles = <int, String>{};
    await Future.wait(
      chatIds.map((id) async {
        try {
          final res = await _tdlib.sendRequest(td.GetChat(chatId: id));
          if (res is td.Chat) titles[res.id] = res.title;
        } catch (_) {}
      }),
    );
    return titles;
  }

  /// Maps raw messages into sorted [Post]s. [quick] skips lookups that reach
  /// the server, for a first paint.
  Future<List<Post>> _buildPosts(
    Map<int, List<td.Message>> messagesByChatId,
    List<td.Chat> chats, {
    bool quick = false,
  }) async {
    final chatMap = {for (final c in chats) c.id: c};

    final knownChatTitles = <int, String>{};
    for (final chat in chats) {
      knownChatTitles[chat.id] = chat.title;
    }

    // Name the channels a post points at: the forward origin, and the origin
    // of a reply or quote. Unknown chats cost a capped request.
    final unresolved = <int>{};
    void nameOrigin(td.MessageOrigin? origin) {
      final originId = switch (origin) {
        td.MessageOriginChannel() => origin.chatId,
        td.MessageOriginChat() => origin.senderChatId,
        _ => null,
      };
      if (originId == null || knownChatTitles.containsKey(originId)) return;

      final cached = _chatCache.chat(originId);
      if (cached != null) {
        knownChatTitles[originId] = cached.title;
      } else {
        unresolved.add(originId);
      }
    }

    for (final messages in messagesByChatId.values) {
      for (final msg in messages) {
        nameOrigin(msg.forwardInfo?.origin);
        final replyTo = msg.replyTo;
        if (replyTo is td.MessageReplyToMessage) nameOrigin(replyTo.origin);
      }
    }

    // Independent lookups, started together so their round trips overlap.
    final bookmarkKeysFuture = _bookmarkKeys();
    final originTitlesFuture = quick
        ? Future.value(const <int, String>{})
        : _lookupOriginTitles(unresolved.take(_maxForwardLookups));
    final replyExcerptsFuture = quick
        ? Future.value(const <String, String>{})
        : _resolveReplyExcerpts(messagesByChatId);

    final bookmarkKeys = await bookmarkKeysFuture;
    knownChatTitles.addAll(await originTitlesFuture);
    final replyExcerpts = await replyExcerptsFuture;

    // Mapping is slow across many channels, so yield a frame periodically.
    final posts = <Post>[];
    var mappedSinceYield = 0;
    for (final entry in messagesByChatId.entries) {
      final chat = chatMap[entry.key];
      if (chat == null) continue;
      posts.addAll(
        TdlibMappers.mergeAlbumMessages(
          entry.value,
          chat,
          bookmarkedKeys: bookmarkKeys,
          knownChatTitles: knownChatTitles,
          knownReplyExcerpts: replyExcerpts,
        ),
      );
      mappedSinceYield += entry.value.length;
      if (mappedSinceYield >= mapYieldEvery) {
        mappedSinceYield = 0;
        await yieldToUi();
      }
    }

    posts.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return posts;
  }

  /// Maps messages into posts for one chat, without the subscription filter
  /// of [mapIncomingMessages].
  Future<List<Post>> mapChannelMessages(
    int chatId,
    List<td.Message> messages,
  ) async {
    if (messages.isEmpty) return [];

    var chat = _chatCache.chat(chatId);
    if (chat == null) {
      final res = await _tdlib.sendRequest(td.GetChat(chatId: chatId));
      if (res is! td.Chat) return [];
      chat = res;
    }

    return _buildPosts({chatId: _dedupeMessages(messages)}, [chat]);
  }

  /// Fetches posts for a single channel, local history first.
  Future<List<Post>> fetchChannelPosts(
    int chatId, {
    int fromMessageId = 0,
    int limit = 50,
  }) async {
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
          final res = await _tdlib.sendRequest(
            td.CreateSupergroupChat(supergroupId: supergroupId, force: false),
          );
          if (res is td.Chat) chatObj = res;
        } catch (_) {}
      }
    }
    if (chatObj is! td.Chat) return [];

    final resolvedChatId = chatObj.id;
    final collected = <td.Message>[];
    final seen = <int>{};

    void collect(td.TdObject? response) {
      if (response is! td.Messages) return;
      for (final message in response.messages) {
        if (seen.add(message.id)) collected.add(message);
      }
    }

    collect(
      await _tdlib.sendRequest(
        td.GetChatHistory(
          chatId: resolvedChatId,
          fromMessageId: fromMessageId,
          offset: 0,
          limit: limit,
          onlyLocal: true,
        ),
      ),
    );

    // Then ask the server until there is a full page, since `GetChatHistory`
    // can return a short batch before the history ends.
    var cursor = collected.isEmpty ? fromMessageId : collected.last.id;
    for (
      var attempt = 0;
      attempt < channelHistoryMaxRequests && collected.length < limit;
      attempt++
    ) {
      final before = collected.length;
      try {
        collect(
          await _tdlib.sendRequest(
            td.GetChatHistory(
              chatId: resolvedChatId,
              fromMessageId: cursor,
              offset: 0,
              limit: limit - collected.length,
              onlyLocal: false,
            ),
          ),
        );
      } on TdlibRequestException catch (e) {
        debugPrint('[FeedRepo] Channel history stopped: $e');
        break;
      }

      // No new messages means the end of the history.
      if (collected.length == before) break;
      cursor = collected.last.id;
    }

    if (collected.isEmpty) return [];

    final bookmarks = await _db.select(_db.bookmarkEntries).get();
    final bookmarkKeys = bookmarks
        .map((b) => '${b.chatId}_${b.messageId}')
        .toSet();

    return TdlibMappers.mergeAlbumMessages(
      collected,
      chatObj,
      bookmarkedKeys: bookmarkKeys,
    );
  }

  static const int searchPageSize = 40;

  /// Searches posts on the server across every channel the user follows.
  Future<List<Post>> searchPosts(
    String query, {
    SearchFilters filters = const SearchFilters(),
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final folderId = filters.folderId;
      final res = await _tdlib.sendRequest(
        td.SearchMessages(
          chatList: folderId == null
              ? const td.ChatListMain()
              : td.ChatListFolder(chatFolderId: folderId),
          onlyInChannels: true,
          query: trimmed,
          offset: '',
          limit: searchPageSize,
          filter: searchFilterFor(filters.type),
          minDate: filters.minDateFor(DateTime.now()),
          maxDate: 0,
        ),
      );

      if (res is! td.FoundMessages) return [];
      final posts = await mapIncomingMessages(res.messages);
      return [
        for (final post in posts)
          if (filters.keeps(post)) post,
      ];
    } on TdlibRequestException catch (e) {
      debugPrint('[FeedRepo] searchPosts failed: $e');
      rethrow;
    } catch (e) {
      debugPrint('[FeedRepo] searchPosts failed: $e');
      return [];
    }
  }

  /// TDLib's filter for a [SearchMediaType], or null for any post.
  static td.SearchMessagesFilter? searchFilterFor(SearchMediaType type) =>
      switch (type) {
        SearchMediaType.any => null,
        SearchMediaType.photos => const td.SearchMessagesFilterPhoto(),
        SearchMediaType.videos => const td.SearchMessagesFilterVideo(),
        SearchMediaType.links => const td.SearchMessagesFilterUrl(),
        SearchMediaType.files => const td.SearchMessagesFilterDocument(),
        SearchMediaType.voice => const td.SearchMessagesFilterVoiceNote(),
        SearchMediaType.music => const td.SearchMessagesFilterAudio(),
      };

  /// Maps messages from the update stream into posts, dropping any not from
  /// a subscribed channel.
  Future<List<Post>> mapIncomingMessages(List<td.Message> messages) async {
    if (messages.isEmpty) return [];

    final chats = <td.Chat>[];
    final messagesByChatId = <int, List<td.Message>>{};

    for (final message in messages) {
      final chat = _chatCache.chat(message.chatId);
      // TDLib also streams updates for chats the user hasn't joined.
      if (chat == null ||
          !ChatCacheState.isChannel(chat) ||
          !ChatCacheState.isSubscribed(chat)) {
        continue;
      }
      if (!messagesByChatId.containsKey(chat.id)) chats.add(chat);
      messagesByChatId.putIfAbsent(chat.id, () => []).add(message);
    }

    if (messagesByChatId.isEmpty) return [];

    for (final entry in messagesByChatId.entries) {
      messagesByChatId[entry.key] = _dedupeMessages(entry.value);
    }

    return _buildPosts(messagesByChatId, chats);
  }

  /// Forwards a post into another Telegram chat.
  Future<bool> forwardPost({required Post post, required int toChatId}) async {
    try {
      final res = await _tdlib.sendRequest(
        td.ForwardMessages(
          chatId: toChatId,
          messageThreadId: 0,
          fromChatId: post.chatId,
          messageIds: [post.messageId],
          options: const td.MessageSendOptions(
            disableNotification: false,
            fromBackground: false,
            protectContent: false,
            updateOrderOfInstalledStickerSets: false,
            effectId: 0,
            sendingId: 0,
            onlyPreview: false,
          ),
          // Forward with attribution rather than copying the content.
          sendCopy: false,
          removeCaption: false,
        ),
      );
      return res is td.Messages;
    } catch (e) {
      debugPrint('[FeedRepo] Forward failed: $e');
      return false;
    }
  }

  /// Chats this account can post into, from the cache.
  List<td.Chat> forwardTargets() => _chatCache.forwardTargets;

  /// A shareable t.me link for a post, from TDLib or built locally if that
  /// fails.
  Future<String?> postLink(Post post) async {
    try {
      final res = await _tdlib.sendRequest(
        td.GetMessageLink(
          chatId: post.chatId,
          messageId: post.messageId,
          mediaTimestamp: 0,
          forAlbum: post.media.length > 1,
          inMessageThread: false,
        ),
      );
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

  /// Bookmarks or unbookmarks a post. Setting a state rather than flipping
  /// it means a repeated tap, or one racing an earlier write, can't undo
  /// itself. The local row is the index; a forward to Saved Messages
  /// survives a reinstall (see [findRestorableBookmarks]) and is best
  /// effort, not retried.
  Future<void> setBookmarked(
    int chatId,
    int messageId, {
    required bool bookmarked,
  }) async {
    final existing = await _bookmarkRow(chatId, messageId);

    if (!bookmarked) {
      if (existing == null) return;
      await (_db.delete(
        _db.bookmarkEntries,
      )..where((b) => b.id.equals(existing.id))).go();
      // Only a copy gramX wrote: a restored bookmark's copy can be a post the
      // user saved themselves.
      if (await _isOwnSavedCopy(existing)) {
        await _removeSavedCopy(existing.savedMessageId);
      }
      return;
    }

    if (existing != null) return;
    final accountId = (await _activeAccount())?.id ?? 1;
    final savedMessageId = await _writeSavedCopy(chatId, messageId);

    await _db
        .into(_db.bookmarkEntries)
        .insert(
          BookmarkEntriesCompanion.insert(
            accountId: accountId,
            chatId: chatId,
            messageId: messageId,
            savedMessageId: Value(savedMessageId),
            isRestored: const Value(false),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<BookmarkEntry?> _bookmarkRow(int chatId, int messageId) =>
      (_db.select(_db.bookmarkEntries)..where(
            (b) => b.chatId.equals(chatId) & b.messageId.equals(messageId),
          ))
          .getSingleOrNull();

  /// How close a Saved Messages copy's date must be to its bookmark's for
  /// the copy to be one gramX wrote when bookmarking.
  static const Duration _ownCopyWindow = Duration(minutes: 2);

  /// Whether [row]'s Saved Messages copy was written by gramX for it. A
  /// restored row's copy was already there; for a row from before
  /// [BookmarkEntries.isRestored], the copy's date tells.
  Future<bool> _isOwnSavedCopy(BookmarkEntry row) async {
    final restored = row.isRestored;
    if (restored != null) return !restored;
    final savedId = row.savedMessageId;
    final saved = await _savedMessagesChatId();
    if (savedId == null || saved == null) return false;
    try {
      final res = await _tdlib.sendRequest(
        td.GetMessage(chatId: saved, messageId: savedId),
      );
      return res is td.Message && !wasRestored(row.createdAt, res.date);
    } catch (_) {
      // Gone, or unreadable: leave Saved Messages alone.
      return false;
    }
  }

  /// Whether a bookmark made at [bookmarkedAt] was restored from a Saved
  /// Messages copy sent at [copyDate] (Unix seconds): a copy written when
  /// bookmarking is sent within moments, a restored one long before.
  @visibleForTesting
  static bool wasRestored(DateTime bookmarkedAt, int copyDate) {
    final copyAt = DateTime.fromMillisecondsSinceEpoch(copyDate * 1000);
    return bookmarkedAt.difference(copyAt) > _ownCopyWindow;
  }

  /// The signed-in account's row.
  Future<Account?> _activeAccount() async {
    final accounts = await (_db.select(
      _db.accounts,
    )..where((a) => a.isActive.equals(true))).get();
    return accounts.isEmpty ? null : accounts.first;
  }

  /// This account's Saved Messages chat, created if needed. Its id is the
  /// user id.
  Future<int?> _savedMessagesChatId() async {
    final selfId = int.tryParse((await _activeAccount())?.telegramUserId ?? '');
    if (selfId == null) return null;
    if (_chatCache.chat(selfId) != null) return selfId;

    try {
      final res = await _tdlib.sendRequest(
        td.CreatePrivateChat(userId: selfId, force: false),
      );
      return res is td.Chat ? res.id : null;
    } catch (e) {
      debugPrint('[FeedRepo] Saved Messages unavailable: $e');
      return null;
    }
  }

  /// Forwards a post into Saved Messages and returns the copy's id.
  Future<int?> _writeSavedCopy(int chatId, int messageId) async {
    final saved = await _savedMessagesChatId();
    if (saved == null) return null;

    try {
      final res = await _tdlib.sendRequest(
        td.ForwardMessages(
          chatId: saved,
          messageThreadId: 0,
          fromChatId: chatId,
          messageIds: [messageId],
          options: const td.MessageSendOptions(
            // No notification for a note to yourself.
            disableNotification: true,
            fromBackground: true,
            protectContent: false,
            updateOrderOfInstalledStickerSets: false,
            effectId: 0,
            sendingId: 0,
            onlyPreview: false,
          ),
          // Attribution is required: a restore reads it to find the original.
          sendCopy: false,
          removeCaption: false,
        ),
      );
      if (res is! td.Messages || res.messages.isEmpty) return null;
      return res.messages.first.id;
    } catch (e) {
      debugPrint('[FeedRepo] Could not save bookmark to Saved Messages: $e');
      return null;
    }
  }

  Future<void> _removeSavedCopy(int? savedMessageId) async {
    if (savedMessageId == null) return;
    final saved = await _savedMessagesChatId();
    if (saved == null) return;

    try {
      await _tdlib.sendRequest(
        td.DeleteMessages(
          chatId: saved,
          messageIds: [savedMessageId],
          // Saved Messages has no other side, so revoke is harmless.
          revoke: true,
        ),
      );
    } catch (e) {
      debugPrint('[FeedRepo] Could not remove the saved copy: $e');
    }
  }

  /// How far back a restore reads.
  static const int _restorePages = 8;
  static const int _restorePageSize = 100;

  /// The channel posts in Saved Messages that aren't bookmarked, newest
  /// first. gramX keeps a copy of each bookmark there, so after a reinstall
  /// these include the old bookmarks, but also anything the user forwarded
  /// there themselves. Nothing is added until [addRestoredBookmarks].
  Future<List<RestorableBookmark>> findRestorableBookmarks() async {
    final saved = await _savedMessagesChatId();
    if (saved == null) return const [];

    final known = await _bookmarkKeys();
    final found = <RestorableBookmark>[];
    var fromMessageId = 0;

    for (var page = 0; page < _restorePages; page++) {
      final messages = await _savedMessagesPage(saved, fromMessageId);
      if (messages.isEmpty) break;

      for (final message in messages) {
        final origin = bookmarkOriginOf(message);
        if (origin == null) continue;
        if (!known.add('${origin.chatId}_${origin.messageId}')) continue;
        found.add((
          chatId: origin.chatId,
          messageId: origin.messageId,
          savedMessageId: message.id,
        ));
      }

      fromMessageId = messages.last.id;
    }
    return found;
  }

  /// Adds [restorable] as restored bookmarks. Returns how many were added.
  Future<int> addRestoredBookmarks(List<RestorableBookmark> restorable) async {
    final accountId = (await _activeAccount())?.id ?? 1;
    var added = 0;
    await _db.batch((batch) {
      for (final item in restorable) {
        batch.insert(
          _db.bookmarkEntries,
          BookmarkEntriesCompanion.insert(
            accountId: accountId,
            chatId: item.chatId,
            messageId: item.messageId,
            savedMessageId: Value(item.savedMessageId),
            isRestored: const Value(true),
          ),
          mode: InsertMode.insertOrIgnore,
        );
        added++;
      }
    });
    return added;
  }

  /// Removes every restored bookmark. Saved Messages is left as it is.
  Future<int> removeRestoredBookmarks() async {
    await _resolveRestoredFlags();
    return (_db.delete(
      _db.bookmarkEntries,
    )..where((b) => b.isRestored.equals(true))).go();
  }

  /// Works out [BookmarkEntries.isRestored] for rows from before it, from
  /// their Saved Messages copies' dates, and saves it. One request.
  Future<void> _resolveRestoredFlags() async {
    final unknown = await (_db.select(
      _db.bookmarkEntries,
    )..where((b) => b.isRestored.isNull())).get();
    if (unknown.isEmpty) return;

    final withCopy = [
      for (final row in unknown)
        if (row.savedMessageId != null) row,
    ];
    final copyDates = <int, int>{};
    final saved = withCopy.isEmpty ? null : await _savedMessagesChatId();
    if (saved != null) {
      try {
        final res = await _tdlib.sendRequest(
          td.GetMessages(
            chatId: saved,
            messageIds: [for (final row in withCopy) row.savedMessageId!],
          ),
        );
        if (res is td.Messages) {
          for (final message in res.messages.whereType<td.Message>()) {
            copyDates[message.id] = message.date;
          }
        }
      } catch (e) {
        // Unknown for now; asked again next time.
        debugPrint('[FeedRepo] Could not read bookmark copies: $e');
        return;
      }
    }

    await _db.batch((batch) {
      for (final row in unknown) {
        final copyDate = copyDates[row.savedMessageId];
        batch.update(
          _db.bookmarkEntries,
          BookmarkEntriesCompanion(
            isRestored: Value(
              copyDate != null && wasRestored(row.createdAt, copyDate),
            ),
          ),
          where: (b) => b.id.equals(row.id),
        );
      }
    });
  }

  Future<List<td.Message>> _savedMessagesPage(int chatId, int from) async {
    try {
      final res = await _tdlib.sendRequest(
        td.GetChatHistory(
          chatId: chatId,
          fromMessageId: from,
          offset: 0,
          limit: _restorePageSize,
          onlyLocal: false,
        ),
      );
      return res is td.Messages ? res.messages : const [];
    } catch (e) {
      debugPrint('[FeedRepo] Saved Messages page failed: $e');
      return const [];
    }
  }

  /// The channel post a saved copy was forwarded from, or null if it isn't a
  /// forward from a channel with a message id.
  @visibleForTesting
  static ({int chatId, int messageId})? bookmarkOriginOf(td.Message message) {
    final origin = message.forwardInfo?.origin;
    if (origin is! td.MessageOriginChannel) return null;
    if (origin.messageId <= 0) return null;
    return (chatId: origin.chatId, messageId: origin.messageId);
  }

  Future<bool> isBookmarked(int chatId, int messageId) async {
    final existing =
        await (_db.select(_db.bookmarkEntries)..where(
              (b) => b.chatId.equals(chatId) & b.messageId.equals(messageId),
            ))
            .getSingleOrNull();
    return existing != null;
  }

  Future<Post?> fetchSinglePost(int chatId, int messageId) async {
    final chat = await _resolveChat(chatId);
    if (chat == null) return null;

    final cached = await _messageById(chatId, messageId);
    if (cached != null) return _postFrom(cached, chat);

    // Ask the server for a window around the message. With offset 0
    // `GetChatHistory` returns only older messages; -1 includes the anchor.
    try {
      final res = await _tdlib.sendRequest(
        td.GetChatHistory(
          chatId: chatId,
          fromMessageId: messageId,
          offset: -1,
          limit: 3,
          onlyLocal: false,
        ),
      );
      if (res is td.Messages) {
        for (final message in res.messages) {
          if (message.id == messageId) return await _postFrom(message, chat);
        }
      }
    } catch (e) {
      debugPrint('[FeedRepo] fetchSinglePost history fallback failed: $e');
    }

    // The window fetch stores the message locally even if it wasn't returned.
    final afterFetch = await _messageById(chatId, messageId);
    return afterFetch == null ? null : _postFrom(afterFetch, chat);
  }

  /// Reads one message, or null if TDLib doesn't have it (it returns id 0).
  Future<td.Message?> _messageById(int chatId, int messageId) async {
    try {
      final res = await _tdlib.sendRequest(
        td.GetMessages(chatId: chatId, messageIds: [messageId]),
      );
      if (res is! td.Messages || res.messages.isEmpty) return null;
      final message = res.messages.first;
      return message.id == messageId ? message : null;
    } catch (e) {
      debugPrint('[FeedRepo] GetMessages failed for $chatId/$messageId: $e');
      return null;
    }
  }

  /// Finds a chat, using `CreateSupergroupChat` when `GetChat` fails, as it can
  /// for a public channel the user isn't in.
  Future<td.Chat?> _resolveChat(int chatId) async {
    final cached = _chatCache.chat(chatId);
    if (cached != null) return cached;

    try {
      final res = await _tdlib.sendRequest(td.GetChat(chatId: chatId));
      if (res is td.Chat) return res;
    } catch (_) {
      // Fall through to the supergroup path.
    }

    final supergroupId = TelegramIds.supergroupId(chatId);
    if (supergroupId == null) return null;

    try {
      final res = await _tdlib.sendRequest(
        td.CreateSupergroupChat(supergroupId: supergroupId, force: false),
      );
      return res is td.Chat ? res : null;
    } catch (e) {
      debugPrint('[FeedRepo] Could not resolve chat $chatId: $e');
      return null;
    }
  }

  Future<Post?> _postFrom(td.Message message, td.Chat chat) async {
    final posts = TdlibMappers.mergeAlbumMessages(
      [message],
      chat,
      bookmarkedKeys: await _bookmarkKeys(),
    );
    return posts.isEmpty ? null : posts.first;
  }

  /// The bookmarked posts, most recently bookmarked first, and which of them
  /// were restored from Saved Messages.
  Future<({List<Post> posts, Set<String> restoredIds})> loadBookmarks() async {
    await _resolveRestoredFlags();
    final bookmarks = await _db.select(_db.bookmarkEntries).get();
    if (bookmarks.isEmpty) return (posts: <Post>[], restoredIds: <String>{});

    final bookmarkKeys = {
      for (final b in bookmarks) '${b.chatId}_${b.messageId}',
    };
    final bookmarkedAt = {
      for (final b in bookmarks) '${b.chatId}_${b.messageId}': b.createdAt,
    };
    final restoredIds = {
      for (final b in bookmarks)
        if (b.isRestored == true) '${b.chatId}_${b.messageId}',
    };

    final messagesByChatId = <int, List<int>>{};
    for (final b in bookmarks) {
      messagesByChatId.putIfAbsent(b.chatId, () => []).add(b.messageId);
    }

    final posts = <Post>[];
    for (final entry in messagesByChatId.entries) {
      // Restored bookmarks can be from channels the user doesn't follow, so
      // the chat may need looking up; it used to be skipped.
      final chat = await _resolveChat(entry.key);
      if (chat == null) continue;
      try {
        final res = await _tdlib.sendRequest(
          td.GetMessages(chatId: entry.key, messageIds: entry.value),
        );
        if (res is! td.Messages) continue;
        posts.addAll(
          TdlibMappers.mergeAlbumMessages(
            res.messages.whereType<td.Message>().toList(),
            chat,
            bookmarkedKeys: bookmarkKeys,
          ),
        );
      } catch (e) {
        debugPrint('[FeedRepo] Bookmarks in chat ${entry.key} failed: $e');
      }
    }

    // As X lists them: by when they were bookmarked, then by date.
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    posts.sort((a, b) {
      final byBookmark = (bookmarkedAt[b.id] ?? epoch).compareTo(
        bookmarkedAt[a.id] ?? epoch,
      );
      return byBookmark != 0
          ? byBookmark
          : b.publishedAt.compareTo(a.publishedAt);
    });
    return (posts: posts, restoredIds: restoredIds);
  }

  /// Marks a post as read. [forceRead] writes the read state even though the
  /// chat isn't open; pass false while it is open.
  Future<void> markPostAsRead(String postId, {bool forceRead = true}) async {
    final parts = postId.split('_');
    if (parts.length != 2) return;
    final chatId = int.tryParse(parts[0]);
    final messageId = int.tryParse(parts[1]);
    if (chatId == null || messageId == null) return;

    await markMessagesRead(
      chatId: chatId,
      messageIds: [messageId],
      forceRead: forceRead,
    );
  }

  /// The messages of [chatId] the read cursor can move over: the unbroken
  /// seen run above it, oldest first. Empty if any unread message is unseen
  /// or not on the device. See [readableUpTo].
  Future<List<int>> readableRun(int chatId, Set<int> seen) async {
    final chat = _chatCache.chat(chatId);
    if (chat == null) return seen.toList()..sort();
    final cursor = chat.lastReadInboxMessageId;
    if (!seen.any((id) => id > cursor)) return const [];

    final unread = await _unreadMessages(chat);
    if (unread == null) return const [];
    final upTo = readableUpTo(cursor: cursor, unread: unread, seen: seen);
    return [
      for (final message in unread)
        if (message.id > cursor && message.id <= upTo) message.id,
    ];
  }

  /// Every message above [chat]'s read cursor, oldest first, or null if they
  /// aren't all stored locally.
  Future<List<UnreadMessage>?> _unreadMessages(td.Chat chat) async {
    final count = chat.unreadCount;
    if (count == 0) return const [];
    if (count >= 100) return null;

    final cursor = chat.lastReadInboxMessageId;
    final List<td.Message> messages;
    try {
      final res = await _tdlib.sendRequest(
        td.GetChatHistory(
          chatId: chat.id,
          fromMessageId: 0,
          offset: 0,
          limit: count + 1,
          onlyLocal: true,
        ),
      );
      if (res is! td.Messages) return null;
      messages = res.messages;
    } catch (e) {
      debugPrint('[FeedRepo] Unread lookup failed for ${chat.id}: $e');
      return null;
    }

    final above = [
      for (final message in messages)
        if (message.id > cursor) message,
    ];
    final reachedCursor = above.length < messages.length;
    final incoming = above.where((m) => !m.isOutgoing).length;
    if (!reachedCursor && incoming < count) return null;

    return [
      for (final message in above.reversed)
        (
          id: message.id,
          albumId: message.mediaAlbumId.toInt(),
          isShown:
              !message.isOutgoing &&
              MessageContentSupport.belongsInFeed(message.content),
        ),
    ];
  }

  /// Marks messages as read, returning null or the error to log. The caller
  /// ([ReadReceiptQueue]) retries.
  Future<String?> markMessagesRead({
    required int chatId,
    required List<int> messageIds,
    bool forceRead = true,
  }) async {
    if (messageIds.isEmpty) return null;

    try {
      final result = await _tdlib.sendRequest(
        td.ViewMessages(
          chatId: chatId,
          messageIds: messageIds,
          source: const td.MessageSourceChatHistory(),
          forceRead: forceRead,
        ),
      );
      if (result is td.Ok) return null;
      return 'TDLib answered ${result.runtimeType}';
    } catch (e) {
      return e.toString();
    }
  }

  /// Tells TDLib the user opened a chat, which turns on live view and reaction
  /// counts. Returns whether TDLib acknowledged it, since a `forceRead: false`
  /// ack for a chat it doesn't consider open is silently ignored.
  Future<bool> openChat(int chatId) async {
    try {
      final result = await _tdlib.sendRequest(td.OpenChat(chatId: chatId));
      return result is td.Ok;
    } catch (e) {
      debugPrint('[FeedRepo] openChat error: $e');
      return false;
    }
  }

  Future<void> closeChat(int chatId) async {
    try {
      await _tdlib.sendRequest(td.CloseChat(chatId: chatId));
    } catch (e) {
      debugPrint('[FeedRepo] closeChat error: $e');
    }
  }

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
    // Fallback when all reactions are allowed. Keys as TDLib spells them:
    // the heart has no U+FE0F.
    return ['👍', '\u2764', '🔥', '🥰', '👏'];
  }

  /// Fetches a channel post's comments.
  Future<List<Post>> fetchPostComments(int chatId, int messageId) async {
    try {
      final res = await _tdlib.sendRequest(
        td.GetMessageThreadHistory(
          chatId: chatId,
          messageId: messageId,
          fromMessageId: 0,
          offset: 0,
          limit: 50,
        ),
      );

      if (res is td.Messages && res.messages.isNotEmpty) {
        // Map against the discussion group the comments are in, not the
        // channel, or reactions and replies target the wrong chat.
        final threadChatId = res.messages.first.chatId;
        var chatObj = _chatCache.chat(threadChatId);
        if (chatObj == null) {
          final fetched = await _tdlib.sendRequest(
            td.GetChat(chatId: threadChatId),
          );
          if (fetched is td.Chat) chatObj = fetched;
        }
        if (chatObj == null) return [];

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

        final userResults = await Future.wait(
          userIds.map((id) => _tdlib.sendRequest(td.GetUser(userId: id))),
        );
        final chatResults = await Future.wait(
          chatIds.map((id) => _tdlib.sendRequest(td.GetChat(chatId: id))),
        );

        // One whole entry per sender, so a missing photo never falls back to
        // the channel's avatar.
        final senders = <String, PostSender>{};

        for (final r in userResults) {
          if (r is td.User) {
            final photo = r.profilePhoto;
            if (photo != null) {
              _syncService.downloadFileWithPriority(photo.small.id);
            }
            senders['user_${r.id}'] = PostSender(
              userId: r.id,
              title: TdlibMappers.userDisplayName(r),
              username: r.usernames?.activeUsernames.firstOrNull,
              avatarPath: _photoPath(photo?.small),
              avatarFileId: photo?.small.id,
            );
          }
        }

        for (final r in chatResults) {
          if (r is td.Chat) {
            final photo = r.photo;
            if (photo != null) {
              _syncService.downloadFileWithPriority(photo.small.id);
            }
            senders['chat_${r.id}'] = PostSender(
              senderChatId: r.id,
              title: r.title,
              avatarPath: _photoPath(photo?.small),
              avatarFileId: photo?.small.id,
            );
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

          posts.add(
            TdlibMappers.mapMessageToPost(m, chatObj, sender: senders[key]),
          );
        }

        return posts;
      }
    } catch (e) {
      debugPrint('[FeedRepo] Failed to fetch comments thread: $e');
    }
    return [];
  }

  /// A downloaded photo's path, or a remote id the loader can resolve later.
  static String? _photoPath(td.File? file) {
    if (file == null) return null;
    if (file.local.path.isNotEmpty) return file.local.path;
    if (file.remote.id.isNotEmpty) return file.remote.id;
    return null;
  }

  static const _commentSendOptions = td.MessageSendOptions(
    disableNotification: false,
    fromBackground: false,
    protectContent: false,
    updateOrderOfInstalledStickerSets: false,
    effectId: 0,
    sendingId: 0,
    onlyPreview: false,
  );

  /// Posts a comment into a post's discussion thread, built by
  /// [ComposeMessages] with the same rules as posts.
  Future<void> sendComment(
    int chatId,
    int messageId,
    String text, {
    int? replyToMessageId,
    List<ComposeAttachment> attachments = const [],
    ComposeRemoteMedia? remote,
  }) async {
    try {
      int targetChatId = chatId;
      int targetThreadId = messageId;

      final threadInfo = await _tdlib.sendRequest(
        td.GetMessageThread(chatId: chatId, messageId: messageId),
      );
      if (threadInfo is td.MessageThreadInfo) {
        targetChatId = threadInfo.chatId;
        targetThreadId = threadInfo.messageThreadId;
      }

      final replyTo = td.InputMessageReplyToMessage(
        messageId: replyToMessageId ?? targetThreadId,
      );

      // `clearDraft: false` keeps any draft in the discussion group.
      if (attachments.isEmpty && remote == null) {
        await _tdlib.sendRequest(
          td.SendMessage(
            chatId: targetChatId,
            messageThreadId: targetThreadId,
            replyTo: replyTo,
            options: _commentSendOptions,
            inputMessageContent: td.InputMessageText(
              text: td.FormattedText(text: text, entities: []),
              clearDraft: false,
            ),
          ),
        );
        return;
      }

      final contents = ComposeMessages.build(
        text: text,
        attachments: attachments,
        remote: remote,
      );

      if (ComposeMessages.isAlbum(contents)) {
        await _tdlib.sendRequest(
          td.SendMessageAlbum(
            chatId: targetChatId,
            messageThreadId: targetThreadId,
            replyTo: replyTo,
            options: _commentSendOptions,
            inputMessageContents: contents,
          ),
        );
        return;
      }

      await _tdlib.sendRequest(
        td.SendMessage(
          chatId: targetChatId,
          messageThreadId: targetThreadId,
          replyTo: replyTo,
          options: _commentSendOptions,
          inputMessageContent: contents.first,
        ),
      );
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
