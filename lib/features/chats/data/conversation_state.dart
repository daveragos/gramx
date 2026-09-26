import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chat_events.dart';
import 'package:gramx/features/chats/data/chat_message_mapper.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';

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

  /// True while what is loaded stops short of the newest message.
  ///
  /// A conversation normally hangs off its bottom: the newest page is loaded
  /// and everything arrives below it. Jumping to a search hit further back
  /// than paging reaches breaks that — see [windowed] — and while it is
  /// broken a live arrival is *not* adjacent to what is on screen, so it is
  /// not folded in, and the way down is a page fetch rather than a scroll.
  /// Cleared by loading down to the bottom, or by going straight back to it.
  final bool hasMoreNewer;

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

  /// The order [messages] is kept in: oldest first, with messages that have not
  /// left the device yet after everything that has.
  ///
  /// An optimistic bubble carries a negative id (see
  /// `ConversationNotifier._optimisticMessage`), and a plain ascending sort put
  /// it *above* the whole conversation — the reader's own message appeared at
  /// the top of the chat until Telegram answered, and paging back asked TDLib
  /// for history older than a negative id. Temporary ids count down as they are
  /// handed out, so among themselves the order is reversed as well: -1 was
  /// typed before -2.
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

  /// The newest *sent* message id — the cursor the page below is fetched
  /// from. Skips optimistic bubbles, whose ids are negative and mean nothing
  /// to TDLib.
  int? get newestMessageId {
    for (final message in messages.reversed) {
      if (message.messageId > 0) return message.messageId;
    }
    return null;
  }

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
    Map<int, td.Chat> chats = const {},
  }) {
    if (event.chatId != chatId) return null;

    switch (event) {
      case ChatMessageArrived():
        // Not adjacent to a window that stops short of the bottom: folding it
        // in would draw a message from now directly under one from last year.
        // It is waiting below, and the page fetch that reaches the bottom
        // brings it in.
        if (hasMoreNewer) return null;
        // TDLib sends a same-chat reply with no preview of what it answers,
        // and a page is only filled once, when it loads — so a reply arriving
        // live drew a bare "Replying to" even with its target right above it.
        final arrived = ChatMessageMapper.fillReplyExcerpts([
          _map(event.message, users: users, chats: chats),
        ], from: messages).single;
        return _upsert(arrived);

      case ChatMessageSent():
        // The id changed. Replacing by the *old* id is the whole point: the
        // optimistic bubble is keyed on a temporary id, and inserting the real
        // message without removing it leaves the reader looking at their own
        // message twice.
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
        // Everything the content decides is re-read, not just the caption and
        // the media. This one update carries an edited caption, a vote landing
        // on a poll, and self-destructing media expiring into
        // `messageExpiredPhoto` — and the poll and the expiry were both dropped
        // while it only looked at two fields.
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
  /// one.
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
    // Replies already on screen may answer something in the page that just
    // arrived above them.
    return copyWith(
      messages: ChatMessageMapper.fillReplyExcerpts(merged),
      hasMoreOlder: !reachedTop,
    );
  }

  /// Adds a page of newer messages below what is already loaded.
  ///
  /// The mirror of [prepend], for a conversation that was opened in the
  /// middle. [reachedBottom] is the caller's answer, checked against the
  /// chat's own newest message rather than inferred from the page size.
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

  /// Replaces what is loaded with a stretch of history around one message.
  ///
  /// What a jump to a search hit does when the hit is further back than
  /// paging reaches: the conversation now reads from the middle, with more
  /// above and — unless the window happens to reach it — more below.
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
      // Whatever was being typed at is off screen now.
      clearTyping: true,
    );
  }

  /// Puts a message the reader has just sent on screen before Telegram has
  /// answered, so the bubble appears under their thumb rather than a round
  /// trip later. The live stream reconciles it — see [ChatMessageSent].
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
    // Sorted rather than appended: a message can arrive out of order, and an
    // append would put it below something newer.
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

  /// Shows a vote as taken before Telegram has confirmed it.
  ///
  /// A poll answer is a round trip, and a card that does nothing until it comes
  /// back reads as a tap that missed. The real counts land moments later on
  /// `updateMessageContent` and replace all of this — so the arithmetic here
  /// only has to be *plausible*, not authoritative: the chosen options are
  /// marked, one voter is added, and the percentages are recomputed from the
  /// new total.
  ///
  /// Answers null when there is nothing to do — no such message, not a poll,
  /// already closed, or already voted in — so the caller can tell a no-op from
  /// a change without comparing states.
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
