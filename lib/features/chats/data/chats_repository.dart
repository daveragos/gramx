import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chat_list_builder.dart';
import 'package:gramx/features/chats/data/chat_message_mapper.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/data/user_profile_mapper.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/features/chats/domain/user_profile.dart';
import 'package:gramx/features/compose/data/compose_repository.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';
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
  );
}

/// A page of history, and whether it reached the top of the chat.
///
/// The two are returned together because the second cannot be inferred from the
/// first: TDLib chooses its own batch size, so a short page is not the end of
/// the history — see `docs/TDLIB.md`.
typedef HistoryPage = ({List<ChatMessage> messages, bool reachedTop});

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
    );
  }

  /// Whether this chat has more than two people in it, which decides whether
  /// bubbles carry a sender name.
  bool isGroupChat(int chatId) {
    final chat = _chatCache.chat(chatId);
    if (chat == null) return false;
    return chat.type is! td.ChatTypePrivate;
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
  /// shape `docs/TDLIB.md` allows, not a fan-out.
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
      isGroup: isGroupChat(chatId),
    );

    return (
      messages: ChatMessageMapper.fillReplyExcerpts(mapped),
      reachedTop: reachedTop,
    );
  }

  /// A page centred on the reader's unread cursor.
  ///
  /// `getChatHistory` walks *backwards* from `fromMessageId` by default, so
  /// asking from the read cursor returns only messages already read — the
  /// opposite of what an unread chat should open on. A **negative offset** is
  /// what TDLib gives you for this: it additionally returns messages *newer*
  /// than the anchor. The documented constraints are that it lies between -99
  /// and -1 and that `limit >= -offset`.
  ///
  /// So the window straddles the cursor: read context above, the unread run
  /// below. Falls back to the newest page when the chat has no cursor, or when
  /// the window comes back empty.
  Future<HistoryPage> historyAround(
    int chatId, {
    required int messageId,
    int limit = historyPageSize,
  }) async {
    if (messageId == 0) return history(chatId, limit: limit);

    // Half above, half below. The read side is context — enough to see what
    // was being answered — and the unread side is what the reader came for.
    final offset = -(limit ~/ 2);
    final batch = await _historyBatch(chatId, messageId, offset, limit);
    if (batch.isEmpty) return history(chatId, limit: limit);

    final mapped = ChatMessageMapper.mapHistory(
      batch,
      users: _chatCache.usersById,
      lastReadOutboxMessageId: lastReadOutboxMessageId(chatId),
      isGroup: isGroupChat(chatId),
    );
    return (
      messages: ChatMessageMapper.fillReplyExcerpts(mapped),
      // A window is never the top of the chat — there is always more above it,
      // and claiming otherwise would stop pagination before it started.
      reachedTop: false,
    );
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
  /// retries it. See `docs/TDLIB.md`.
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
  /// chat is declined silently and still answers `Ok`. See `docs/TDLIB.md`.
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
    int? replyToMessageId,
  }) async {
    final contents = ComposeMessages.build(
      text: text,
      attachments: attachments,
    );
    final replyTo = replyToMessageId == null
        ? null
        : td.InputMessageReplyToMessage(messageId: replyToMessageId);

    try {
      if (ComposeMessages.isAlbum(contents)) {
        final res = await _tdlib.sendRequest(
          td.SendMessageAlbum(
            chatId: chatId,
            messageThreadId: 0,
            replyTo: replyTo,
            options: _sendOptions,
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
          options: _sendOptions,
          inputMessageContent: contents.first,
        ),
      );
      return res is td.Message ? res : null;
    } catch (e) {
      debugPrint('[ChatsRepo] send to $chatId failed: $e');
      return null;
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
  }) async {
    try {
      final res = await _tdlib.sendRequest(
        td.EditMessageText(
          chatId: chatId,
          messageId: messageId,
          inputMessageContent: td.InputMessageText(
            text: td.FormattedText(text: text, entities: const []),
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
  /// request, so this costs no network round trip — but the fan-out rule in
  /// `docs/TDLIB.md` is about shape as much as cost, and forty of anything on
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
      );
    } catch (e) {
      debugPrint('[ChatsRepo] properties for $chatId/$messageId failed: $e');
      return MessageActionsNone.none;
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
  /// shape `docs/TDLIB.md` forbids.
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
  /// `docs/TDLIB.md` allows — a mention is only resolved when somebody touches
  /// it. Answers the chat id and whether it is a person, because those go to
  /// two different places: a channel to the channel screen, a person to a
  /// conversation with them. Null when Telegram does not know the name.
  Future<({int chatId, bool isPrivate})?> resolveUsername(
    String username,
  ) async {
    final handle = username.replaceFirst('@', '').trim();
    if (handle.isEmpty) return null;

    try {
      final res = await _tdlib.sendRequest(
        td.SearchPublicChat(username: handle),
      );
      if (res is! td.Chat) return null;
      return (chatId: res.id, isPrivate: res.type is td.ChatTypePrivate);
    } catch (e) {
      debugPrint('[ChatsRepo] resolve @$handle failed: $e');
      return null;
    }
  }

  /// One person's profile.
  ///
  /// **Two requests, and only when somebody opens a profile.** `GetUser` is
  /// skipped entirely when the chat cache already holds the record, which it
  /// usually does — TDLib volunteers a `User` for everyone it loads a chat
  /// for. `GetUserFullInfo` is the one that always costs something, and it is
  /// the half that carries the bio, the groups in common and the channel this
  /// person runs. That is the on-demand, user-driven, bounded shape
  /// `docs/TDLIB.md` allows; what it must never become is a lookup per row of
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
