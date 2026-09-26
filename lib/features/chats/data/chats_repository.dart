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
///
/// A record rather than a model: it has no identity, it is never stored, and it
/// is thrown away when the sheet closes.
typedef MessageActions = ({
  bool canEdit,
  bool canDeleteForSelf,
  bool canDeleteForAll,
  bool canReply,
  bool canForward,
  bool canCopy,

  /// Whether Telegram would take a pin for this message. Its rules depend on
  /// the chat type and this account's rights, which is exactly the kind of
  /// thing `getMessageProperties` answers and a guess here would get wrong.
  bool canPin,
});

/// Nothing is allowed — the honest answer when TDLib could not be asked.
///
/// Deliberately the *closed* default. A failed lookup that answered "everything
/// is allowed" would draw a Delete that fails when tapped.
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

/// A page of history, and whether it reached the top of the chat.
///
/// The two are returned together because the second cannot be inferred from the
/// first: TDLib chooses its own batch size, so a short page is not the end of
/// the history.
typedef HistoryPage = ({List<ChatMessage> messages, bool reachedTop});

/// A stretch of history that may end short of the newest message.
///
/// What a jump to a search hit loads: the messages around one point, with the
/// chat continuing both above and below. [reachedBottom] is the half
/// [HistoryPage] never had to answer, because a page fetched from the newest
/// message always is the bottom.
typedef HistoryWindow = ({
  List<ChatMessage> messages,
  bool reachedTop,
  bool reachedBottom,
});

/// Everything a conversation does that reaches Telegram.
///
/// Stateless, like every repository here: it takes its collaborators in the
/// constructor and exposes futures. Cross-request state belongs in a notifier.
///
/// **On the request budget.** The chat list costs nothing at all — it is read
/// straight out of [ChatCache], which the update stream fills. Everything else
/// on this class is user-driven and bounded: opening one chat, sending one
/// message, asking for one more page. There is no path here that walks the chat
/// list issuing a request per chat, and there must never be one.
class ChatsRepository {
  final TdlibService _tdlib;
  final ChatCache _chatCache;

  ChatsRepository(this._tdlib, this._chatCache);

  /// How many messages one history page asks for. TDLib may answer with fewer.
  static const int historyPageSize = 40;

  /// How many rounds a single page is willing to spend before giving up.
  ///
  /// `GetChatHistory` returns fewer messages than asked for, and a reply of one
  /// message does not mean the history ended — so a page asks again from the
  /// oldest id it was given. Bounded, because "ask until full" against a chat
  /// that genuinely has three messages left is an unbounded loop on the budget.
  static const int historyMaxRequests = 3;

  /// The chat list, straight from the cache. Costs zero requests.
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

  /// Whether this chat has more than two people in it, which decides whether
  /// bubbles carry a sender name.
  bool isGroupChat(int chatId) {
    final chat = _chatCache.chat(chatId);
    if (chat == null) return false;
    return chat.type is! td.ChatTypePrivate;
  }

  /// Whether this is a one-to-one chat with another person.
  ///
  /// Not simply the inverse of [isGroupChat]: a secret chat is private but is
  /// not a `chatTypePrivate`, and self-destructing media is exactly the feature
  /// that would be offered wrongly if the two were treated as the same
  /// question. Telegram takes a self-destruct timer only in a `chatTypePrivate`.
  bool isPrivateChat(int chatId) =>
      _chatCache.chat(chatId)?.type is td.ChatTypePrivate;

  /// Whether a poll may be sent into this chat.
  ///
  /// Telegram's rules, not a guess: a poll cannot go into a private chat with a
  /// person at all (only into one with a bot), a group has to permit them, and
  /// a channel needs posting rights. The control is hidden where this is false
  /// rather than offered and rejected on send.
  bool canSendPollsIn(int chatId) {
    final chat = _chatCache.chat(chatId);
    if (chat == null) return false;
    return ChatCacheState.canSendPollsIn(chat, _chatCache.supergroupForChat(chat));
  }

  /// Whether one kind of thing may be sent into this chat.
  ///
  /// The composer asks this per control, so a group that forbids voice messages
  /// shows no microphone rather than one that fails when held.
  bool canSendIn(int chatId, ChatSendRight right) {
    final chat = _chatCache.chat(chatId);
    if (chat == null) return false;
    return ChatCacheState.canSendIn(
      chat,
      _chatCache.supergroupForChat(chat),
      right,
    );
  }

  /// The chat's outbox cursor — everything at or below it has been read by the
  /// other side.
  int lastReadOutboxMessageId(int chatId) =>
      _chatCache.chat(chatId)?.lastReadOutboxMessageId ?? 0;

  int lastReadInboxMessageId(int chatId) =>
      _chatCache.chat(chatId)?.lastReadInboxMessageId ?? 0;

  /// How many messages the reader has not seen in this chat.
  int unreadCount(int chatId) => _chatCache.chat(chatId)?.unreadCount ?? 0;

  /// A page of history, oldest first.
  ///
  /// [fromMessageId] is the cursor: 0 for the newest messages, otherwise the
  /// oldest id already loaded. One tap is one page — this is the on-demand
  /// shape the request budget allows, not a fan-out.
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
        // Nothing came back from the cursor we asked from. With a real cursor
        // that is the top of the chat; on the very first page it means TDLib
        // has nothing yet, which is not the same claim.
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

  /// The messages around one message — for landing on a search hit, a reply
  /// target or a pin that is further back than paging would reach.
  ///
  /// One request. A negative offset is TDLib's "and some newer than this
  /// one", so the target lands in the middle of the window with the chat
  /// continuing on both sides. Paging back to a message a year up the
  /// scrollback used to mean forty requests or a shrug; this is what
  /// Telegram's own clients do instead, and it is the on-demand, one-tap
  /// one-request shape the request budget allows.
  ///
  /// [reachedTop] is always false — nothing here asked about the top — and
  /// the first page above will find it if it is there. [reachedBottom] is
  /// answered against the chat's own last message, which the cache already
  /// holds: TDLib chooses its own batch size, so a short window is not proof
  /// of anything.
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

  /// The page below what is loaded, for a conversation opened in the middle.
  ///
  /// The mirror of [history]: [fromMessageId] is the newest id already on
  /// screen, and the answer is what comes after it. TDLib returns the cursor
  /// message itself along with the newer ones, so it is dropped here.
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

  /// Whether [messageId] is the chat's newest message, as far as the cache
  /// knows. The chat record's `lastMessage` is kept current by the update
  /// stream, so this costs nothing and is not fooled by a short page.
  bool isAtLatest(int chatId, int messageId) {
    final last = _chatCache.chat(chatId)?.lastMessage;
    return last == null || last.id <= messageId;
  }

  static int _newestIdIn(List<td.Message> messages) =>
      messages.map((m) => m.id).fold(0, (a, b) => a > b ? a : b);

  /// Messages in one chat matching [query].
  ///
  /// The half of a chat app that is only ever missed when you need it, and
  /// named in the T15 notes as absent rather than half-built.
  ///
  /// **On the budget, and driven by a person typing** — so it must reach TDLib
  /// only after the 300 ms debounce the request budget requires, which is the
  /// caller's job and is why this takes a settled query rather than a
  /// controller. One page per call; [fromMessageId] pages back through the
  /// results using TDLib's own `nextFromMessageId`, which answers 0 when they
  /// end — inferring exhaustion from a short page would stop early, because
  /// TDLib chooses its own batch size.
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

      return (
        messages: mapped,
        nextFromMessageId: res.nextFromMessageId,
      );
    } catch (e) {
      debugPrint('[ChatsRepo] search in $chatId failed: $e');
      return (messages: const <ChatMessage>[], nextFromMessageId: 0);
    }
  }

  /// The message pinned at the top of a chat, if there is one.
  ///
  /// **This costs a request even when the answer is "none".** TDLib 2.x carries
  /// no `pinnedMessageId` on `Chat`, so the only way to ask is a networked
  /// `SearchChatMessages` with the pinned filter — there is no free version of
  /// this question. It is therefore issued once per chat, when a conversation
  /// is opened, and the provider that calls it holds the answer for the rest of
  /// the session: one tap, one request, which is the on-demand shape
  /// the request budget allows.
  ///
  /// Only the newest pin is returned. Telegram allows several and shows a
  /// counter to page through them; that is a control gramX does not have, and
  /// a bar that showed one of five without saying so would be lying about
  /// which one.
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

  /// The most messages opening an unread chat will load before it stops
  /// reaching for the read line.
  ///
  /// Past this the chat opens on the newest [backlogMaxMessages] with the
  /// unread band above the oldest of them, and scrolling up pages back the
  /// ordinary way. Bounded because a group left for a month is thousands of
  /// messages, and opening it must cost the same few requests as any other.
  static const int backlogMaxMessages = 120;

  /// The newest messages, reaching back far enough to include [messageId].
  ///
  /// This is how an unread chat opens: everything from the read line down to
  /// the newest message, with nothing missing in between. It replaced a
  /// window *centred* on the read cursor, which loaded twenty unread messages
  /// and nothing after them — in a chat with more than that waiting, the
  /// newest messages were simply not there, "jump to latest" stopped short of
  /// them, and a message arriving live was appended below the hole. Loading
  /// from the bottom up means the list is always one unbroken run ending at
  /// the newest message, which every other part of the screen assumes.
  ///
  /// Stops when the read line is covered, when the chat runs out, or at
  /// [backlogMaxMessages] — whichever comes first. Each round asks for a full
  /// page from the oldest id so far, since TDLib answers with fewer than asked.
  Future<HistoryPage> historyReaching(
    int chatId, {
    required int messageId,
    int maxMessages = backlogMaxMessages,
  }) async {
    if (messageId == 0) return history(chatId);

    final collected = <int, td.Message>{};
    var cursor = 0;
    var reachedTop = false;

    // Enough rounds to fill [maxMessages] even when TDLib answers each with a
    // short page, and never unbounded.
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

  /// Fills in what the replies on a page are answering.
  ///
  /// Most answers are on the page already, and cost nothing — see
  /// [ChatMessageMapper.fillReplyExcerpts]. The rest point further back than
  /// the page reaches, and drew as a bare "Replying to" with nothing after it,
  /// which in a busy group was most of the replies on screen. They are fetched
  /// together: one `GetMessages` per page, bounded by the page size and only
  /// ever for a page somebody asked to see.
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
        [for (final message in res.messages) if (message.id != 0) message],
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

  /// Tells TDLib the reader has this chat open.
  ///
  /// Returns whether TDLib acknowledged it, and the caller needs that answer: a
  /// read acknowledgement sent with `forceRead: false` against a chat TDLib does
  /// not consider open is quietly declined and still answers `Ok`, so nothing
  /// retries it.
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

  /// Acknowledges messages as read. Returns null on success, or the error.
  ///
  /// Read state is written to every client this account owns and cannot be
  /// reconstructed, so failures are reported rather than swallowed — the caller
  /// retries.
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

  /// Acknowledges a whole chat as read, up to its last message.
  ///
  /// `ViewMessages` moves the read cursor to the highest id it is given, so
  /// acknowledging the last message acknowledges everything behind it — one
  /// request per chat rather than one per unread message. Returns null on
  /// success, or the error to log.
  ///
  /// Forced, because the chat is not open: an unforced ack against an unopened
  /// chat is declined silently and still answers `Ok`.
  Future<String?> markChatRead(int chatId) async {
    final lastMessageId = _chatCache.chat(chatId)?.lastMessage?.id;
    if (lastMessageId == null) return null;
    return markRead(
      chatId: chatId,
      messageIds: [lastMessageId],
      forceRead: true,
    );
  }

  /// Sends a message. Returns the queued message, or null if TDLib refused it.
  ///
  /// "Queued" is the honest word — `SendMessage` answers as soon as the message
  /// is on its way and any attachment uploads afterwards, so the reply means
  /// "accepted", not "delivered". The bubble shows that state rather than
  /// claiming a delivery it cannot know about.
  ///
  /// The content shapes come from [ComposeMessages], which already knows that
  /// one file is a captioned message and several are an album whose caption
  /// belongs to the first item only. A second copy of those rules is how the
  /// caption ends up repeated under every picture.
  Future<td.Message?> send({
    required int chatId,
    required String text,
    List<ComposeAttachment> attachments = const [],

    /// A sticker or GIF out of the account's collection. Already on
    /// Telegram's servers, so nothing is uploaded — see [ComposeRemoteMedia].
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

    try {
      if (ComposeMessages.isAlbum(contents)) {
        final res = await _tdlib.sendRequest(
          td.SendMessageAlbum(
            chatId: chatId,
            messageThreadId: 0,
            replyTo: replyTo,
            options: options,
            inputMessageContents: contents,
          ),
        );
        // An album is several messages; the first is the one carrying the
        // caption, and the one the screen scrolls to.
        if (res is td.Messages) {
          return res.messages.isEmpty ? null : res.messages.first;
        }
        return null;
      }

      final res = await _tdlib.sendRequest(
        td.SendMessage(
          chatId: chatId,
          messageThreadId: 0,
          replyTo: replyTo,
          options: options,
          inputMessageContent: contents.first,
        ),
      );
      return res is td.Message ? res : null;
    } catch (e) {
      debugPrint('[ChatsRepo] send to $chatId failed: $e');
      return null;
    }
  }

  /// The send options for one schedule.
  ///
  /// A null `schedulingState` is "send it now", and it is the *absence* of the
  /// field rather than a date of zero — TDLib reads a present state as "this is
  /// scheduled", so a zero date would queue the message for 1970.
  static td.MessageSendOptions _optionsFor(MessageSchedule schedule) =>
      schedule.isImmediate
      ? _sendOptions
      : _sendOptions.copyWith(schedulingState: schedule.toTdlib());

  /// Whether this chat has messages waiting to be sent.
  ///
  /// Read from the cache, which mirrors `updateChatHasScheduledMessages`, so
  /// the header can offer the scheduled screen only when there is something on
  /// it — and costs nothing to ask.
  bool hasScheduledMessages(int chatId) =>
      _chatCache.chat(chatId)?.hasScheduledMessages ?? false;

  /// The messages waiting to be sent in this chat, soonest first.
  ///
  /// One request, when the scheduled screen is opened. Telegram keeps the queue
  /// server-side — it sends them whether or not this app is running — so there
  /// is nothing local to read it from.
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
      // Soonest first. `mapHistory` orders by message id, which for a scheduled
      // message is the order it was *written* rather than the order it goes.
      messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      return messages;
    } catch (e) {
      debugPrint('[ChatsRepo] scheduled for $chatId failed: $e');
      return const [];
    }
  }

  /// Moves a scheduled message, or sends it now.
  ///
  /// [MessageSchedule.now] is how a message is sent immediately: TDLib takes a
  /// null scheduling state on this call to mean "send it".
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
  ///
  /// Separate from [send] rather than a branch inside it: a poll carries no
  /// text and no attachments, and threading a nullable draft through the media
  /// path would put a `if (poll != null) ignore everything else` at the top of
  /// the one method that decides what a message *is*.
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

  /// Starts an end-to-end chat with somebody. Returns the new chat's id.
  ///
  /// The chat exists immediately and is **pending**: TDLib has generated this
  /// side of the key exchange, and nothing can be sent until the other person's
  /// device comes online and finishes it. That can be hours, so the screen it
  /// opens says so rather than showing a composer that would be refused.
  ///
  /// Always a *new* chat. `createNewSecretChat` is deliberate rather than
  /// `createSecretChat`, which joins an existing one by id — two people who
  /// have talked secretly before and want to again are starting a new
  /// end-to-end session, which is the point of the feature.
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

  /// Whether an end-to-end chat is still waiting on the other device.
  ///
  /// False for every chat that is not a secret one, so a caller can ask without
  /// checking the type first.
  bool isSecretChatPending(int chatId) {
    final chat = _chatCache.chat(chatId);
    if (chat == null || chat.type is! td.ChatTypeSecret) return false;
    return !ChatCacheState.isSecretChatReady(_chatCache.secretChatFor(chat));
  }

  /// Sends where this device is. Returns whether Telegram queued it.
  ///
  /// A still location, never a live one: `livePeriod` of zero is Telegram's
  /// spelling of "this is where I was when I sent it". A live location would
  /// need a position stream running while the app is in the background, which
  /// is a different permission and a foreground service — see
  /// [LocationService].
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
            // Both are live-location machinery: a compass heading to draw an
            // arrow with, and a radius to alert on approach. Zero is "none" for
            // each, and neither means anything on a still location.
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
              // Telegram builds the vCard itself from the fields above when
              // this is empty. Writing one here would mean this app deciding
              // what a contact card says, which is not its call.
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

  /// This account's Telegram contacts, by name.
  ///
  /// **No device permission.** These are the contacts Telegram already holds
  /// for this account, which is what somebody sharing a contact from a Telegram
  /// client is choosing from anyway — reading the phone's address book would
  /// mean asking for it, and would offer people who are not on Telegram and
  /// therefore cannot be sent as a Telegram contact.
  ///
  /// One request, when the picker opens. `GetContacts` answers with ids and
  /// TDLib has already volunteered the user records behind them through
  /// `UpdateUser`, so there is no per-contact lookup after it.
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
        (a, b) => a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        ),
      );
      return profiles;
    } catch (e) {
      debugPrint('[ChatsRepo] contacts failed: $e');
      return const [];
    }
  }

  /// Opens self-destructing media, which starts its clock.
  ///
  /// This is the one request in the app that *destroys* something, and it is
  /// irreversible: Telegram treats the call as "this person has now seen it",
  /// tells the sender so, and — for view-once media — the content is gone the
  /// moment the viewer closes it. Nothing calls this on the reader's behalf.
  /// It is wired to a deliberate tap on a cover that says what will happen.
  ///
  /// The expiry itself arrives back on `updateMessageContent` as
  /// `messageExpiredPhoto`, so nothing here has to guess when it happened.
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
      // A photo's or a file's words are its caption, and Telegram refuses to
      // turn media into text — so "Edit" on one always failed while it sent
      // `EditMessageText`.
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

  /// Deletes messages. [revoke] deletes them for everybody rather than just
  /// this account — irreversible, which is why the caller confirms first.
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

  /// What this account may do with one message.
  ///
  /// Asked per message and only when the reader long-presses one, never for a
  /// page of them. TDLib documents `getMessageProperties` as an **offline**
  /// request, so this costs no network round trip — but the fan-out rule
  /// is about shape as much as cost, and forty of anything on
  /// opening a screen is the shape that goes wrong when a future TDLib changes
  /// its mind about what is local.
  ///
  /// The alternative was worse: guessing. Telegram's rules for what can be
  /// edited or revoked depend on the chat type, the age of the message, who
  /// sent it and the account's own rights — reimplementing that here would
  /// offer a Delete that fails and an Edit that isn't allowed, which is the
  /// inert-control bug the hard rules name.
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

  /// Pins a message to the top of the chat, or takes the pin off.
  ///
  /// [isPinned] is the state being moved *to*, matching [setPinned] and
  /// [setMuted] — every toggle in this repository takes the destination rather
  /// than the current value, so a caller cannot invert one by accident.
  ///
  /// A pin is visible to everybody in the chat and notifies them, which is why
  /// `disableNotification` is true: gramX pins from a long-press menu with no
  /// second step, and silently pinning is the recoverable half of a mis-tap.
  /// Telegram's own clients ask; ours does too, at the call site.
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

  /// How long a message survives in this chat before Telegram deletes it, in
  /// seconds. Zero means never, which is every chat's default.
  int autoDeleteTime(int chatId) =>
      _chatCache.chat(chatId)?.messageAutoDeleteTime ?? 0;

  /// Sets the chat's auto-delete timer. [seconds] of zero turns it off.
  ///
  /// Chat-wide and two-sided: it applies to everything either side sends from
  /// now on, both people see the change, and Telegram posts a service notice
  /// about it. Distinct from the per-message self-destruct, which the
  /// sender chooses for one picture.
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

  /// Adds or removes one of this account's reactions on a message.
  Future<void> toggleReaction({
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
    } catch (e) {
      debugPrint('[ChatsRepo] react on $chatId/$messageId failed: $e');
    }
  }

  /// The reactions offered for one message, best first.
  ///
  /// Asked per message, alongside [messageActions], and for the same reason:
  /// it is the long-press that needs the answer, and never a page of bubbles.
  ///
  /// Reading `chat.availableReactions` instead was the obvious shortcut and it
  /// was **wrong**: that field is a `ChatAvailableReactionsSome` only where a
  /// group has restricted the set, and every ordinary private chat reports
  /// `ChatAvailableReactionsAll` — which names no emoji at all. So the picker
  /// came up empty in exactly the chats a reader spends their time in, and the
  /// reaction row looked unimplemented. `getMessageAvailableReactions` answers
  /// the real question, ordered the way Telegram itself orders it.
  ///
  /// Premium-only reactions are dropped rather than offered and refused.
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
      // Top first, then recent, then popular — Telegram's own precedence.
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

  /// How many reactions the picker shows in its row. Telegram takes this as a
  /// layout hint and orders its answer around it.
  static const int reactionRowSize = 8;

  /// Tells the other side this account is typing, or has stopped.
  ///
  /// Telegram expects this roughly every five seconds while typing continues,
  /// and the caller throttles to that — a per-keystroke send is exactly the
  /// shape the request budget forbids.
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

  /// Saves what the reader has typed but not sent, so it survives leaving the
  /// screen — and follows them to their other Telegram clients, which is what
  /// a draft means everywhere else.
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

  /// The chat id for Saved Messages, creating it if it does not exist yet.
  ///
  /// Telegram models notes-to-self as a private chat with your own user, so the
  /// id *is* [selfUserId] — but the chat only exists once something has opened
  /// it, and on a fresh account nothing has. `CreatePrivateChat` is idempotent:
  /// it returns the existing chat when there is one, so this is safe to call on
  /// every tap and costs nothing once the cache knows the chat.
  ///
  /// Null when the account record has not loaded, which is the honest answer —
  /// there is no way to know which private chat is yours without it.
  Future<int?> savedMessagesChatId(int? selfUserId) async {
    if (selfUserId == null) return null;
    if (_chatCache.chat(selfUserId) != null) return selfUserId;

    try {
      final res = await _tdlib.sendRequest(
        td.CreatePrivateChat(userId: selfUserId, force: false),
      );
      return res is td.Chat ? res.id : null;
    } catch (e) {
      debugPrint('[ChatsRepo] savedMessages failed: $e');
      return null;
    }
  }

  /// Pins a chat to the top of the main list, or unpins it.
  ///
  /// Scoped to `ChatListMain` explicitly: a pin is per chat list, and pinning
  /// into the archive from a screen that shows the main list would move a chat
  /// the reader cannot see.
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
      // Telegram caps how many chats may be pinned, and answers with an error
      // rather than silently ignoring the extra one — so this is a real
      // failure the caller has to be able to report.
      debugPrint('[ChatsRepo] pin($chatId) failed: $e');
      return false;
    }
  }

  /// Silences a chat, or unsilences it.
  ///
  /// `muteFor` is seconds and TDLib takes the *maximum* int as "forever", which
  /// is what Telegram's own mute-with-no-end-date sends. Unmuting hands the
  /// chat back to the account-wide default rather than pinning it to zero —
  /// otherwise a chat unmuted here would stop following a default the reader
  /// later changes.
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

  /// Telegram's "muted with no end date". Not a magic number of this app's
  /// choosing — it is what the official clients send.
  static const int muteForever = 2147483647;

  /// Whether a chat is somewhere this account can *leave* — a group — as
  /// opposed to a one-to-one chat, which can only be deleted.
  bool canLeave(int chatId) {
    final type = _chatCache.chat(chatId)?.type;
    return type is td.ChatTypeBasicGroup ||
        (type is td.ChatTypeSupergroup && !type.isChannel);
  }

  /// Whether deleting this chat can take the history away from the other
  /// person too. Telegram's own answer, carried on the chat.
  bool canDeleteForBoth(int chatId) =>
      _chatCache.chat(chatId)?.canBeDeletedForAllUsers ?? false;

  /// Takes a one-to-one chat off the list, with its history.
  ///
  /// Irreversible, so the screen confirms first. [revoke] deletes it for the
  /// other person as well, and is only offered where [canDeleteForBoth] says
  /// Telegram allows it. A secret chat is closed before it is deleted:
  /// deleting the history of a live end-to-end session would leave the session
  /// itself open on both devices.
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

  /// Leaves a group, and takes it off the list.
  ///
  /// A supergroup drops off the list by itself once left. A basic group does
  /// not — Telegram keeps it as a read-only chat — so its history is deleted
  /// from the list as well, which is what "Leave" means in every client.
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

  /// Whether this account has blocked [userId]. Read from the chat with them,
  /// which TDLib keeps current, so asking costs nothing.
  bool isBlocked(int userId) => _chatCache.chat(userId)?.blockList != null;

  /// Blocks or unblocks a person. They can no longer message this account, and
  /// Telegram tells nobody.
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

  /// Puts away the "you don't know this person" bar without doing anything
  /// else — the reader looked, and the chat is fine.
  Future<void> dismissRequest(int chatId) async {
    try {
      await _tdlib.sendRequest(td.RemoveChatActionBar(chatId: chatId));
    } catch (e) {
      debugPrint('[ChatsRepo] dismiss request in $chatId failed: $e');
    }
  }

  /// Forwards messages into another chat, with attribution.
  ///
  /// `sendCopy: false`, so the destination shows "Forwarded from …" rather than
  /// silently reattributing somebody else's words to the sender — the same
  /// choice `FeedRepository.forwardPost` makes, for the same reason.
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

  /// Chats this account can forward into, best destination first.
  ///
  /// Read straight from [ChatCache] — the same source and the same rules the
  /// post forward picker uses, so opening it costs no requests.
  List<ChatSummary> forwardTargets({int? selfUserId}) => ChatListBuilder.build(
    _chatCache.forwardTargets,
    users: _chatCache.usersById,
    supergroups: _chatCache.supergroupsById,
    selfUserId: selfUserId,
  );

  /// What a `@username` refers to, so a tap can go to the right screen.
  ///
  /// Networked and one request per tap, which is the on-demand shape
  /// the request budget allows — a mention is only resolved when somebody touches
  /// it. Answers the chat id and what kind of chat it is, because those go to
  /// different places: a channel to the channel screen, a group to its
  /// conversation, a person to them. Null when Telegram does not know the name.
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

  /// Which screen a resolved chat belongs on. Pure, so the rule is testable.
  static ResolvedChatKind resolvedKindOf(td.ChatType type) => switch (type) {
    td.ChatTypePrivate() || td.ChatTypeSecret() => ResolvedChatKind.person,
    td.ChatTypeSupergroup(:final isChannel) when isChannel =>
      ResolvedChatKind.channel,
    _ => ResolvedChatKind.group,
  };

  /// One person's profile.
  ///
  /// **Two requests, and only when somebody opens a profile.** `GetUser` is
  /// skipped entirely when the chat cache already holds the record, which it
  /// usually does — TDLib volunteers a `User` for everyone it loads a chat
  /// for. `GetUserFullInfo` is the one that always costs something, and it is
  /// the half that carries the bio, the groups in common and the channel this
  /// person runs. That is the on-demand, user-driven, bounded shape
  /// the request budget allows; what it must never become is a lookup per row of
  /// a list — see [ChatSummary.affiliatedChannelId].
  ///
  /// The full record is filed back into the cache on the way out, so the chat
  /// list can show that person's channel afterwards for free.
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
        // Only if the cache already knows the channel. Fetching it would be a
        // third request for a line of text, and the row simply says less
        // without it.
        personalChannelTitle: personalChatId == 0
            ? null
            : _chatCache.chat(personalChatId)?.title,
      );
    } catch (e) {
      debugPrint('[ChatsRepo] userProfile($userId) failed: $e');
      return null;
    }
  }

  /// Fetches one person's full record into the cache, if it is not there.
  ///
  /// Returns whether the cache now has it. What it carries that the chat list
  /// wants is the channel they run — see [ChatSummary.affiliatedChannelId] —
  /// and the channel itself is fetched too when the cache has never met it,
  /// otherwise the badge would draw as a question mark. Two requests at
  /// most, and only ever from [AffiliationPrefetcher], which decides who is
  /// worth asking about and how fast.
  Future<bool> ensureUserFullInfo(int userId) async {
    if (_chatCache.userFullInfosById.containsKey(userId)) return true;
    final res = await _tdlib.sendRequest(td.GetUserFullInfo(userId: userId));
    if (res is! td.UserFullInfo) return false;
    _chatCache.rememberUserFullInfo(userId, res);

    final personalChatId = res.personalChatId;
    if (personalChatId != 0 && _chatCache.chat(personalChatId) == null) {
      // A `GetChat` answers through `updateNewChat`, which is how the cache
      // learns titles; the reply itself is not needed.
      try {
        await _tdlib.sendRequest(td.GetChat(chatId: personalChatId));
      } catch (e) {
        debugPrint('[ChatsRepo] personal chat $personalChatId: $e');
      }
    }
    return true;
  }

  /// Sends a failed message again.
  ///
  /// The one recovery path for `MessageSendState.failed`: Telegram will not
  /// retry by itself, so without this a refused message sits in the chat
  /// forever with a warning on it and nothing the reader can do. TDLib keeps
  /// the content, so this needs the id and nothing else.
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

  /// Chats matching [query], for the "new message" picker.
  ///
  /// `SearchChats` is one of TDLib's offline methods — it searches the titles
  /// and usernames of chats already loaded and never reaches the server — so
  /// this is free to call as somebody types. It is registered as local-only in
  /// `TdlibService`, which keeps it off the budget and out of the flood gate.
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
