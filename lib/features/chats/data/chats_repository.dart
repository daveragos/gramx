import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/core/navigation/deep_link_handler.dart';
import 'package:gramx/features/chats/data/chat_list_builder.dart';
import 'package:gramx/features/chats/data/chat_message_mapper.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/data/user_profile_mapper.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/features/chats/domain/message_schedule.dart';
import 'package:gramx/features/chats/domain/user_profile.dart';
import 'package:gramx/features/compose/data/compose_repository.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/compose_remote_media.dart';
import 'package:gramx/features/compose/domain/poll_draft.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// What the long-press menu may offer for one message.
typedef MessageActions = ({
  bool canEdit,
  bool canDeleteForSelf,
  bool canDeleteForAll,
  bool canReply,
  bool canForward,
  bool canCopy,

  /// Whether Telegram allows pinning this message, per `getMessageProperties`.
  bool canPin,
});

/// Nothing allowed. Used when TDLib could not be asked, so the menu never
/// offers an action that would fail.
extension MessageActionsNone on MessageActions {
  static const MessageActions none = (
    canEdit: false,
    canDeleteForSelf: false,
    canDeleteForAll: false,
    canReply: false,
    canForward: false,
    canCopy: false,
    canPin: false,
  );
}

/// A page of history, and whether it reached the top of the chat. TDLib picks
/// its own batch size, so a short page doesn't mean the top was reached.
typedef HistoryPage = ({List<ChatMessage> messages, bool reachedTop});

/// A stretch of history that may end short of the newest message, such as
/// the messages around a search hit.
typedef HistoryWindow = ({
  List<ChatMessage> messages,
  bool reachedTop,
  bool reachedBottom,
});

/// Everything a conversation does that reaches Telegram. Every request here is
/// user-driven and bounded; never issue one per chat in the list.
class ChatsRepository {
  final TdlibService _tdlib;
  final ChatCache _chatCache;

  ChatsRepository(this._tdlib, this._chatCache);

  /// How many messages one history page asks for. TDLib may answer with fewer.
  static const int historyPageSize = 40;

  /// How many requests one page may make. `GetChatHistory` often returns fewer
  /// messages than asked, so a page asks again from the oldest id it got.
  static const int historyMaxRequests = 3;

  /// The chat list, straight from the cache.
  List<ChatSummary> chatList({int? selfUserId}) => ChatListBuilder.build(
    _chatCache.conversations,
    users: _chatCache.usersById,
    supergroups: _chatCache.supergroupsById,
    selfUserId: selfUserId,
    userFullInfos: _chatCache.userFullInfosById,
    chatsById: _chatCache.chatsById,
    secretChats: _chatCache.secretChatsById,
  );

  /// One chat's row, or null if the cache doesn't know it.
  ChatSummary? summary(int chatId, {int? selfUserId}) {
    final chat = _chatCache.chat(chatId);
    if (chat == null) return null;
    return ChatListBuilder.summaryFor(
      chat,
      users: _chatCache.usersById,
      supergroups: _chatCache.supergroupsById,
      selfUserId: selfUserId,
      userFullInfos: _chatCache.userFullInfosById,
      chatsById: _chatCache.chatsById,
      secretChats: _chatCache.secretChatsById,
    );
  }

  /// Whether bubbles in this chat carry a sender name.
  bool isGroupChat(int chatId) {
    final chat = _chatCache.chat(chatId);
    if (chat == null) return false;
    return chat.type is! td.ChatTypePrivate;
  }

  /// Whether this is a `chatTypePrivate`, the only chat type Telegram accepts
  /// a self-destruct timer in. Secret chats are not.
  bool isPrivateChat(int chatId) =>
      _chatCache.chat(chatId)?.type is td.ChatTypePrivate;

  /// Whether a poll may be sent into this chat. Telegram refuses them in
  /// private chats with people and wherever the chat's rights forbid them.
  bool canSendPollsIn(int chatId) {
    final chat = _chatCache.chat(chatId);
    if (chat == null) return false;
    return ChatCacheState.canSendPollsIn(
      chat,
      _chatCache.supergroupForChat(chat),
    );
  }

  /// Whether one kind of content may be sent into this chat. The composer
  /// checks it per control.
  bool canSendIn(int chatId, ChatSendRight right) {
    final chat = _chatCache.chat(chatId);
    if (chat == null) return false;
    return ChatCacheState.canSendIn(
      chat,
      _chatCache.supergroupForChat(chat),
      right,
    );
  }

  /// The chat's outbox cursor: everything at or below it has been read by the
  /// other side.
  int lastReadOutboxMessageId(int chatId) =>
      _chatCache.chat(chatId)?.lastReadOutboxMessageId ?? 0;

  int lastReadInboxMessageId(int chatId) =>
      _chatCache.chat(chatId)?.lastReadInboxMessageId ?? 0;

  int unreadCount(int chatId) => _chatCache.chat(chatId)?.unreadCount ?? 0;

  /// A page of history, oldest first. [fromMessageId] is 0 for the newest
  /// messages, otherwise the oldest id already loaded.
  Future<HistoryPage> history(
    int chatId, {
    int fromMessageId = 0,
    int limit = historyPageSize,
  }) async {
    final collected = <int, td.Message>{};
    var cursor = fromMessageId;
    var reachedTop = false;

    for (var round = 0; round < historyMaxRequests; round++) {
      final batch = await _historyBatch(chatId, cursor, 0, limit);
      if (batch.isEmpty) {
        // Empty from a real cursor is the top. Empty on the first page only
        // means TDLib has nothing loaded yet.
        reachedTop = cursor != 0;
        break;
      }

      for (final message in batch) {
        collected[message.id] = message;
      }
      if (collected.length >= limit) break;

      final oldest = batch.map((m) => m.id).reduce((a, b) => a < b ? a : b);
      if (oldest == cursor) break;
      cursor = oldest;
    }

    final users = _chatCache.usersById;
    final mapped = ChatMessageMapper.mapHistory(
      collected.values.toList(),
      users: users,
      lastReadOutboxMessageId: lastReadOutboxMessageId(chatId),
      chats: _chatCache.chatsById,
      isGroup: isGroupChat(chatId),
    );

    return (
      messages: await _withReplyTargets(chatId, mapped),
      reachedTop: reachedTop,
    );
  }

  /// The messages around one message, for jumping to a search hit, reply
  /// target or pin beyond what is loaded. A negative offset centres the target.
  /// `reachedTop` is always false; the next page up finds the top.
  Future<HistoryWindow> historyAround(
    int chatId, {
    required int messageId,
    int limit = historyPageSize,
  }) async {
    final batch = await _historyBatch(chatId, messageId, -(limit ~/ 2), limit);
    final mapped = ChatMessageMapper.mapHistory(
      batch,
      users: _chatCache.usersById,
      lastReadOutboxMessageId: lastReadOutboxMessageId(chatId),
      chats: _chatCache.chatsById,
      isGroup: isGroupChat(chatId),
    );
    return (
      messages: await _withReplyTargets(chatId, mapped),
      reachedTop: false,
      reachedBottom: isAtLatest(chatId, _newestIdIn(batch)),
    );
  }

  /// The page below [fromMessageId], for a conversation opened in the middle.
  /// TDLib includes the cursor message itself, so it is dropped.
  Future<HistoryWindow> historyAfter(
    int chatId, {
    required int fromMessageId,
    int limit = historyPageSize,
  }) async {
    final batch = [
      for (final message in await _historyBatch(
        chatId,
        fromMessageId,
        -limit,
        limit + 1,
      ))
        if (message.id > fromMessageId) message,
    ];
    final mapped = ChatMessageMapper.mapHistory(
      batch,
      users: _chatCache.usersById,
      lastReadOutboxMessageId: lastReadOutboxMessageId(chatId),
      chats: _chatCache.chatsById,
      isGroup: isGroupChat(chatId),
    );
    return (
      messages: await _withReplyTargets(chatId, mapped),
      reachedTop: false,
      reachedBottom: isAtLatest(
        chatId,
        batch.isEmpty ? fromMessageId : _newestIdIn(batch),
      ),
    );
  }

  /// Whether [messageId] is the chat's newest message, per the cached
  /// `lastMessage` the update stream keeps current.
  bool isAtLatest(int chatId, int messageId) {
    final last = _chatCache.chat(chatId)?.lastMessage;
    return last == null || last.id <= messageId;
  }

  static int _newestIdIn(List<td.Message> messages) =>
      messages.map((m) => m.id).fold(0, (a, b) => a > b ? a : b);

  /// Messages in one chat matching [query], one page per call; the caller
  /// debounces. Page with `nextFromMessageId`, which is 0 at the end.
  Future<({List<ChatMessage> messages, int nextFromMessageId})> searchInChat(
    int chatId,
    String query, {
    int fromMessageId = 0,
    int limit = historyPageSize,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return (messages: const <ChatMessage>[], nextFromMessageId: 0);
    }

    try {
      final res = await _tdlib.sendRequest(
        td.SearchChatMessages(
          chatId: chatId,
          query: trimmed,
          fromMessageId: fromMessageId,
          offset: 0,
          limit: limit,
          messageThreadId: 0,
          savedMessagesTopicId: 0,
        ),
      );
      if (res is! td.FoundChatMessages) {
        return (messages: const <ChatMessage>[], nextFromMessageId: 0);
      }

      final mapped = ChatMessageMapper.mapHistory(
        res.messages,
        users: _chatCache.usersById,
        lastReadOutboxMessageId: lastReadOutboxMessageId(chatId),
        chats: _chatCache.chatsById,
        isGroup: isGroupChat(chatId),
      );

      return (messages: mapped, nextFromMessageId: res.nextFromMessageId);
    } catch (e) {
      debugPrint('[ChatsRepo] search in $chatId failed: $e');
      return (messages: const <ChatMessage>[], nextFromMessageId: 0);
    }
  }

  /// The newest message pinned in a chat, if any. Always a request: TDLib 2.x
  /// has no `pinnedMessageId` on `Chat`, so this searches with the pinned filter.
  Future<ChatMessage?> pinnedMessage(int chatId) async {
    try {
      final res = await _tdlib.sendRequest(
        td.SearchChatMessages(
          chatId: chatId,
          query: '',
          fromMessageId: 0,
          offset: 0,
          limit: 1,
          filter: const td.SearchMessagesFilterPinned(),
          messageThreadId: 0,
          savedMessagesTopicId: 0,
        ),
      );
      if (res is! td.FoundChatMessages || res.messages.isEmpty) return null;

      final mapped = ChatMessageMapper.mapHistory(
        res.messages,
        users: _chatCache.usersById,
        lastReadOutboxMessageId: lastReadOutboxMessageId(chatId),
        chats: _chatCache.chatsById,
        isGroup: isGroupChat(chatId),
      );
      return mapped.isEmpty ? null : mapped.first;
    } catch (e) {
      debugPrint('[ChatsRepo] pinned message in $chatId failed: $e');
      return null;
    }
  }

  /// The most messages opening an unread chat loads while reaching back for
  /// the read line, so a long backlog costs only a few requests.
  static const int backlogMaxMessages = 120;

  /// The newest messages, reaching back to include [messageId] or up to
  /// [maxMessages]. Opens an unread chat as one unbroken run to the newest.
  Future<HistoryPage> historyReaching(
    int chatId, {
    required int messageId,
    int maxMessages = backlogMaxMessages,
  }) async {
    if (messageId == 0) return history(chatId);

    final collected = <int, td.Message>{};
    var cursor = 0;
    var reachedTop = false;

    // Enough rounds to fill [maxMessages] even with short pages, but bounded.
    final maxRounds =
        (maxMessages / historyPageSize).ceil() + historyMaxRequests;
    for (var round = 0; round < maxRounds; round++) {
      final batch = await _historyBatch(chatId, cursor, 0, historyPageSize);
      if (batch.isEmpty) {
        reachedTop = cursor != 0;
        break;
      }

      for (final message in batch) {
        collected[message.id] = message;
      }

      final oldest = batch.map((m) => m.id).reduce((a, b) => a < b ? a : b);
      if (oldest <= messageId || collected.length >= maxMessages) break;
      if (oldest == cursor) break;
      cursor = oldest;
    }

    final mapped = ChatMessageMapper.mapHistory(
      collected.values.toList(),
      users: _chatCache.usersById,
      lastReadOutboxMessageId: lastReadOutboxMessageId(chatId),
      chats: _chatCache.chatsById,
      isGroup: isGroupChat(chatId),
    );
    return (
      messages: await _withReplyTargets(chatId, mapped),
      reachedTop: reachedTop,
    );
  }

  /// Fills in what the replies on a page are answering. Targets on the page
  /// cost nothing; the rest are fetched with one `GetMessages` per page.
  Future<List<ChatMessage>> _withReplyTargets(
    int chatId,
    List<ChatMessage> page,
  ) async {
    final filled = ChatMessageMapper.fillReplyExcerpts(page);
    final missing = {
      for (final message in filled)
        if (message.replyToMessageId != null &&
            message.replyToChatId == null &&
            message.replyToText == null)
          message.replyToMessageId!,
    };
    if (missing.isEmpty) return filled;

    try {
      final res = await _tdlib.sendRequest(
        td.GetMessages(chatId: chatId, messageIds: missing.toList()),
      );
      if (res is! td.Messages) return filled;
      final targets = ChatMessageMapper.mapHistory(
        // GetMessages answers with an id of 0 for anything it doesn't have.
        [
          for (final message in res.messages)
            if (message.id != 0) message,
        ],
        users: _chatCache.usersById,
        chats: _chatCache.chatsById,
        lastReadOutboxMessageId: lastReadOutboxMessageId(chatId),
        isGroup: isGroupChat(chatId),
      );
      return ChatMessageMapper.fillReplyExcerpts(filled, from: targets);
    } catch (e) {
      debugPrint('[ChatsRepo] reply targets in $chatId failed: $e');
      return filled;
    }
  }

  Future<List<td.Message>> _historyBatch(
    int chatId,
    int fromMessageId,
    int offset,
    int limit,
  ) async {
    try {
      final res = await _tdlib.sendRequest(
        td.GetChatHistory(
          chatId: chatId,
          fromMessageId: fromMessageId,
          offset: offset,
          limit: limit,
          onlyLocal: false,
        ),
      );
      return res is td.Messages ? res.messages : const [];
    } catch (e) {
      debugPrint('[ChatsRepo] GetChatHistory($chatId) failed: $e');
      return const [];
    }
  }

  /// Tells TDLib the chat is open, and returns whether it accepted. An unforced
  /// `ViewMessages` in a chat TDLib doesn't consider open is silently ignored
  /// but still answers `Ok`.
  Future<bool> openChat(int chatId) async {
    try {
      return await _tdlib.sendRequest(td.OpenChat(chatId: chatId)) is td.Ok;
    } catch (e) {
      debugPrint('[ChatsRepo] openChat($chatId) failed: $e');
      return false;
    }
  }

  Future<void> closeChat(int chatId) async {
    try {
      await _tdlib.sendRequest(td.CloseChat(chatId: chatId));
    } catch (e) {
      debugPrint('[ChatsRepo] closeChat($chatId) failed: $e');
    }
  }

  /// Marks messages as read. Returns null on success, or the error so the
  /// caller can retry.
  Future<String?> markRead({
    required int chatId,
    required List<int> messageIds,
    bool forceRead = false,
  }) async {
    if (messageIds.isEmpty) return null;
    try {
      final res = await _tdlib.sendRequest(
        td.ViewMessages(
          chatId: chatId,
          messageIds: messageIds,
          source: const td.MessageSourceChatHistory(),
          forceRead: forceRead,
        ),
      );
      return res is td.Ok ? null : 'TDLib answered ${res.runtimeType}';
    } catch (e) {
      return e.toString();
    }
  }

  /// Marks a whole chat read by viewing its last message. Forced, because
  /// TDLib ignores an unforced read in a chat that isn't open.
  Future<String?> markChatRead(int chatId) async {
    final lastMessageId = _chatCache.chat(chatId)?.lastMessage?.id;
    if (lastMessageId == null) return null;
    return markRead(
      chatId: chatId,
      messageIds: [lastMessageId],
      forceRead: true,
    );
  }

  /// Sends a message, or an album when [ComposeMessages] says so. Returns the
  /// queued message, or null if TDLib refused it.
  Future<td.Message?> send({
    required int chatId,
    required String text,
    List<ComposeAttachment> attachments = const [],

    /// A sticker or GIF already on Telegram's servers, so nothing is uploaded.
    ComposeRemoteMedia? remote,
    int? replyToMessageId,
    MessageSchedule schedule = MessageSchedule.now,
  }) async {
    final contents = ComposeMessages.build(
      text: text,
      attachments: attachments,
      remote: remote,
    );
    final replyTo = replyToMessageId == null
        ? null
        : td.InputMessageReplyToMessage(messageId: replyToMessageId);
    final options = _optionsFor(schedule);

    // Attachments that can't share an album go as several messages; only
    // the first used to be sent. The first message carries the caption.
    td.Message? first;
    try {
      for (final batch in ComposeMessages.batches(contents)) {
        final td.Message? queued;
        if (ComposeMessages.isAlbum(batch)) {
          final res = await _tdlib.sendRequest(
            td.SendMessageAlbum(
              chatId: chatId,
              messageThreadId: 0,
              replyTo: replyTo,
              options: options,
              inputMessageContents: batch,
            ),
          );
          queued = res is td.Messages ? res.messages.firstOrNull : null;
        } else {
          final res = await _tdlib.sendRequest(
            td.SendMessage(
              chatId: chatId,
              messageThreadId: 0,
              replyTo: replyTo,
              options: options,
              inputMessageContent: batch.single,
            ),
          );
          queued = res is td.Message ? res : null;
        }
        if (queued == null) break;
        first ??= queued;
      }
    } catch (e) {
      debugPrint('[ChatsRepo] send to $chatId failed: $e');
    }
    return first;
  }

  /// The send options for one schedule. An immediate send leaves
  /// `schedulingState` unset; see [MessageSchedule.toTdlib].
  static td.MessageSendOptions _optionsFor(MessageSchedule schedule) =>
      schedule.isImmediate
      ? _sendOptions
      : _sendOptions.copyWith(schedulingState: schedule.toTdlib());

  /// Whether this chat has scheduled messages, from the cached
  /// `updateChatHasScheduledMessages`.
  bool hasScheduledMessages(int chatId) =>
      _chatCache.chat(chatId)?.hasScheduledMessages ?? false;

  /// The scheduled messages in this chat, soonest first. Telegram keeps them
  /// server-side, so this is a request.
  Future<List<ChatMessage>> scheduledMessages(int chatId) async {
    try {
      final res = await _tdlib.sendRequest(
        td.GetChatScheduledMessages(chatId: chatId),
      );
      if (res is! td.Messages) return const [];

      final messages = ChatMessageMapper.mapHistory(
        res.messages,
        users: _chatCache.usersById,
        lastReadOutboxMessageId: lastReadOutboxMessageId(chatId),
        chats: _chatCache.chatsById,
        isGroup: isGroupChat(chatId),
      );
      // `mapHistory` orders by id, which for scheduled messages is the order
      // they were written, not sent.
      messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      return messages;
    } catch (e) {
      debugPrint('[ChatsRepo] scheduled for $chatId failed: $e');
      return const [];
    }
  }

  /// Moves a scheduled message, or sends it now with [MessageSchedule.now].
  Future<bool> reschedule({
    required int chatId,
    required int messageId,
    required MessageSchedule schedule,
  }) async {
    try {
      await _tdlib.sendRequest(
        td.EditMessageSchedulingState(
          chatId: chatId,
          messageId: messageId,
          schedulingState: schedule.toTdlib(),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[ChatsRepo] reschedule $chatId/$messageId failed: $e');
      return false;
    }
  }

  /// Sends a poll. Returns the queued message, or null if Telegram refused it.
  Future<td.Message?> sendPoll({
    required int chatId,
    required PollDraft draft,
    int? replyToMessageId,
  }) async {
    if (!draft.canSend) return null;

    try {
      final res = await _tdlib.sendRequest(
        td.SendMessage(
          chatId: chatId,
          messageThreadId: 0,
          replyTo: replyToMessageId == null
              ? null
              : td.InputMessageReplyToMessage(messageId: replyToMessageId),
          options: _sendOptions,
          inputMessageContent: ComposeMessages.pollContent(draft),
        ),
      );
      return res is td.Message ? res : null;
    } catch (e) {
      debugPrint('[ChatsRepo] poll to $chatId failed: $e');
      return null;
    }
  }

  /// Starts a new end-to-end chat and returns its id. It stays pending until
  /// the other person's device comes online, which can take hours.
  Future<int?> createSecretChat(int userId) async {
    try {
      final res = await _tdlib.sendRequest(
        td.CreateNewSecretChat(userId: userId),
      );
      return res is td.Chat ? res.id : null;
    } catch (e) {
      debugPrint('[ChatsRepo] secret chat with $userId failed: $e');
      return null;
    }
  }

  /// Ends an end-to-end chat. Irreversible, and visible to the other side.
  Future<bool> closeSecretChat(int chatId) async {
    final chat = _chatCache.chat(chatId);
    final type = chat?.type;
    if (type is! td.ChatTypeSecret) return false;

    try {
      await _tdlib.sendRequest(
        td.CloseSecretChat(secretChatId: type.secretChatId),
      );
      return true;
    } catch (e) {
      debugPrint('[ChatsRepo] closing secret chat $chatId failed: $e');
      return false;
    }
  }

  /// Whether this is an end-to-end chat.
  bool isSecretChat(int chatId) =>
      _chatCache.chat(chatId)?.type is td.ChatTypeSecret;

  /// Whether an end-to-end chat is still waiting on the other device. False
  /// for any other chat.
  bool isSecretChatPending(int chatId) {
    final chat = _chatCache.chat(chatId);
    if (chat == null || chat.type is! td.ChatTypeSecret) return false;
    return !ChatCacheState.isSecretChatReady(_chatCache.secretChatFor(chat));
  }

  /// Sends this device's location as a still (not live) location. Returns the
  /// queued message, or null.
  Future<td.Message?> sendLocation({
    required int chatId,
    required double latitude,
    required double longitude,
    double accuracy = 0,
    int? replyToMessageId,
  }) async {
    try {
      final res = await _tdlib.sendRequest(
        td.SendMessage(
          chatId: chatId,
          messageThreadId: 0,
          replyTo: replyToMessageId == null
              ? null
              : td.InputMessageReplyToMessage(messageId: replyToMessageId),
          options: _sendOptions,
          inputMessageContent: td.InputMessageLocation(
            location: td.Location(
              latitude: latitude,
              longitude: longitude,
              horizontalAccuracy: accuracy,
            ),
            livePeriod: 0,
            // Live-location only; zero means none.
            heading: 0,
            proximityAlertRadius: 0,
          ),
        ),
      );
      return res is td.Message ? res : null;
    } catch (e) {
      debugPrint('[ChatsRepo] location to $chatId failed: $e');
      return null;
    }
  }

  /// Shares one of this account's Telegram contacts.
  Future<td.Message?> sendContact({
    required int chatId,
    required int userId,
    int? replyToMessageId,
  }) async {
    final user = _chatCache.usersById[userId];
    if (user == null) return null;

    try {
      final res = await _tdlib.sendRequest(
        td.SendMessage(
          chatId: chatId,
          messageThreadId: 0,
          replyTo: replyToMessageId == null
              ? null
              : td.InputMessageReplyToMessage(messageId: replyToMessageId),
          options: _sendOptions,
          inputMessageContent: td.InputMessageContact(
            contact: td.Contact(
              phoneNumber: user.phoneNumber,
              firstName: user.firstName,
              lastName: user.lastName,
              // Left empty so Telegram builds the vCard from the fields above.
              vcard: '',
              userId: userId,
            ),
          ),
        ),
      );
      return res is td.Message ? res : null;
    } catch (e) {
      debugPrint('[ChatsRepo] contact to $chatId failed: $e');
      return null;
    }
  }

  /// This account's Telegram contacts (not the device address book), sorted
  /// by name. One `GetContacts`; the users are already cached.
  Future<List<UserProfile>> contacts() async {
    try {
      final res = await _tdlib.sendRequest(const td.GetContacts());
      if (res is! td.Users) return const [];

      final profiles = <UserProfile>[];
      for (final id in res.userIds) {
        final user = _chatCache.usersById[id];
        if (user == null) continue;
        profiles.add(UserProfileMapper.from(user));
      }
      profiles.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
      return profiles;
    } catch (e) {
      debugPrint('[ChatsRepo] contacts failed: $e');
      return const [];
    }
  }

  /// Opens self-destructing media, which starts its clock and tells the
  /// sender. Irreversible, so only call it from an explicit user tap.
  Future<bool> openSecretMedia({
    required int chatId,
    required int messageId,
  }) async {
    try {
      await _tdlib.sendRequest(
        td.OpenMessageContent(chatId: chatId, messageId: messageId),
      );
      return true;
    } catch (e) {
      debugPrint('[ChatsRepo] open secret $chatId/$messageId failed: $e');
      return false;
    }
  }

  static const _sendOptions = td.MessageSendOptions(
    disableNotification: false,
    fromBackground: false,
    protectContent: false,
    updateOrderOfInstalledStickerSets: false,
    effectId: 0,
    sendingId: 0,
    onlyPreview: false,
  );

  /// Rewrites a message this account sent. Returns whether Telegram took it.
  Future<bool> editText({
    required int chatId,
    required int messageId,
    required String text,
    bool isCaption = false,
  }) async {
    final formatted = td.FormattedText(text: text, entities: const []);
    try {
      // Media messages need `EditMessageCaption`; Telegram rejects
      // `EditMessageText` for them.
      final res = await _tdlib.sendRequest(
        isCaption
            ? td.EditMessageCaption(
                chatId: chatId,
                messageId: messageId,
                caption: formatted,
                showCaptionAboveMedia: false,
              )
            : td.EditMessageText(
                chatId: chatId,
                messageId: messageId,
                inputMessageContent: td.InputMessageText(
                  text: formatted,
                  clearDraft: false,
                ),
              ),
      );
      return res is td.Message;
    } catch (e) {
      debugPrint('[ChatsRepo] edit $chatId/$messageId failed: $e');
      return false;
    }
  }

  /// Deletes messages. [revoke] deletes them for everybody, not just this
  /// account.
  Future<bool> deleteMessages({
    required int chatId,
    required List<int> messageIds,
    required bool revoke,
  }) async {
    if (messageIds.isEmpty) return true;
    try {
      final res = await _tdlib.sendRequest(
        td.DeleteMessages(
          chatId: chatId,
          messageIds: messageIds,
          revoke: revoke,
        ),
      );
      return res is td.Ok;
    } catch (e) {
      debugPrint('[ChatsRepo] delete in $chatId failed: $e');
      return false;
    }
  }

  /// What this account may do with one message, from TDLib's offline
  /// `getMessageProperties`. Asked on long-press only, never for a whole page.
  Future<MessageActions> messageActions({
    required int chatId,
    required int messageId,
  }) async {
    try {
      final res = await _tdlib.sendRequest(
        td.GetMessageProperties(chatId: chatId, messageId: messageId),
      );
      if (res is! td.MessageProperties) return MessageActionsNone.none;
      return (
        canEdit: res.canBeEdited,
        canDeleteForSelf: res.canBeDeletedOnlyForSelf,
        canDeleteForAll: res.canBeDeletedForAllUsers,
        canReply: res.canBeReplied,
        canForward: res.canBeForwarded,
        canCopy: res.canBeSaved,
        canPin: res.canBePinned,
      );
    } catch (e) {
      debugPrint('[ChatsRepo] properties for $chatId/$messageId failed: $e');
      return MessageActionsNone.none;
    }
  }

  /// Pins or unpins a message, without notifying the chat. [isPinned] is the
  /// target state, as with every toggle here.
  Future<bool> setMessagePinned({
    required int chatId,
    required int messageId,
    required bool isPinned,
  }) async {
    try {
      await _tdlib.sendRequest(
        isPinned
            ? td.PinChatMessage(
                chatId: chatId,
                messageId: messageId,
                disableNotification: true,
                onlyForSelf: false,
              )
            : td.UnpinChatMessage(chatId: chatId, messageId: messageId),
      );
      return true;
    } catch (e) {
      debugPrint('[ChatsRepo] pin $chatId/$messageId failed: $e');
      return false;
    }
  }

  /// Whether this account may change this chat's auto-delete timer.
  bool canSetAutoDelete(int chatId) {
    final chat = _chatCache.chat(chatId);
    if (chat == null) return false;
    return ChatCacheState.canSetAutoDeleteIn(
      chat,
      _chatCache.supergroupForChat(chat),
    );
  }

  /// The chat's auto-delete timer in seconds. Zero (the default) means never.
  int autoDeleteTime(int chatId) =>
      _chatCache.chat(chatId)?.messageAutoDeleteTime ?? 0;

  /// Sets the chat's auto-delete timer. [seconds] of zero turns it off. Applies
  /// to both sides from now on, and Telegram posts a service notice about it.
  Future<bool> setAutoDeleteTime(int chatId, int seconds) async {
    try {
      await _tdlib.sendRequest(
        td.SetChatMessageAutoDeleteTime(
          chatId: chatId,
          messageAutoDeleteTime: seconds,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[ChatsRepo] auto-delete for $chatId failed: $e');
      return false;
    }
  }

  /// Adds or removes one of this account's reactions on a message. Returns
  /// false if Telegram refused it.
  Future<bool> toggleReaction({
    required int chatId,
    required int messageId,
    required String emoji,
    required bool isChosen,
  }) async {
    try {
      if (isChosen) {
        await _tdlib.sendRequest(
          td.RemoveMessageReaction(
            chatId: chatId,
            messageId: messageId,
            reactionType: td.ReactionTypeEmoji(emoji: emoji),
          ),
        );
      } else {
        await _tdlib.sendRequest(
          td.AddMessageReaction(
            chatId: chatId,
            messageId: messageId,
            reactionType: td.ReactionTypeEmoji(emoji: emoji),
            isBig: false,
            updateRecentReactions: true,
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('[ChatsRepo] react on $chatId/$messageId failed: $e');
      return false;
    }
  }

  /// The reactions offered for one message, best first, minus Premium-only
  /// ones. `chat.availableReactions` won't do: most chats report
  /// `ChatAvailableReactionsAll`, which lists no emoji.
  Future<List<String>> messageReactions({
    required int chatId,
    required int messageId,
    int rowSize = reactionRowSize,
  }) async {
    try {
      final res = await _tdlib.sendRequest(
        td.GetMessageAvailableReactions(
          chatId: chatId,
          messageId: messageId,
          rowSize: rowSize,
        ),
      );
      if (res is! td.AvailableReactions) return const [];

      final emojis = <String>[];
      // Top, then recent, then popular, as Telegram orders them.
      for (final group in [
        res.topReactions,
        res.recentReactions,
        res.popularReactions,
      ]) {
        for (final reaction in group) {
          if (reaction.needsPremium) continue;
          final type = reaction.type;
          if (type is! td.ReactionTypeEmoji) continue;
          if (emojis.contains(type.emoji)) continue;
          emojis.add(type.emoji);
        }
      }
      return emojis;
    } catch (e) {
      debugPrint('[ChatsRepo] reactions for $chatId/$messageId failed: $e');
      return const [];
    }
  }

  /// How many reactions the picker shows in its row; Telegram orders around it.
  static const int reactionRowSize = 8;

  /// Tells the other side this account is typing, or has stopped. Telegram
  /// expects it about every five seconds while typing; the caller throttles.
  Future<void> setTyping(int chatId, {required bool isTyping}) async {
    try {
      await _tdlib.sendRequest(
        td.SendChatAction(
          chatId: chatId,
          messageThreadId: 0,
          businessConnectionId: '',
          action: isTyping
              ? const td.ChatActionTyping()
              : const td.ChatActionCancel(),
        ),
      );
    } catch (e) {
      debugPrint('[ChatsRepo] chat action on $chatId failed: $e');
    }
  }

  /// Saves unsent text as the chat's Telegram draft, which syncs across the
  /// account's devices.
  Future<void> saveDraft(
    int chatId,
    String text, {
    int? replyToMessageId,
  }) async {
    try {
      await _tdlib.sendRequest(
        td.SetChatDraftMessage(
          chatId: chatId,
          messageThreadId: 0,
          draftMessage: text.trim().isEmpty
              ? null
              : td.DraftMessage(
                  replyTo: replyToMessageId == null
                      ? null
                      : td.InputMessageReplyToMessage(
                          messageId: replyToMessageId,
                        ),
                  date: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  inputMessageText: td.InputMessageText(
                    text: td.FormattedText(text: text, entities: const []),
                    clearDraft: false,
                  ),
                  effectId: 0,
                ),
        ),
      );
    } catch (e) {
      debugPrint('[ChatsRepo] saveDraft for $chatId failed: $e');
    }
  }

  /// The text of the draft TDLib holds for this chat, if it is a text one.
  String? draftText(int chatId) {
    final draft = _chatCache.chat(chatId)?.draftMessage;
    final content = draft?.inputMessageText;
    if (content is! td.InputMessageText) return null;
    return content.text.text.isEmpty ? null : content.text.text;
  }

  /// The Saved Messages chat id, which is [selfUserId]. Creates the chat if a
  /// fresh account doesn't have it yet. Null when [selfUserId] hasn't loaded.
  Future<int?> savedMessagesChatId(int? selfUserId) async =>
      selfUserId == null ? null : privateChatId(selfUserId);

  /// The private chat with [userId], created if TDLib doesn't have one yet,
  /// as for someone never written to. Null if it couldn't be.
  Future<int?> privateChatId(int userId) async {
    if (_chatCache.chat(userId) != null) return userId;

    try {
      final res = await _tdlib.sendRequest(
        td.CreatePrivateChat(userId: userId, force: false),
      );
      return res is td.Chat ? res.id : null;
    } catch (e) {
      debugPrint('[ChatsRepo] private chat with $userId failed: $e');
      return null;
    }
  }

  /// Pins a chat to the top of the main list, or unpins it. Pins are per chat
  /// list, so this targets `ChatListMain`.
  Future<bool> setPinned(int chatId, {required bool isPinned}) async {
    try {
      final res = await _tdlib.sendRequest(
        td.ToggleChatIsPinned(
          chatList: const td.ChatListMain(),
          chatId: chatId,
          isPinned: isPinned,
        ),
      );
      return res is td.Ok;
    } catch (e) {
      // Telegram caps the number of pinned chats and errors past the limit.
      debugPrint('[ChatsRepo] pin($chatId) failed: $e');
      return false;
    }
  }

  /// Mutes a chat forever, or unmutes it. Unmuting returns the chat to the
  /// account-wide default instead of setting it to zero, so it keeps following
  /// later changes to that default.
  Future<bool> setMuted(int chatId, {required bool isMuted}) async {
    final current = _chatCache.chat(chatId)?.notificationSettings;
    if (current == null) return false;

    try {
      final res = await _tdlib.sendRequest(
        td.SetChatNotificationSettings(
          chatId: chatId,
          notificationSettings: current.copyWith(
            useDefaultMuteFor: !isMuted,
            muteFor: isMuted ? muteForever : 0,
          ),
        ),
      );
      return res is td.Ok;
    } catch (e) {
      debugPrint('[ChatsRepo] mute($chatId) failed: $e');
      return false;
    }
  }

  /// Telegram's "muted with no end date": the maximum 32-bit int.
  static const int muteForever = 2147483647;

  /// Whether this is a group that can be left. One-to-one chats can only be
  /// deleted.
  bool canLeave(int chatId) {
    final type = _chatCache.chat(chatId)?.type;
    return type is td.ChatTypeBasicGroup ||
        (type is td.ChatTypeSupergroup && !type.isChannel);
  }

  /// Whether deleting this chat can also delete it for the other person.
  bool canDeleteForBoth(int chatId) =>
      _chatCache.chat(chatId)?.canBeDeletedForAllUsers ?? false;

  /// Deletes a one-to-one chat and its history; [revoke] deletes it for the
  /// other person too. A secret chat is closed first so the session ends.
  Future<bool> deleteChat(int chatId, {required bool revoke}) async {
    try {
      if (isSecretChat(chatId)) await closeSecretChat(chatId);
      final res = await _tdlib.sendRequest(
        td.DeleteChatHistory(
          chatId: chatId,
          removeFromChatList: true,
          revoke: revoke,
        ),
      );
      return res is td.Ok;
    } catch (e) {
      debugPrint('[ChatsRepo] delete chat $chatId failed: $e');
      return false;
    }
  }

  /// Leaves a group and removes it from the list. Telegram keeps a left basic
  /// group as a read-only chat, so its history is deleted as well.
  Future<bool> leaveChat(int chatId) async {
    try {
      final res = await _tdlib.sendRequest(td.LeaveChat(chatId: chatId));
      if (res is! td.Ok) return false;
      if (_chatCache.chat(chatId)?.type is td.ChatTypeBasicGroup) {
        await _tdlib.sendRequest(
          td.DeleteChatHistory(
            chatId: chatId,
            removeFromChatList: true,
            revoke: false,
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('[ChatsRepo] leave $chatId failed: $e');
      return false;
    }
  }

  /// Whether this account has blocked [userId], read from the cached chat.
  bool isBlocked(int userId) => _chatCache.chat(userId)?.blockList != null;

  /// Blocks or unblocks a person. Telegram doesn't notify them.
  Future<bool> setBlocked(int userId, {required bool isBlocked}) async {
    try {
      final res = await _tdlib.sendRequest(
        td.SetMessageSenderBlockList(
          senderId: td.MessageSenderUser(userId: userId),
          blockList: isBlocked ? const td.BlockListMain() : null,
        ),
      );
      return res is td.Ok;
    } catch (e) {
      debugPrint('[ChatsRepo] block($userId, $isBlocked) failed: $e');
      return false;
    }
  }

  /// Dismisses the chat's action bar (report / add / block) without acting.
  Future<void> dismissRequest(int chatId) async {
    try {
      await _tdlib.sendRequest(td.RemoveChatActionBar(chatId: chatId));
    } catch (e) {
      debugPrint('[ChatsRepo] dismiss request in $chatId failed: $e');
    }
  }

  /// Forwards messages into another chat. `sendCopy: false` keeps the
  /// "Forwarded from" attribution.
  Future<bool> forward({
    required int fromChatId,
    required List<int> messageIds,
    required int toChatId,
  }) async {
    if (messageIds.isEmpty) return true;
    try {
      final res = await _tdlib.sendRequest(
        td.ForwardMessages(
          chatId: toChatId,
          messageThreadId: 0,
          fromChatId: fromChatId,
          messageIds: messageIds,
          options: _sendOptions,
          sendCopy: false,
          removeCaption: false,
        ),
      );
      return res is td.Messages;
    } catch (e) {
      debugPrint('[ChatsRepo] forward to $toChatId failed: $e');
      return false;
    }
  }

  /// Chats this account can forward into, best destination first. Read from
  /// [ChatCache], so it costs no requests.
  List<ChatSummary> forwardTargets({int? selfUserId}) => ChatListBuilder.build(
    _chatCache.forwardTargets,
    users: _chatCache.usersById,
    supergroups: _chatCache.supergroupsById,
    selfUserId: selfUserId,
  );

  /// What a `@username` refers to, so a tap can open the right screen. One
  /// request per tap. Null when Telegram doesn't know the name.
  Future<({int chatId, ResolvedChatKind kind})?> resolveUsername(
    String username,
  ) async {
    final handle = username.replaceFirst('@', '').trim();
    if (handle.isEmpty) return null;

    try {
      final res = await _tdlib.sendRequest(
        td.SearchPublicChat(username: handle),
      );
      if (res is! td.Chat) return null;
      return (chatId: res.id, kind: resolvedKindOf(res.type));
    } catch (e) {
      debugPrint('[ChatsRepo] resolve @$handle failed: $e');
      return null;
    }
  }

  /// Which screen a chat known by id belongs on, or null if TDLib can't
  /// find it. A `t.me/c/` link names a channel or a group alike.
  Future<ResolvedChatKind?> chatKind(int chatId) async {
    try {
      final chat =
          _chatCache.chat(chatId) ??
          await _tdlib.sendRequest(td.GetChat(chatId: chatId));
      return chat is td.Chat ? resolvedKindOf(chat.type) : null;
    } catch (_) {
      return null;
    }
  }

  /// Which screen a resolved chat belongs on.
  static ResolvedChatKind resolvedKindOf(td.ChatType type) => switch (type) {
    td.ChatTypePrivate() || td.ChatTypeSecret() => ResolvedChatKind.person,
    td.ChatTypeSupergroup(:final isChannel) when isChannel =>
      ResolvedChatKind.channel,
    _ => ResolvedChatKind.group,
  };

  /// One person's profile: at most a `GetUser` and a `GetUserFullInfo`, so
  /// never call it per list row. Caches the full info for the chat list.
  Future<UserProfile?> userProfile(int userId) async {
    try {
      var user = _chatCache.user(userId);
      if (user == null) {
        final res = await _tdlib.sendRequest(td.GetUser(userId: userId));
        if (res is! td.User) return null;
        user = res;
      }

      td.UserFullInfo? fullInfo = _chatCache.userFullInfosById[userId];
      if (fullInfo == null) {
        final res = await _tdlib.sendRequest(
          td.GetUserFullInfo(userId: userId),
        );
        if (res is td.UserFullInfo) {
          fullInfo = res;
          _chatCache.rememberUserFullInfo(userId, res);
        }
      }

      final personalChatId = fullInfo?.personalChatId ?? 0;
      return UserProfileMapper.from(
        user,
        fullInfo: fullInfo,
        // Only from cache, to avoid a third request.
        personalChannelTitle: personalChatId == 0
            ? null
            : _chatCache.chat(personalChatId)?.title,
      );
    } catch (e) {
      debugPrint('[ChatsRepo] userProfile($userId) failed: $e');
      return null;
    }
  }

  /// Fetches one person's `UserFullInfo` into the cache if missing, and their
  /// personal channel if the cache doesn't know it. Returns whether the cache
  /// now has the full info. Only [AffiliationPrefetcher] calls this.
  Future<bool> ensureUserFullInfo(int userId) async {
    if (_chatCache.userFullInfosById.containsKey(userId)) return true;
    final res = await _tdlib.sendRequest(td.GetUserFullInfo(userId: userId));
    if (res is! td.UserFullInfo) return false;
    _chatCache.rememberUserFullInfo(userId, res);

    final personalChatId = res.personalChatId;
    if (personalChatId != 0 && _chatCache.chat(personalChatId) == null) {
      // The cache picks the chat up from the resulting `updateNewChat`.
      try {
        await _tdlib.sendRequest(td.GetChat(chatId: personalChatId));
      } catch (e) {
        debugPrint('[ChatsRepo] personal chat $personalChatId: $e');
      }
    }
    return true;
  }

  /// Sends failed messages again. Telegram doesn't retry by itself; TDLib
  /// keeps the content, so only the ids are needed.
  Future<bool> resend(int chatId, List<int> messageIds) async {
    if (messageIds.isEmpty) return true;
    try {
      final res = await _tdlib.sendRequest(
        td.ResendMessages(chatId: chatId, messageIds: messageIds),
      );
      return res is td.Messages;
    } catch (e) {
      debugPrint('[ChatsRepo] resend in $chatId failed: $e');
      return false;
    }
  }

  /// Marks a chat unread by hand, or clears that mark.
  Future<void> setMarkedAsUnread(int chatId, {required bool value}) async {
    try {
      await _tdlib.sendRequest(
        td.ToggleChatIsMarkedAsUnread(chatId: chatId, isMarkedAsUnread: value),
      );
    } catch (e) {
      debugPrint('[ChatsRepo] markUnread($chatId) failed: $e');
    }
  }

  /// Chats matching [query], for the "new message" picker. `SearchChats` is
  /// offline, so it can run on every keystroke.
  Future<List<ChatSummary>> searchChats(
    String query, {
    int? selfUserId,
    int limit = 30,
  }) async {
    if (query.trim().isEmpty) return chatList(selfUserId: selfUserId);

    try {
      final res = await _tdlib.sendRequest(
        td.SearchChats(query: query.trim(), limit: limit),
      );
      if (res is! td.Chats) return const [];

      return [
        for (final chatId in res.chatIds)
          if (_chatCache.chat(chatId) case final chat?)
            if (ChatCacheState.isConversation(chat))
              ChatListBuilder.summaryFor(
                chat,
                users: _chatCache.usersById,
                supergroups: _chatCache.supergroupsById,
                selfUserId: selfUserId,
                secretChats: _chatCache.secretChatsById,
              ),
      ];
    } catch (e) {
      debugPrint('[ChatsRepo] searchChats failed: $e');
      return const [];
    }
  }
}

final chatsRepositoryProvider = Provider<ChatsRepository>((ref) {
  return ChatsRepository(
    ref.watch(tdlibServiceProvider),
    ref.watch(chatCacheProvider),
  );
});
