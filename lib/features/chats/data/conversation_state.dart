import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chat_events.dart';
import 'package:gramx/features/chats/data/chat_message_mapper.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';

/// Who is doing something in the chat right now, and what.
@immutable
class ChatTyping {
  final int? userId;

  /// Their name in a group. Null in a private chat.
  final String? name;

  /// The verb phrase, such as "typing" or "sending a photo".
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

/// One conversation, oldest message first, and the pure rules for folding live
/// updates into it.
@immutable
class ConversationState {
  /// How long a typing indicator survives without another update. TDLib does
  /// not guarantee a `chatActionCancel`, so indicators expire on a timer.
  static const Duration typingTimeout = Duration(seconds: 6);

  final int chatId;
  final bool isGroup;
  final List<ChatMessage> messages;

  /// The chat's outbox cursor: everything at or below it has been read by the
  /// other side.
  final int lastReadOutboxMessageId;
  final ChatTyping? typing;

  /// False once the top of the chat has been reached.
  final bool hasMoreOlder;

  /// True while what is loaded stops short of the newest message, after a
  /// jump with [windowed]. Live arrivals are not folded in while this is set.
  final bool hasMoreNewer;

  /// The oldest unseen message when the chat was opened. Set once on open so
  /// the unread band and the scroll anchor don't move as messages are read.
  final int? firstUnreadMessageId;

  const ConversationState({
    required this.chatId,
    this.isGroup = false,
    this.messages = const [],
    this.lastReadOutboxMessageId = 0,
    this.typing,
    this.hasMoreOlder = true,
    this.hasMoreNewer = false,
    this.firstUnreadMessageId,
  });

  ConversationState copyWith({
    List<ChatMessage>? messages,
    int? lastReadOutboxMessageId,
    bool? hasMoreOlder,
    bool? hasMoreNewer,
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
      hasMoreNewer: hasMoreNewer ?? this.hasMoreNewer,
      firstUnreadMessageId: firstUnreadMessageId,
    );
  }

  /// The oldest incoming message past [lastReadInboxMessageId] in what is
  /// loaded, or null if there is none.
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

  /// The order [messages] is kept in: oldest first, then unsent messages.
  /// Optimistic ids are negative and count down as they are handed out, so -1
  /// sorts before -2.
  static int compareOrder(ChatMessage a, ChatMessage b) {
    final aPending = a.messageId < 0;
    final bPending = b.messageId < 0;
    if (aPending != bPending) return aPending ? 1 : -1;
    return aPending
        ? b.messageId.compareTo(a.messageId)
        : a.messageId.compareTo(b.messageId);
  }

  /// The newest message, or null on an empty chat.
  ChatMessage? get newest => messages.isEmpty ? null : messages.last;

  /// The newest sent message id, used as the cursor for the page below.
  /// Skips optimistic bubbles, whose negative ids mean nothing to TDLib.
  int? get newestMessageId {
    for (final message in messages.reversed) {
      if (message.messageId > 0) return message.messageId;
    }
    return null;
  }

  /// The oldest loaded message id, used as the cursor for the next older page.
  int? get oldestMessageId =>
      messages.isEmpty ? null : messages.first.messageId;

  /// Incoming messages not yet marked read, newest first.
  List<int> unreadIncomingIds(int lastReadInboxMessageId) => [
    for (final message in messages.reversed)
      if (!message.isOutgoing &&
          !message.isService &&
          message.messageId > lastReadInboxMessageId)
        message.messageId,
  ];

  /// Folds one event in. Returns null when nothing about this conversation
  /// changed, including for events from other chats.
  ConversationState? apply(
    ChatEvent event, {
    required Map<int, td.User> users,
    Map<int, td.Chat> chats = const {},
  }) {
    if (event.chatId != chatId) return null;

    switch (event) {
      case ChatMessageArrived():
        // Not adjacent to a window that stops short of the bottom. The page
        // fetch that reaches the bottom brings it in.
        if (hasMoreNewer) return null;
        // TDLib sends a same-chat reply without a preview of its target.
        final arrived = ChatMessageMapper.fillReplyExcerpts([
          _map(event.message, users: users, chats: chats),
        ], from: messages).single;
        return _upsert(arrived);

      case ChatMessageSent():
        // Replace the optimistic bubble, which is keyed on the temporary id.
        return _replaceId(
          event.oldMessageId,
          _map(event.message, users: users, chats: chats),
        );

      case ChatMessageFailed():
        return _replaceId(
          event.oldMessageId,
          _map(
            event.message,
            users: users,
            chats: chats,
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
        // Re-read everything the content decides: this update carries edited
        // captions, poll votes and expired self-destructing media.
        return _update(
          event.messageId,
          (message) => ChatMessageMapper.withContent(message, event.content),
        );

      case ChatMessagePinChanged():
        return _update(
          event.messageId,
          (message) => message.copyWith(isPinned: event.isPinned),
        );

      case ChatMessageEdited():
        return _update(
          event.messageId,
          (message) => message.copyWith(editedAt: event.editedAt),
        );

      case ChatOutboxRead():
        // The cursor only moves forwards, in case updates arrive out of order.
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

  /// Adds a page of older messages above what is loaded. [reachedTop] comes
  /// from the caller, since TDLib may return short pages before the top.
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
    merged.sort(compareOrder);
    // Replies already loaded may answer something in the new page.
    return copyWith(
      messages: ChatMessageMapper.fillReplyExcerpts(merged),
      hasMoreOlder: !reachedTop,
    );
  }

  /// Adds a page of newer messages below what is already loaded, for a
  /// conversation opened in the middle. [reachedBottom] comes from the caller.
  ConversationState append(
    List<ChatMessage> newer, {
    required bool reachedBottom,
  }) {
    final known = {for (final message in messages) message.messageId};
    final merged = [
      ...messages,
      for (final message in newer)
        if (!known.contains(message.messageId)) message,
    ];
    merged.sort(compareOrder);
    return copyWith(
      messages: ChatMessageMapper.fillReplyExcerpts(merged),
      hasMoreNewer: !reachedBottom,
    );
  }

  /// Replaces what is loaded with a stretch of history around one message,
  /// for jumping to a search hit beyond what paging has loaded.
  ConversationState windowed(
    List<ChatMessage> window, {
    required bool reachedTop,
    required bool reachedBottom,
  }) {
    final sorted = [...window]..sort(compareOrder);
    return copyWith(
      messages: sorted,
      hasMoreOlder: !reachedTop,
      hasMoreNewer: !reachedBottom,
      clearTyping: true,
    );
  }

  /// Shows a just-sent message before Telegram answers. [ChatMessageSent]
  /// replaces it later.
  ConversationState withOptimistic(ChatMessage message) => _upsert(message);

  ChatMessage _map(
    td.Message message, {
    required Map<int, td.User> users,
    Map<int, td.Chat> chats = const {},
  }) => ChatMessageMapper.map(
    message,
    users: users,
    lastReadOutboxMessageId: lastReadOutboxMessageId,
    isGroup: isGroup,
    chats: chats,
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
    // Sorted, not appended, because messages can arrive out of order.
    next.sort(compareOrder);
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

  /// Shows a vote before Telegram confirms it; `updateMessageContent` brings
  /// the real counts. Null when there is nothing to vote in.
  ConversationState? withOptimisticVote(int messageId, List<int> optionIds) {
    if (optionIds.isEmpty) return null;

    return _update(messageId, (message) {
      final poll = message.poll;
      if (poll == null || poll.isClosed || poll.chosenOptionIds.isNotEmpty) {
        return message;
      }

      final total = poll.totalVoterCount + 1;
      final options = [
        for (var i = 0; i < poll.options.length; i++)
          if (optionIds.contains(i))
            poll.options[i].copyWith(
              isChosen: true,
              voterCount: poll.options[i].voterCount + 1,
              votePercentage: (poll.options[i].voterCount + 1) * 100 / total,
            )
          else
            poll.options[i].copyWith(
              votePercentage: poll.options[i].voterCount * 100 / total,
            ),
      ];

      return message.copyWith(
        poll: poll.copyWith(
          options: options,
          totalVoterCount: total,
          chosenOptionIds: optionIds,
        ),
      );
    });
  }
}
