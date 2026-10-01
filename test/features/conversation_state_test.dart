import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chat_events.dart';
import 'package:gramx/features/chats/data/chat_message_mapper.dart';
import 'package:gramx/features/chats/data/conversation_state.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';

import '../support/td_fixtures.dart';

const int _chatId = -100500;
const int _me = 1;
const int _them = 2;

final _users = {
  _me: TdFixtures.user(id: _me, firstName: 'Me'),
  _them: TdFixtures.user(id: _them, firstName: 'Ada'),
};

ConversationState _empty({bool isGroup = false, int outboxCursor = 0}) =>
    ConversationState(
      chatId: _chatId,
      isGroup: isGroup,
      lastReadOutboxMessageId: outboxCursor,
    );

td.Message _incoming(int id, {String text = 'hi'}) => TdFixtures.chatMessage(
  id: id,
  chatId: _chatId,
  senderUserId: _them,
  text: text,
);

td.Message _outgoing(int id, {String text = 'hi', String? sendingState}) =>
    TdFixtures.chatMessage(
      id: id,
      chatId: _chatId,
      senderUserId: _me,
      text: text,
      isOutgoing: true,
      sendingState: sendingState,
    );

ConversationState _apply(ConversationState state, ChatEvent event) =>
    state.apply(event, users: _users) ?? state;

/// An incoming message as a page of history would carry it.
ChatMessage _mapped(int id) => ChatMessageMapper.map(
  _incoming(id),
  users: _users,
  lastReadOutboxMessageId: 0,
);

/// A bubble that has not left the device, keyed the way the notifier keys one.
ChatMessage _pending(int id) => ChatMessage(
  id: '${_chatId}_$id',
  chatId: _chatId,
  messageId: id,
  isOutgoing: true,
  text: 'on its way',
  sentAt: DateTime(2026),
  sendState: MessageSendState.sending,
);

void main() {
  group('arrivals', () {
    test('a message lands in the list', () {
      final state = _apply(_empty(), ChatMessageArrived(_incoming(100)));
      expect(state.messages.single.text, 'hi');
      expect(state.messages.single.isOutgoing, isFalse);
    });

    // A message can arrive out of order, and an append would put it below
    // something newer.
    test('out-of-order arrivals are sorted, not appended', () {
      var state = _apply(_empty(), ChatMessageArrived(_incoming(300)));
      state = _apply(state, ChatMessageArrived(_incoming(100)));
      expect(state.messages.map((m) => m.messageId), [100, 300]);
    });

    test('the same message twice is not two bubbles', () {
      var state = _apply(_empty(), ChatMessageArrived(_incoming(100)));
      state = _apply(state, ChatMessageArrived(_incoming(100)));
      expect(state.messages, hasLength(1));
    });

    // Checked on the state rather than at every subscription, so a caller
    // cannot forget.
    test('an event for another chat is ignored', () {
      final other = TdFixtures.chatMessage(
        id: 100,
        chatId: -999,
        senderUserId: _them,
      );
      expect(_empty().apply(ChatMessageArrived(other), users: _users), isNull);
    });
  });

  group('sending', () {
    // The optimistic bubble has a temporary id and must not linger next to
    // the real message.
    test('the real message replaces the optimistic one, id and all', () {
      final placeholder = ChatMessage(
        id: '${_chatId}_-1',
        chatId: _chatId,
        messageId: -1,
        isOutgoing: true,
        text: 'on its way',
        sentAt: DateTime(2026),
        sendState: MessageSendState.sending,
      );

      var state = _empty().withOptimistic(placeholder);
      expect(state.messages.single.messageId, -1);

      state = _apply(state, ChatMessageSent(_outgoing(900), -1));
      expect(state.messages, hasLength(1));
      expect(state.messages.single.messageId, 900);
      expect(state.messages.single.sendState, MessageSendState.sent);
    });

    test('a refused message keeps its place and says so', () {
      final placeholder = ChatMessage(
        id: '${_chatId}_-1',
        chatId: _chatId,
        messageId: -1,
        isOutgoing: true,
        sentAt: DateTime(2026),
        sendState: MessageSendState.sending,
      );
      var state = _empty().withOptimistic(placeholder);
      state = _apply(
        state,
        ChatMessageFailed(_outgoing(901), -1, 'MESSAGE_TOO_LONG'),
      );
      expect(state.messages.single.sendState, MessageSendState.failed);
    });

    // Optimistic ids are negative, so a plain numeric sort would put them on
    // top.
    test('an optimistic bubble sits below the conversation, not above it', () {
      var state = _apply(_empty(), ChatMessageArrived(_incoming(100)));
      state = _apply(state, ChatMessageArrived(_incoming(200)));
      state = state.withOptimistic(_pending(-1));

      expect(state.messages.map((m) => m.messageId), [100, 200, -1]);
      expect(state.newest?.messageId, -1);
      expect(
        state.oldestMessageId,
        100,
        reason: 'paging back starts from a real message',
      );
    });

    test('two messages sent back to back keep the order they were typed', () {
      var state = _apply(_empty(), ChatMessageArrived(_incoming(100)));
      state = state.withOptimistic(_pending(-1));
      state = state.withOptimistic(_pending(-2));

      expect(state.messages.map((m) => m.messageId), [100, -1, -2]);
    });

    test(
      'a message arriving while one is sending goes above the pending one',
      () {
        var state = _apply(_empty(), ChatMessageArrived(_incoming(100)));
        state = state.withOptimistic(_pending(-1));
        state = _apply(state, ChatMessageArrived(_incoming(300)));

        expect(state.messages.map((m) => m.messageId), [100, 300, -1]);
      },
    );

    test('a page of older history still lands above a pending message', () {
      var state = _apply(_empty(), ChatMessageArrived(_incoming(500)));
      state = state.withOptimistic(_pending(-1));
      final older = ChatMessageMapper.mapHistory(
        [_incoming(300), _incoming(400)],
        users: _users,
        lastReadOutboxMessageId: 0,
        isGroup: false,
      );
      state = state.prepend(older, reachedTop: false);

      expect(state.messages.map((m) => m.messageId), [300, 400, 500, -1]);
    });

    test('a pending message reads as sending', () {
      final state = _apply(
        _empty(),
        ChatMessageArrived(_outgoing(900, sendingState: 'pending')),
      );
      expect(state.messages.single.sendState, MessageSendState.sending);
    });
  });

  group('the read tick', () {
    test('turns sent into read for everything behind the cursor', () {
      var state = _apply(_empty(), ChatMessageArrived(_outgoing(100)));
      state = _apply(state, ChatMessageArrived(_outgoing(300)));
      expect(state.messages.map((m) => m.sendState), [
        MessageSendState.sent,
        MessageSendState.sent,
      ]);

      state = _apply(state, const ChatOutboxRead(_chatId, 100));
      expect(state.messages.map((m) => m.sendState), [
        MessageSendState.read,
        MessageSendState.sent,
      ]);
    });

    // An out-of-order update must not mark read messages unread again.
    test('the cursor only ever moves forwards', () {
      var state = _apply(_empty(), ChatMessageArrived(_outgoing(300)));
      state = _apply(state, const ChatOutboxRead(_chatId, 300));
      expect(state.messages.single.sendState, MessageSendState.read);

      expect(
        state.apply(const ChatOutboxRead(_chatId, 100), users: _users),
        isNull,
      );
    });

    test('an incoming message never carries one', () {
      var state = _apply(_empty(), ChatMessageArrived(_incoming(100)));
      state = _apply(state, const ChatOutboxRead(_chatId, 500));
      expect(state.messages.single.isOutgoing, isFalse);
      expect(state.messages.single.sendState, MessageSendState.sent);
    });
  });

  group('deletion', () {
    test('removes the messages named', () {
      var state = _apply(_empty(), ChatMessageArrived(_incoming(100)));
      state = _apply(state, ChatMessageArrived(_incoming(200)));
      state = _apply(state, const ChatMessagesDeleted(_chatId, [100], true));
      expect(state.messages.map((m) => m.messageId), [200]);
    });

    test('a delete for something not loaded changes nothing', () {
      final state = _apply(_empty(), ChatMessageArrived(_incoming(100)));
      expect(
        state.apply(
          const ChatMessagesDeleted(_chatId, [999], true),
          users: _users,
        ),
        isNull,
      );
    });
  });

  group('edits', () {
    test('new content replaces the text', () {
      var state = _apply(_empty(), ChatMessageArrived(_incoming(100)));
      state = _apply(
        state,
        ChatMessageContentChanged(
          _chatId,
          100,
          td.MessageText(
            text: const td.FormattedText(text: 'fixed', entities: []),
          ),
        ),
      );
      expect(state.messages.single.text, 'fixed');
    });

    test('the edited stamp is carried', () {
      var state = _apply(_empty(), ChatMessageArrived(_incoming(100)));
      final at = DateTime(2026, 8, 28, 11);
      state = _apply(state, ChatMessageEdited(_chatId, 100, at));
      expect(state.messages.single.editedAt, at);
    });
  });

  group('reactions', () {
    test('replace what the message had', () {
      var state = _apply(_empty(), ChatMessageArrived(_incoming(100)));
      state = _apply(
        state,
        const ChatReactionsChanged(_chatId, 100, {'❤️': 2}, {'❤️'}),
      );
      expect(state.messages.single.reactions, {'❤️': 2});
      expect(state.messages.single.chosenReactions, {'❤️'});
    });

    // An empty map, unlike an absent one, means the last reaction was removed.
    test('an empty map clears them', () {
      var state = _apply(_empty(), ChatMessageArrived(_incoming(100)));
      state = _apply(
        state,
        const ChatReactionsChanged(_chatId, 100, {'❤️': 1}, {'❤️'}),
      );
      state = _apply(state, const ChatReactionsChanged(_chatId, 100, {}, {}));
      expect(state.messages.single.reactions, isEmpty);
    });
  });

  group('typing', () {
    test('is held, and cleared by a cancel', () {
      var state = _apply(
        _empty(),
        const ChatActionChanged(_chatId, _them, 'typing'),
      );
      expect(state.typing?.action, 'typing');

      state = _apply(state, const ChatActionChanged(_chatId, _them, null));
      expect(state.typing, isNull);
    });

    test('names the person in a group and nobody in a private chat', () {
      final group = _apply(
        _empty(isGroup: true),
        const ChatActionChanged(_chatId, _them, 'typing'),
      );
      expect(group.typing?.name, 'Ada');

      final private = _apply(
        _empty(),
        const ChatActionChanged(_chatId, _them, 'typing'),
      );
      expect(private.typing?.name, isNull);
    });

    test('the same action twice is not a new state', () {
      final state = _apply(
        _empty(),
        const ChatActionChanged(_chatId, _them, 'typing'),
      );
      expect(
        state.apply(
          const ChatActionChanged(_chatId, _them, 'typing'),
          users: _users,
        ),
        isNull,
      );
    });
  });

  // TDLib sends a same-chat reply with no preview, so live replies are filled
  // from loaded messages too.
  group('reply previews', () {
    test('a reply arriving live is filled from what is on screen', () {
      var state = _apply(
        _empty(isGroup: true),
        ChatMessageArrived(_incoming(100, text: 'the question')),
      );
      state = _apply(
        state,
        ChatMessageArrived(
          TdFixtures.chatMessage(
            id: 200,
            chatId: _chatId,
            senderUserId: _them,
            text: 'the answer',
            replyToMessageId: 100,
          ),
        ),
      );

      final reply = state.messages.last;
      expect(reply.replyToText, 'the question');
      expect(reply.replyToAuthorName, 'Ada');
    });

    test('a reply already on screen is filled when its target pages in', () {
      var state = _apply(
        _empty(isGroup: true),
        ChatMessageArrived(
          TdFixtures.chatMessage(
            id: 200,
            chatId: _chatId,
            senderUserId: _them,
            text: 'the answer',
            replyToMessageId: 100,
          ),
        ),
      );
      expect(state.messages.single.replyToText, isNull);

      state = state.prepend(
        ChatMessageMapper.mapHistory(
          [_incoming(100, text: 'the question')],
          users: _users,
          lastReadOutboxMessageId: 0,
          isGroup: true,
        ),
        reachedTop: false,
      );

      expect(state.messages.last.replyToText, 'the question');
    });
  });

  group('paging back', () {
    test('older messages go above, without duplicating', () {
      var state = _apply(_empty(), ChatMessageArrived(_incoming(300)));
      final older = ChatMessageMapper.mapHistory(
        [_incoming(100), _incoming(200), _incoming(300)],
        users: _users,
        lastReadOutboxMessageId: 0,
      );

      state = state.prepend(older, reachedTop: false);
      expect(state.messages.map((m) => m.messageId), [100, 200, 300]);
      expect(state.hasMoreOlder, isTrue);
    });

    // TDLib picks its own batch size, so a short page doesn't mean the top.
    test('the caller decides when the top is reached', () {
      final state = _empty().prepend(const [], reachedTop: true);
      expect(state.hasMoreOlder, isFalse);
    });
  });

  group('what gets acknowledged as read', () {
    test('incoming messages past the cursor, and nothing else', () {
      var state = _apply(_empty(), ChatMessageArrived(_incoming(100)));
      state = _apply(state, ChatMessageArrived(_incoming(200)));
      state = _apply(state, ChatMessageArrived(_outgoing(300)));

      // Read state syncs to every device on the account, so it is decided
      // here rather than inferred from the viewport.
      expect(state.unreadIncomingIds(100), [200]);
      expect(state.unreadIncomingIds(0), [200, 100]);
      expect(state.unreadIncomingIds(999), isEmpty);
    });
  });

  // Jumping to an old search hit loads a window around it, detached from the
  // live end of the chat.
  group('a window in the middle', () {
    ConversationState window() =>
        _apply(
          _apply(_empty(), ChatMessageArrived(_incoming(100))),
          ChatMessageArrived(_incoming(101)),
        ).windowed(
          [_mapped(50), _mapped(51)],
          reachedTop: false,
          reachedBottom: false,
        );

    test('replaces what was loaded and opens both ends', () {
      final state = window();
      expect(state.messages.map((m) => m.messageId), [50, 51]);
      expect(state.hasMoreOlder, isTrue);
      expect(state.hasMoreNewer, isTrue);
    });

    test('a live arrival is not folded in while the bottom is off screen', () {
      final state = window();
      expect(
        state.apply(ChatMessageArrived(_incoming(200)), users: _users),
        isNull,
      );
    });

    test('a page below lands below, and reaching the bottom closes it', () {
      var state = window().append([_mapped(52)], reachedBottom: false);
      expect(state.messages.map((m) => m.messageId), [50, 51, 52]);
      expect(state.hasMoreNewer, isTrue);

      state = state.append([_mapped(53)], reachedBottom: true);
      expect(state.hasMoreNewer, isFalse);
      // Adjacent again, so arrivals fold in.
      expect(
        _apply(
          state,
          ChatMessageArrived(_incoming(200)),
        ).messages.last.messageId,
        200,
      );
    });

    test('a window that reaches the bottom is not a window at all', () {
      final state = window().windowed(
        [_mapped(60)],
        reachedTop: false,
        reachedBottom: true,
      );
      expect(state.hasMoreNewer, isFalse);
    });

    // The cursor the page below is fetched from has to be an id TDLib knows.
    test('the newest id skips a bubble that has not been sent', () {
      final state = window().withOptimistic(_pending(-1));
      expect(state.newestMessageId, 51);
      expect(_empty().newestMessageId, isNull);
    });
  });
}
