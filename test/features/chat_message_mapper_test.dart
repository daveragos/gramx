import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chat_message_mapper.dart';
import 'package:gramx/features/chats/data/conversation_rows.dart';
import 'package:gramx/features/chats/data/conversation_state.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/presentation/widgets/chat_date_separator.dart';

import '../support/td_fixtures.dart';

const int _chatId = -100500;
const int _me = 1;
const int _them = 2;

final _users = {
  _me: TdFixtures.user(id: _me, firstName: 'Me'),
  _them: TdFixtures.user(id: _them, firstName: 'Ada', lastName: 'Lovelace'),
};

ChatMessage _map(td.Message message, {bool isGroup = false, int cursor = 0}) =>
    ChatMessageMapper.map(
      message,
      users: _users,
      lastReadOutboxMessageId: cursor,
      isGroup: isGroup,
    );

void main() {
  group('sender names', () {
    // In a private chat the two possible senders are the two people looking at
    // the screen, and naming them on every bubble is noise.
    test('only groups carry one', () {
      final message = TdFixtures.chatMessage(
        id: 10,
        chatId: _chatId,
        senderUserId: _them,
      );
      expect(_map(message, isGroup: true).senderName, 'Ada Lovelace');
      expect(_map(message).senderName, isNull);
    });
  });

  group('send state', () {
    test('a pending or failed send outranks any cursor', () {
      final pending = TdFixtures.chatMessage(
        id: 10,
        chatId: _chatId,
        senderUserId: _me,
        isOutgoing: true,
        sendingState: 'pending',
      );
      expect(
        ChatMessageMapper.sendStateOf(pending, lastReadOutboxMessageId: 999),
        MessageSendState.sending,
      );

      final failed = TdFixtures.chatMessage(
        id: 10,
        chatId: _chatId,
        senderUserId: _me,
        isOutgoing: true,
        sendingState: 'failed',
      );
      expect(
        ChatMessageMapper.sendStateOf(failed, lastReadOutboxMessageId: 999),
        MessageSendState.failed,
      );
    });

    test('read is decided by the outbox cursor', () {
      final message = TdFixtures.chatMessage(
        id: 100,
        chatId: _chatId,
        senderUserId: _me,
        isOutgoing: true,
      );
      expect(
        ChatMessageMapper.sendStateOf(message, lastReadOutboxMessageId: 100),
        MessageSendState.read,
      );
      expect(
        ChatMessageMapper.sendStateOf(message, lastReadOutboxMessageId: 99),
        MessageSendState.sent,
      );
    });

    // An incoming message has no send state to show, so it must not claim one.
    test('an incoming message is never read', () {
      final message = TdFixtures.chatMessage(
        id: 100,
        chatId: _chatId,
        senderUserId: _them,
      );
      expect(
        ChatMessageMapper.sendStateOf(message, lastReadOutboxMessageId: 999),
        MessageSendState.sent,
      );
    });
  });

  group('replies', () {
    test('a reply in the same chat carries no other chat id', () {
      final message = TdFixtures.chatMessage(
        id: 20,
        chatId: _chatId,
        senderUserId: _them,
        replyToMessageId: 10,
      );
      final mapped = _map(message);
      expect(mapped.replyToMessageId, 10);
      expect(mapped.replyToChatId, isNull);
    });

    // TDLib only inlines reply content for cross-chat replies and quotes, so a
    // reply within a chat arrives with no preview. In a conversation the answer
    // is almost always a few bubbles up — free, where the feed has to spend a
    // request on it.
    test('the excerpt is resolved from the page itself', () {
      final page = ChatMessageMapper.mapHistory(
        [
          TdFixtures.chatMessage(
            id: 10,
            chatId: _chatId,
            senderUserId: _them,
            text: 'the original',
          ),
          TdFixtures.chatMessage(
            id: 20,
            chatId: _chatId,
            senderUserId: _me,
            text: 'a reply',
            isOutgoing: true,
            replyToMessageId: 10,
          ),
        ],
        users: _users,
        lastReadOutboxMessageId: 0,
      );

      final filled = ChatMessageMapper.fillReplyExcerpts(page);
      expect(filled.last.replyToText, 'the original');
    });

    // A bare "replying to" line is honest. Inventing a preview is not.
    test('a reply to something off the page keeps its empty preview', () {
      final page = ChatMessageMapper.mapHistory(
        [
          TdFixtures.chatMessage(
            id: 20,
            chatId: _chatId,
            senderUserId: _me,
            replyToMessageId: 10,
          ),
        ],
        users: _users,
        lastReadOutboxMessageId: 0,
      );
      expect(
        ChatMessageMapper.fillReplyExcerpts(page).single.replyToText,
        isNull,
      );
    });
  });

  group('history order', () {
    // TDLib hands history back newest-first; a conversation reads oldest-first.
    test('is reversed into reading order', () {
      final page = ChatMessageMapper.mapHistory(
        [
          TdFixtures.chatMessage(id: 300, chatId: _chatId, senderUserId: _them),
          TdFixtures.chatMessage(id: 100, chatId: _chatId, senderUserId: _them),
          TdFixtures.chatMessage(id: 200, chatId: _chatId, senderUserId: _them),
        ],
        users: _users,
        lastReadOutboxMessageId: 0,
      );
      expect(page.map((m) => m.messageId), [100, 200, 300]);
    });
  });

  group('grouping into rows', () {
    ChatMessage at(int id, DateTime when, {int sender = _them}) => ChatMessage(
      id: '${_chatId}_$id',
      chatId: _chatId,
      messageId: id,
      isOutgoing: sender == _me,
      senderId: sender,
      text: 'x',
      sentAt: when,
    );

    test('a date band opens each day', () {
      final rows = ConversationRows.build([
        at(1, DateTime(2026, 8, 27, 10)),
        at(2, DateTime(2026, 8, 28, 10)),
      ]);
      expect(rows.whereType<ConversationDateRow>(), hasLength(2));
    });

    test('a run from one sender is one group', () {
      final rows = ConversationRows.build([
        at(1, DateTime(2026, 8, 28, 10, 0)),
        at(2, DateTime(2026, 8, 28, 10, 1)),
        at(3, DateTime(2026, 8, 28, 10, 2)),
      ]).whereType<ConversationMessageRow>().toList();

      expect(rows.map((r) => r.isFirstInGroup), [true, false, false]);
      expect(rows.map((r) => r.isLastInGroup), [false, false, true]);
    });

    // Longer than the window and a reply an hour later reads as part of the
    // previous thought.
    test('a long gap breaks the run', () {
      final rows = ConversationRows.build([
        at(1, DateTime(2026, 8, 28, 10, 0)),
        at(2, DateTime(2026, 8, 28, 11, 0)),
      ]).whereType<ConversationMessageRow>().toList();

      expect(rows.every((r) => r.isFirstInGroup && r.isLastInGroup), isTrue);
    });

    test('so does the other person answering', () {
      final rows = ConversationRows.build([
        at(1, DateTime(2026, 8, 28, 10, 0)),
        at(2, DateTime(2026, 8, 28, 10, 1), sender: _me),
      ]).whereType<ConversationMessageRow>().toList();

      expect(rows.every((r) => r.isFirstInGroup), isTrue);
    });

    // A message that opens a day opens a run, whoever sent the last one
    // yesterday.
    test('a day boundary breaks a run that would otherwise continue', () {
      final rows = ConversationRows.build([
        at(1, DateTime(2026, 8, 27, 23, 59)),
        at(2, DateTime(2026, 8, 28, 0, 1)),
      ]).whereType<ConversationMessageRow>().toList();

      expect(rows.map((r) => r.isFirstInGroup), [true, true]);
    });
  });

  group('the unread band', () {
    ChatMessage msg(int id, {bool outgoing = false, bool service = false}) =>
        ChatMessage(
          id: '${_chatId}_$id',
          chatId: _chatId,
          messageId: id,
          isOutgoing: outgoing,
          isService: service,
          senderId: outgoing ? _me : _them,
          text: 'x',
          sentAt: DateTime(2026, 8, 28, 10),
        );

    test('sits above the oldest message past the read cursor', () {
      final messages = [msg(100), msg(200), msg(300)];
      expect(ConversationState.firstUnreadIn(messages, 100), 200);
    });

    // Your own messages are not something you have to come back and read.
    test('skips outgoing and service messages', () {
      final messages = [
        msg(200, outgoing: true),
        msg(300, service: true),
        msg(400),
      ];
      expect(ConversationState.firstUnreadIn(messages, 100), 400);
    });

    test('is absent when there is no cursor or nothing behind it', () {
      expect(ConversationState.firstUnreadIn([msg(100)], 0), isNull);
      expect(ConversationState.firstUnreadIn([msg(100)], 100), isNull);
    });

    test('the band is drawn once, above that message', () {
      final rows = ConversationRows.build([
        msg(100),
        msg(200),
        msg(300),
      ], firstUnreadMessageId: 200);
      final bands = rows.whereType<ConversationUnreadRow>();
      expect(bands, hasLength(1));

      final index = rows.indexWhere((r) => r is ConversationUnreadRow);
      final next = rows[index + 1];
      expect(next, isA<ConversationMessageRow>());
      expect((next as ConversationMessageRow).message.messageId, 200);
    });

    // The screen scrolls to the band by walking up the scrollback until it has
    // been built — `ListView.builder` builds nothing far from the viewport, so
    // the band twenty rows up has no `BuildContext` for `ensureVisible` to find.
    // Knowing how far up it is, in the reversed order the list is drawn in, is
    // what tells the screen there is anything to walk towards.
    test('the band knows how far it is from the newest row', () {
      final rows = ConversationRows.build([
        msg(100),
        msg(200),
        msg(300),
        msg(400),
      ], firstUnreadMessageId: 300);

      final fromNewest = ConversationRows.unreadRowFromNewest(rows)!;

      // Counted in the reversed order the list draws: the two newest messages
      // sit below the band, so it is the third row from the bottom.
      expect(rows[rows.length - 1 - fromNewest], isA<ConversationUnreadRow>());
      expect(fromNewest, 2);
    });

    test('a band above everything is still found', () {
      final rows = ConversationRows.build([
        msg(100),
        msg(200),
      ], firstUnreadMessageId: 100);

      final fromNewest = ConversationRows.unreadRowFromNewest(rows)!;
      expect(rows[rows.length - 1 - fromNewest], isA<ConversationUnreadRow>());
    });

    // Nothing to walk towards. The screen has to be able to tell this apart
    // from "the band is a long way up", or it steps ten viewports for nothing.
    test('no band means no distance', () {
      expect(
        ConversationRows.unreadRowFromNewest(
          ConversationRows.build([msg(100)]),
        ),
        isNull,
      );
    });

    // A chat opened with nothing waiting gets no band at all, and an id that
    // paged out of the loaded window must not conjure one somewhere else.
    test('no band without a target, or for a target off the page', () {
      expect(
        ConversationRows.build([msg(100)]).whereType<ConversationUnreadRow>(),
        isEmpty,
      );
      expect(
        ConversationRows.build([
          msg(100),
        ], firstUnreadMessageId: 999).whereType<ConversationUnreadRow>(),
        isEmpty,
      );
    });
  });

  group('date labels', () {
    final now = DateTime(2026, 8, 28, 12);

    test('today and yesterday get their names', () {
      expect(ChatDateSeparator.label(DateTime(2026, 8, 28), now: now), 'Today');
      expect(
        ChatDateSeparator.label(DateTime(2026, 8, 27), now: now),
        'Yesterday',
      );
    });

    // Within this year the year is noise; outside it, it is the point.
    test('the year appears only when it differs', () {
      expect(
        ChatDateSeparator.label(DateTime(2026, 5, 1), now: now),
        isNot(contains('2026')),
      );
      expect(
        ChatDateSeparator.label(DateTime(2024, 5, 1), now: now),
        contains('2024'),
      );
    });
  });
}
