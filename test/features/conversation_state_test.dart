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
    // The optimistic bubble is keyed on a temporary id. Inserting the real
    // message without removing it leaves the sender looking at their own
    // message twice.
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

    // An out-of-order update that moved it back would un-read messages the
    // reader watched turn read.
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

    // An empty map is meaningful and different from absent: it is how the last
    // reaction being taken back arrives.
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

    // TDLib chooses its own batch size, so exhaustion is the caller's answer
    // rather than something inferred from a short page.
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

      // Read state is pushed to every client this account owns, so what is
      // acknowledged is decided here rather than inferred from the viewport.
      expect(state.unreadIncomingIds(100), [200]);
      expect(state.unreadIncomingIds(0), [200, 100]);
      expect(state.unreadIncomingIds(999), isEmpty);
    });
  });
}
