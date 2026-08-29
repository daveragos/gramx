import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chat_events.dart';
import 'package:gramx/features/chats/data/chat_message_mapper.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';

/// Who is doing something in the chat right now, and what.
@immutable
class ChatTyping {
  final int? userId;

  /// Their name, when the chat is a group and the reader needs to know which
  /// of several people it is. Null in a private chat, where there is only one
  /// possible answer.
  final String? name;

  /// The verb phrase — "typing", "sending a photo".
  final String action;

  const ChatTyping({this.userId, this.name, required this.action});

  @override
  bool operator ==(Object other) =>
      other is ChatTyping &&
      other.userId == userId &&
      other.name == name &&
      other.action == action;

  @override
  int get hashCode => Object.hash(userId, name, action);
}

/// One conversation, and the rules for folding live updates into it.
///
/// Pure state with no I/O, exactly like `ChatCacheState`, and for the same
/// reason: the folding is where the subtle bugs live. An optimistic bubble that
/// never gets its real id, a deletion that leaves a hole, a read tick that
/// never arrives — all of them are decisions taken here, and all of them are
/// testable without a TDLib client.
///
/// [messages] is ordered **oldest first**, which is the order a conversation is
/// read in and the order the list renders bottom-up from.
@immutable
class ConversationState {
  /// How long a typing indicator survives without another update.
  ///
  /// TDLib does not promise a `chatActionCancel` — somebody who types a word
  /// and closes the app never sends one — so an indicator that waits for it
  /// stays on screen forever. Telegram's own clients expire on a timer, and
  /// this is that timer, held here so the notifier and its test agree on one
  /// number.
  static const Duration typingTimeout = Duration(seconds: 6);

  final int chatId;
  final bool isGroup;
  final List<ChatMessage> messages;

  /// The chat's outbox cursor: everything at or below it has been read by the
  /// other side.
  final int lastReadOutboxMessageId;
  final ChatTyping? typing;

  /// False once a history page comes back short — the top of the chat.
  final bool hasMoreOlder;

  /// The oldest message the reader had not seen when they opened the chat.
  ///
  /// Captured **once, on open**, and never recomputed. It is where the unread
  /// band is drawn and where the list is anchored, and both of those are
  /// answers about the moment of arrival: recomputing as messages get
  /// acknowledged would walk the band down the screen under the reader.
  final int? firstUnreadMessageId;

  const ConversationState({
    required this.chatId,
    this.isGroup = false,
    this.messages = const [],
    this.lastReadOutboxMessageId = 0,
    this.typing,
    this.hasMoreOlder = true,
    this.firstUnreadMessageId,
  });

  ConversationState copyWith({
    List<ChatMessage>? messages,
    int? lastReadOutboxMessageId,
    bool? hasMoreOlder,
    ChatTyping? typing,
    bool clearTyping = false,
  }) {
    return ConversationState(
      chatId: chatId,
      isGroup: isGroup,
      messages: messages ?? this.messages,
      lastReadOutboxMessageId:
          lastReadOutboxMessageId ?? this.lastReadOutboxMessageId,
      typing: clearTyping ? null : (typing ?? this.typing),
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      firstUnreadMessageId: firstUnreadMessageId,
    );
  }

  /// The oldest incoming message past [lastReadInboxMessageId] in what is
  /// loaded, or null if there is none. Pure, so "where does the band go" is
  /// testable without a client.
  static int? firstUnreadIn(
    List<ChatMessage> messages,
    int lastReadInboxMessageId,
  ) {
    if (lastReadInboxMessageId == 0) return null;
    for (final message in messages) {
      if (!message.isOutgoing &&
          !message.isService &&
          message.messageId > lastReadInboxMessageId) {
        return message.messageId;
      }
    }
    return null;
  }

  /// The newest message, or null on an empty chat.
  ChatMessage? get newest => messages.isEmpty ? null : messages.last;

  /// The oldest loaded message id — the cursor the next page is fetched from.
  int? get oldestMessageId =>
      messages.isEmpty ? null : messages.first.messageId;

  /// Incoming messages the reader has not acknowledged yet, newest first.
  ///
  /// Read state is written to every client this account owns, so which messages
  /// get acknowledged is decided here — in a pure function with a test — rather
  /// than inferred from what happens to be on screen.
  List<int> unreadIncomingIds(int lastReadInboxMessageId) => [
    for (final message in messages.reversed)
      if (!message.isOutgoing &&
          !message.isService &&
          message.messageId > lastReadInboxMessageId)
        message.messageId,
  ];

  /// Folds one event in. Returns null when nothing about this conversation
  /// changed, so a notifier can skip the rebuild rather than churn the list.
  ///
  /// Events for other chats are not this state's business and answer null —
  /// checked here rather than at the subscription, so a caller cannot forget.
  ConversationState? apply(
    ChatEvent event, {
    required Map<int, td.User> users,
  }) {
    if (event.chatId != chatId) return null;

    switch (event) {
      case ChatMessageArrived():
        return _upsert(_map(event.message, users: users));

      case ChatMessageSent():
        // The id changed. Replacing by the *old* id is the whole point: the
        // optimistic bubble is keyed on a temporary id, and inserting the real
        // message without removing it leaves the reader looking at their own
        // message twice.
        return _replaceId(
          event.oldMessageId,
          _map(event.message, users: users),
        );

      case ChatMessageFailed():
        return _replaceId(
          event.oldMessageId,
          _map(
            event.message,
            users: users,
          ).copyWith(sendState: MessageSendState.failed),
        );

      case ChatMessagesDeleted():
        final ids = event.messageIds.toSet();
        final kept = [
          for (final message in messages)
            if (!ids.contains(message.messageId)) message,
        ];
        if (kept.length == messages.length) return null;
        return copyWith(messages: kept);

      case ChatMessageContentChanged():
        return _update(event.messageId, (message) {
          final content = event.content;
          return message.copyWith(
            text: _textOf(content) ?? message.text,
            media: TdlibMappers.extractMediaFromContent(content),
          );
        });

      case ChatMessageEdited():
        return _update(
          event.messageId,
          (message) => message.copyWith(editedAt: event.editedAt),
        );

      case ChatOutboxRead():
        // A cursor only ever moves forwards. An out-of-order update that moved
        // it back would un-read messages the reader watched turn read.
        if (event.lastReadOutboxMessageId <= lastReadOutboxMessageId) {
          return null;
        }
        final cursor = event.lastReadOutboxMessageId;
        return copyWith(
          lastReadOutboxMessageId: cursor,
          messages: [
            for (final message in messages)
              if (message.isOutgoing &&
                  message.messageId <= cursor &&
                  message.sendState == MessageSendState.sent)
                message.copyWith(sendState: MessageSendState.read)
              else
                message,
          ],
        );

      case ChatReactionsChanged():
        return _update(
          event.messageId,
          (message) => message.copyWith(
            reactions: event.reactions,
            chosenReactions: event.chosen,
          ),
        );

      case ChatActionChanged():
        // The reader's own actions come back on the stream too. Showing
        // "typing" to somebody about their own typing is absurd.
        final action = event.action;
        if (action == null) {
          return typing == null ? null : copyWith(clearTyping: true);
        }
        final user = event.userId == null ? null : users[event.userId];
        final next = ChatTyping(
          userId: event.userId,
          name: isGroup && user != null ? _nameOf(user) : null,
          action: action,
        );
        return next == typing ? null : copyWith(typing: next);
    }
  }

  /// Adds a page of older messages above what is already loaded.
  ///
  /// [reachedTop] is the caller's answer, not something inferred from the page
  /// size: TDLib chooses its own batch size and a short page is not an empty
  /// one — see `docs/TDLIB.md`.
  ConversationState prepend(
    List<ChatMessage> older, {
    required bool reachedTop,
  }) {
    final known = {for (final message in messages) message.messageId};
    final merged = [
      for (final message in older)
        if (!known.contains(message.messageId)) message,
      ...messages,
    ];
    merged.sort((a, b) => a.messageId.compareTo(b.messageId));
    return copyWith(messages: merged, hasMoreOlder: !reachedTop);
  }

  /// Puts a message the reader has just sent on screen before Telegram has
  /// answered, so the bubble appears under their thumb rather than a round
  /// trip later. The live stream reconciles it — see [ChatMessageSent].
  ConversationState withOptimistic(ChatMessage message) => _upsert(message);

  ChatMessage _map(td.Message message, {required Map<int, td.User> users}) =>
      ChatMessageMapper.map(
        message,
        users: users,
        lastReadOutboxMessageId: lastReadOutboxMessageId,
        isGroup: isGroup,
      );

  /// Inserts, or replaces in place if the id is already loaded.
  ConversationState _upsert(ChatMessage message) {
    final index = messages.indexWhere((m) => m.messageId == message.messageId);
    if (index >= 0) {
      final next = [...messages];
      if (next[index] == message) return this;
      next[index] = message;
      return copyWith(messages: next);
    }

    final next = [...messages, message];
    // Sorted rather than appended: a message can arrive out of order, and an
    // append would put it below something newer.
    next.sort((a, b) => a.messageId.compareTo(b.messageId));
    return copyWith(messages: next);
  }

  ConversationState _replaceId(int oldMessageId, ChatMessage message) {
    final without = [
      for (final m in messages)
        if (m.messageId != oldMessageId) m,
    ];
    return copyWith(messages: without)._upsert(message);
  }

  ConversationState? _update(
    int messageId,
    ChatMessage Function(ChatMessage) change,
  ) {
    final index = messages.indexWhere((m) => m.messageId == messageId);
    if (index < 0) return null;
    final updated = change(messages[index]);
    if (updated == messages[index]) return null;
    final next = [...messages];
    next[index] = updated;
    return copyWith(messages: next);
  }

  static String _nameOf(td.User user) {
    final name = '${user.firstName} ${user.lastName}'.trim();
    return name.isEmpty ? 'Someone' : name;
  }

  static String? _textOf(td.MessageContent content) => switch (content) {
    td.MessageText() => TdlibMappers.plainTextOf(content.text),
    td.MessagePhoto() => TdlibMappers.plainTextOf(content.caption),
    td.MessageVideo() => TdlibMappers.plainTextOf(content.caption),
    td.MessageAnimation() => TdlibMappers.plainTextOf(content.caption),
    td.MessageDocument() => TdlibMappers.plainTextOf(content.caption),
    td.MessageAudio() => TdlibMappers.plainTextOf(content.caption),
    td.MessageVoiceNote() => TdlibMappers.plainTextOf(content.caption),
    _ => null,
  };
}
