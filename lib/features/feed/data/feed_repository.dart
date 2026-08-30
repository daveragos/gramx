import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/core/telegram/telegram_ids.dart';
import 'package:gramx/features/compose/data/compose_repository.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/compose_remote_media.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/domain/post_sender.dart';
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
  /// raise one without the other.
  static const int backfillTopChannels = 30;

  /// Gap between backfill requests. Just over one second keeps us under the cap
  /// with headroom for the requests the user's own taps generate.
  static const Duration backfillThrottle = Duration(milliseconds: 1100);

  /// How many times opening a channel will ask the server for more history
  /// before giving up on filling the first page.
  ///
  /// TDLib chooses its own batch size and can answer with one message while
  /// plenty of history remains, so one request is not a page. Bounded because
  /// even a user-driven path shares the account's request budget.
  static const int channelHistoryMaxRequests = 4;

  /// Channels the unread sweep looks behind the read cursor for.
  ///
  /// Shares the budget with [backfillTopChannels] and runs after it: one
  /// request at a time at [backfillThrottle], abandoned on the first
  /// rate-limit. A bounded, throttled sweep — not a fan-out.
  static const int unreadSweepTopChannels = 30;

  /// Unread posts lifted per channel per sweep.
  ///
  /// Small on purpose: a backlog is read a few posts at a time, and one
  /// channel sitting on four hundred unread must not become the feed.
  static const int unreadPerChannel = 5;

  /// Channels one "load older" page will reach back into. Pagination is a
  /// user-driven path, but it repeats on every scroll to the bottom, so it is
  /// bounded too.
  static const int paginationChannelsPerPage = 10;

  /// Cap on how many unknown forwarded-from channels we will name per feed
  /// build. Bounded so a feed full of forwards can't become a fan-out.
  static const int _maxForwardLookups = 10;

  FeedRepository(this._tdlib, this._db, this._syncService, this._chatCache);

  /// Picks the channels whose oldest loaded post is newest.
  ///
  /// Those are the only ones that can extend a merged feed backwards — every
  /// other channel already reaches further back than the current frontier, so
  /// paging it adds nothing the user would see.
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

  /// Reads a chat's history from TDLib's local database only.
  ///
  /// `onlyLocal: true` never reaches the server, so this is outside the flood
  /// budget and safe to run across every channel at once. It can legitimately
  /// return nothing on a cold cache.
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

  /// Builds the merged feed with **no per-channel network requests**.
  ///
  /// Two cheap phases: the chat cache's `lastMessage` (already delivered by the
  /// update stream, so free) and a local-only history read (never touches the
  /// server). Real history for the busiest channels arrives afterwards via
  /// [backfillRecentHistory], which is throttled.
  ///
  /// This deliberately does not call `GetChat` or a networked `GetChatHistory`
  /// per channel. Doing so over a 200-channel list is an instant account-global
  /// FLOOD_WAIT.
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
      channelChats.map(
        (chat) => _localHistory(chat.id, limit: postsPerChannel),
      ),
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
        final res = await _tdlib.sendRequest(
          td.GetChatHistory(
            chatId: chat.id,
            fromMessageId: 0,
            offset: 0,
            limit: postsPerChannel,
            onlyLocal: false,
          ),
        );
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

  /// Unread posts behind each channel's read cursor that TDLib already holds.
  ///
  /// Local-only, so it costs nothing and is off the request budget entirely —
  /// which is the point: the feed's first paint can carry a real mix of old
  /// unread posts without waiting on a single network round trip. The
  /// networked [fetchUnreadBacklog] runs later and goes deeper.
  ///
  /// A cold cache legitimately answers with nothing; that is not an error, it
  /// just means the mix arrives with the throttled sweep instead.
  Future<List<Post>> fetchCachedUnreadBacklog() async {
    final targets = _chatCache.channels
        .where((chat) => chat.unreadCount > 0)
        .take(unreadSweepTopChannels)
        .toList();
    if (targets.isEmpty) return const [];

    final histories = await Future.wait(
      targets.map((chat) => _localUnread(chat)),
    );

    final messagesByChatId = <int, List<td.Message>>{};
    for (var i = 0; i < targets.length; i++) {
      if (histories[i].isEmpty) continue;
      messagesByChatId[targets[i].id] = _dedupeMessages(histories[i]);
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
          // A negative offset from the read cursor is TDLib's way of saying "the
          // messages after this one" — the oldest unread rather than the newest.
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

  /// The oldest unread posts sitting behind each channel's read cursor.
  ///
  /// The feed is newest-first, so a channel's older unread posts are only
  /// reachable by scrolling past everything newer — which nobody does, and the
  /// backlog only grows. This lifts a few of them out per channel so the feed
  /// can weave them in; see `buildFeedEntries`.
  ///
  /// Same budget shape as [backfillRecentHistory]: the busiest channels only,
  /// one request at a time, abandoned on the first rate-limit. Channels with
  /// nothing unread cost nothing — they are never requested.
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
            // From the read cursor, with a negative offset: TDLib reads that as
            // "the messages *after* this one", which is precisely the oldest
            // unread. Asking from 0 returns the newest, which the feed already
            // has.
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

  /// Loads one page of older posts, reaching back into a bounded set of channels.
  ///
  /// Only the channels whose oldest loaded post is *newest* can extend the
  /// merged feed backwards — the others already reach further back than the
  /// current frontier. Fetching just those keeps a scroll-to-bottom at
  /// [paginationChannelsPerPage] requests instead of one per subscription.
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

  /// Looks up the messages that posts in this batch are replying to.
  ///
  /// TDLib only inlines `replyTo.content` for cross-chat replies and quotes, so
  /// a reply inside one channel arrives with no preview text — the card fell
  /// back to the words "Original post", which say nothing about the post.
  ///
  /// `GetMessages` takes a list, so this is one request per chat regardless of
  /// how many replies it holds, and it reads local data in the common case.
  Future<Map<String, String>> _resolveReplyExcerpts(
    Map<int, List<td.Message>> messagesByChatId,
  ) async {
    final wanted = <int, Set<int>>{};

    for (final entry in messagesByChatId.entries) {
      for (final message in entry.value) {
        final replyTo = message.replyTo;
        if (replyTo is! td.MessageReplyToMessage) continue;
        // Already inlined by TDLib, or the user quoted specific text.
        if (replyTo.content != null || replyTo.quote != null) continue;
        if (replyTo.messageId == 0) continue;
        wanted.putIfAbsent(entry.key, () => {}).add(replyTo.messageId);
      }
    }

    if (wanted.isEmpty) return const {};

    final excerpts = <String, String>{};
    for (final entry in wanted.entries) {
      try {
        final res = await _tdlib.sendRequest(
          td.GetMessages(chatId: entry.key, messageIds: entry.value.toList()),
        );
        if (res is! td.Messages) continue;
        for (final message in res.messages) {
          // GetMessages answers with an id of 0 for anything it doesn't have.
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
    }
    return excerpts;
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

    // Name the channels a post points at — the one it was forwarded from, and
    // the one a reply or a quote came out of. Both used to be one list; only
    // forwards were on it, so a passage quoted from another channel had no
    // name for its author and the mapper fell back to the channel doing the
    // quoting, putting the wrong byline over somebody else's words.
    //
    // The cache answers most of these for free; only genuinely unknown chats
    // cost a request, and that is capped. See docs/TDLIB.md.
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

    for (final id in unresolved.take(_maxForwardLookups)) {
      try {
        final res = await _tdlib.sendRequest(td.GetChat(chatId: id));
        if (res is td.Chat) knownChatTitles[res.id] = res.title;
      } catch (_) {
        // A private or deleted origin channel; the card falls back to the
        // author signature.
      }
    }

    final replyExcerpts = await _resolveReplyExcerpts(messagesByChatId);

    final posts = <Post>[];
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
    }

    posts.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return posts;
  }

  /// Maps messages already in hand into posts for one known chat.
  ///
  /// Unlike [mapIncomingMessages] this does **not** filter by subscription:
  /// the caller has a specific chat open and asked for these messages, so a
  /// channel the reader is browsing without having joined still renders. Costs
  /// nothing beyond the bookmark lookup and whatever forwarded-origin names
  /// are not already cached.
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

  /// Fetch posts for a single channel (local-first fallback).
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

    // Local history first, for an instant first paint.
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

    // Then keep asking the server until there is a real page.
    //
    // `GetChatHistory` is documented to return **fewer messages than
    // requested even when the history has not ended** — TDLib picks the batch
    // size. Asking once and rendering whatever came back is why opening a
    // channel could land on a single post with nothing to scroll to, and
    // therefore nothing to trigger pagination either: a dead end.
    //
    // Bounded and user-driven, which is what the request budget allows for
    // opening a specific channel — never a fan-out over the chat list.
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

      // Nothing new means the end of the history, not a slow batch.
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
      final res = await _tdlib.sendRequest(
        td.SearchMessages(
          chatList: const td.ChatListMain(),
          onlyInChannels: true,
          query: trimmed,
          offset: '',
          limit: searchPageSize,
          minDate: 0,
          maxDate: 0,
        ),
      );

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
      // Membership matters here too: TDLib streams updates for chats it merely
      // knows about, and those must not reach the feed.
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
  ///
  /// This is what the repeat icon should always have done — it displayed
  /// `forwardCount` while being wired to "copy a link".
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
          // Forward with attribution rather than silently copying the content.
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

  /// Chats a post can be forwarded into, most recently active first.
  ///
  /// Read straight from the cache, so opening the picker costs no requests.
  /// Where a post can be forwarded to.
  ///
  /// Only chats this account can actually post into — see
  /// `ChatCacheState.canPostIn`. Listing every subscribed channel offered
  /// destinations that would always fail.
  List<td.Chat> forwardTargets() => _chatCache.forwardTargets;

  /// A shareable t.me link for a post.
  ///
  /// Asks TDLib for the canonical link first — it knows about usernames,
  /// albums and thread context. Falls back to building one locally if the
  /// request fails, so sharing still works offline or for a channel TDLib
  /// declines to link.
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

  /// Toggle bookmark using chatId + messageId.
  ///
  /// The local row is the index; **Saved Messages is the copy that lasts.** A
  /// bookmark used to be a Drift row and nothing else, so reinstalling the app
  /// — or signing in on a second device — lost every one of them. Telegram's
  /// own durable save is a forward to Saved Messages, so that is what this
  /// writes, and [restoreBookmarks] is what reads it back.
  ///
  /// The mirror is best-effort. A tap while offline, or while rate limited,
  /// still bookmarks locally and simply has no saved copy; it is not queued
  /// and not retried, because a bookmark is not worth a queue. What that costs
  /// is one bookmark missing from a restore, which is better than a tap that
  /// appears to do nothing.
  Future<void> toggleBookmark(int chatId, int messageId) async {
    final existing =
        await (_db.select(_db.bookmarkEntries)..where(
              (b) => b.chatId.equals(chatId) & b.messageId.equals(messageId),
            ))
            .getSingleOrNull();

    if (existing != null) {
      await (_db.delete(_db.bookmarkEntries)..where(
            (b) => b.chatId.equals(chatId) & b.messageId.equals(messageId),
          ))
          .go();
      await _removeSavedCopy(existing.savedMessageId);
      return;
    }

    final accountId = (await _activeAccount())?.id ?? 1;

    // Written before the local row, so the row is stored with its handle
    // rather than needing a second write to attach one.
    final savedMessageId = await _writeSavedCopy(chatId, messageId);

    await _db
        .into(_db.bookmarkEntries)
        .insert(
          BookmarkEntriesCompanion.insert(
            accountId: accountId,
            chatId: chatId,
            messageId: messageId,
            savedMessageId: Value(savedMessageId),
          ),
        );
  }

  /// The signed-in account's row, which is also where the reader's own
  /// Telegram user id lives.
  Future<Account?> _activeAccount() async {
    final accounts = await (_db.select(
      _db.accounts,
    )..where((a) => a.isActive.equals(true))).get();
    return accounts.isEmpty ? null : accounts.first;
  }

  /// This account's Saved Messages chat, or null when there is no account.
  ///
  /// Telegram models notes-to-self as a private chat with yourself, so the
  /// chat id *is* the user id — once the chat exists. On a fresh account it
  /// does not, which is why this can have to create it.
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

  /// Forwards a post into Saved Messages, answering the copy's id.
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
            // A note to yourself should not buzz your own phone.
            disableNotification: true,
            fromBackground: true,
            protectContent: false,
            updateOrderOfInstalledStickerSets: false,
            effectId: 0,
            sendingId: 0,
            onlyPreview: false,
          ),
          // Attribution is the whole point: the copy has to say where it came
          // from, because that is what a restore reads to find the original.
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

  /// Deletes a bookmark's copy out of Saved Messages.
  Future<void> _removeSavedCopy(int? savedMessageId) async {
    if (savedMessageId == null) return;
    final saved = await _savedMessagesChatId();
    if (saved == null) return;

    try {
      await _tdlib.sendRequest(
        td.DeleteMessages(
          chatId: saved,
          messageIds: [savedMessageId],
          // Saved Messages is a chat with yourself; there is no other side for
          // a copy to be left on.
          revoke: true,
        ),
      );
    } catch (e) {
      debugPrint('[FeedRepo] Could not remove the saved copy: $e');
    }
  }

  /// How far back a restore reads.
  ///
  /// Paged like any history read, and bounded: Saved Messages is also where a
  /// reader keeps everything else they have ever sent themselves, and walking
  /// all of it to find bookmarks would be a fan-out with extra steps.
  static const int _restorePages = 8;
  static const int _restorePageSize = 100;

  /// Rebuilds the local bookmark rows from Saved Messages.
  ///
  /// This is what makes a bookmark survive a reinstall. Every mirror carries
  /// `forwardInfo`, and a channel origin names the chat and the message it came
  /// from — which is exactly the pair a bookmark is.
  ///
  /// Existing rows are left alone, so running this twice adds nothing and
  /// running it after deleting a bookmark does not bring that bookmark back:
  /// unbookmarking deletes the mirror too, so there is nothing to find.
  ///
  /// Answers how many bookmarks it added.
  Future<int> restoreBookmarks() async {
    final saved = await _savedMessagesChatId();
    if (saved == null) return 0;

    final accountId = (await _activeAccount())?.id ?? 1;
    final known = await _bookmarkKeys();
    var added = 0;
    var fromMessageId = 0;

    for (var page = 0; page < _restorePages; page++) {
      final messages = await _savedMessagesPage(saved, fromMessageId);
      if (messages.isEmpty) break;

      for (final message in messages) {
        final origin = bookmarkOriginOf(message);
        if (origin == null) continue;
        if (!known.add('${origin.chatId}_${origin.messageId}')) continue;

        await _db
            .into(_db.bookmarkEntries)
            .insert(
              BookmarkEntriesCompanion.insert(
                accountId: accountId,
                chatId: origin.chatId,
                messageId: origin.messageId,
                savedMessageId: Value(message.id),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        added++;
      }

      fromMessageId = messages.last.id;
    }

    return added;
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

  /// The channel post a saved copy was forwarded from, if it was one.
  ///
  /// Pure, and the part worth testing: Saved Messages holds everything a reader
  /// has ever sent themselves, and only a forward *from a channel* with a
  /// message id behind it is a bookmark. A note typed to yourself, a forward
  /// from a person, and a channel origin with no message id all answer null —
  /// the last of those is a forward Telegram could not attribute precisely,
  /// which is not enough to find a post with.
  @visibleForTesting
  static ({int chatId, int messageId})? bookmarkOriginOf(td.Message message) {
    final origin = message.forwardInfo?.origin;
    if (origin is! td.MessageOriginChannel) return null;
    if (origin.messageId <= 0) return null;
    return (chatId: origin.chatId, messageId: origin.messageId);
  }

  /// Check if a post is bookmarked.
  Future<bool> isBookmarked(int chatId, int messageId) async {
    final existing =
        await (_db.select(_db.bookmarkEntries)..where(
              (b) => b.chatId.equals(chatId) & b.messageId.equals(messageId),
            ))
            .getSingleOrNull();
    return existing != null;
  }

  /// Fetch a single post by chatId and messageId via TDLib GetMessages.
  Future<Post?> fetchSinglePost(int chatId, int messageId) async {
    final chat = await _resolveChat(chatId);
    if (chat == null) return null;

    // Local first — free, and usually enough for a post already in the feed.
    final cached = await _messageById(chatId, messageId);
    if (cached != null) return _postFrom(cached, chat);

    // Not cached. Ask the server for a window *around* the message.
    //
    // `GetChatHistory` with offset 0 returns messages strictly older than the
    // anchor, so the message asked for is never in the result — the old
    // fallback could not succeed, and a perfectly reachable public post
    // reported itself as private. A negative offset includes the anchor.
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

    // One more try at the direct read: the window fetch above will have pulled
    // the message into TDLib's local store even if it wasn't in the reply.
    final afterFetch = await _messageById(chatId, messageId);
    return afterFetch == null ? null : _postFrom(afterFetch, chat);
  }

  /// Reads one message, or null if TDLib doesn't have it.
  ///
  /// `GetMessages` answers with a placeholder whose id is 0 rather than an
  /// error when a message isn't cached, so the id has to be checked.
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

  /// Finds a chat, teaching TDLib about it if it only knows the id.
  ///
  /// A forwarded post's origin is often a channel the user isn't in, so the
  /// cache misses and `GetChat` alone can fail. `CreateSupergroupChat` makes a
  /// public channel resolvable; a genuinely private one still fails, which is
  /// the case the UI reports honestly.
  Future<td.Chat?> _resolveChat(int chatId) async {
    final cached = _chatCache.chat(chatId);
    if (cached != null) return cached;

    try {
      final res = await _tdlib.sendRequest(td.GetChat(chatId: chatId));
      if (res is td.Chat) return res;
    } catch (_) {
      // Falls through to the supergroup path below.
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

  /// Fetch all bookmarked posts stored in the local SQLite database.
  Future<List<Post>> fetchBookmarkedPosts() async {
    final bookmarks = await _db.select(_db.bookmarkEntries).get();
    if (bookmarks.isEmpty) return [];

    final bookmarkKeys = bookmarks
        .map((b) => '${b.chatId}_${b.messageId}')
        .toSet();

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

        final res = await _tdlib.sendRequest(
          td.GetMessages(chatId: chatId, messageIds: messageIds),
        );

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
        debugPrint(
          '[FeedRepo] Failed to fetch bookmarked messages for chat $chatId: $e',
        );
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

    await markMessagesRead(
      chatId: chatId,
      messageIds: [messageId],
      forceRead: forceRead,
    );
  }

  /// Acknowledges messages as read, and reports what went wrong.
  ///
  /// Returns null on success, or the error to log. Read acks used to be
  /// fire-and-forget: a flood wait or a moment offline lost them silently, and
  /// the reader's Telegram kept showing everything unread with nothing to
  /// explain it. The caller ([ReadReceiptQueue]) retries.
  ///
  /// The source is stated rather than left for TDLib to infer from whether the
  /// chat happens to be open. Read state is exactly the thing that must not
  /// depend on a guess.
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

  /// Notify TDLib that the user has opened a chat.
  ///
  /// Required for unread tracking across clients, and for interaction info —
  /// views and reactions only stream for open chats (docs/TDLIB.md).
  ///
  /// Returns whether TDLib actually acknowledged it. The caller needs that: a
  /// read acknowledgement sent with `forceRead: false` against a chat TDLib
  /// does not yet consider open is quietly declined, and `ViewMessages` still
  /// answers `Ok`, so nothing retries it. See [ReadReceiptQueue].
  Future<bool> openChat(int chatId) async {
    try {
      final result = await _tdlib.sendRequest(td.OpenChat(chatId: chatId));
      return result is td.Ok;
    } catch (e) {
      debugPrint('[FeedRepo] openChat error: $e');
      return false;
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

        // One entry per sender, built whole. Three parallel maps keyed by a
        // string used to leave a commenter with a name but no photo falling
        // back to the *channel's* avatar for the missing half — which is why
        // people's comments sometimes showed up wearing the channel's face.
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

  /// A downloaded photo's path, or something the loader can resolve later.
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

  /// Posts a comment into a post's discussion thread.
  ///
  /// A comment can now carry what a post can: pictures, a video, a sticker or
  /// a GIF out of the account's own collection. The content objects come from
  /// [ComposeMessages] rather than being built here, which is the whole reason
  /// that class is pure and separate — the rules about captions, albums and
  /// what a sticker may not carry are decided in one place, and a comment
  /// obeys the same ones a post does.
  ///
  /// Two requests at most: one `GetMessageThread` to find where comments
  /// actually live, and one send. Both are a direct consequence of somebody
  /// pressing a button.
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

      // Words alone stay on the path they were always on, including
      // `clearDraft: false` — the discussion group may hold a draft of its own
      // that a comment posted from here has no business wiping.
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
