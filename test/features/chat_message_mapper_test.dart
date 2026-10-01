import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chat_message_mapper.dart';
import 'package:gramx/features/chats/data/conversation_rows.dart';
import 'package:gramx/features/chats/data/conversation_state.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/presentation/widgets/chat_date_separator.dart';
import 'package:gramx/features/feed/domain/media_item.dart';

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
  // Most channels leave the post signature blank, so the channel itself is
  // named as the author.
  test('a reply to a channel post is to that channel', () {
    final message = TdFixtures.replyingMessage(
      id: 20,
      chatId: _chatId,
      replyToMessageId: 7 << 20,
      replyToChatId: -100900,
      targetText: 'to the whole community',
      originChatId: -100900,
    );
    final channel = TdFixtures.chat(id: -100900, title: 'Self Made Coder');

    final mapped = ChatMessageMapper.map(
      message,
      users: _users,
      chats: {channel.id: channel},
      lastReadOutboxMessageId: 0,
      isGroup: true,
    );

    expect(mapped.replyToAuthorName, 'Self Made Coder');
  });

  // A photo has no text, so a reply to one needs a label of its own.
  group('what a reply quotes', () {
    ChatMessage photo({bool outgoing = true}) => ChatMessage(
      id: '${_chatId}_1',
      chatId: _chatId,
      messageId: 1,
      isOutgoing: outgoing,
      sentAt: DateTime(2026),
      media: const [
        MediaItem(
          id: 'p',
          type: MediaType.photo,
          fileId: 40,
          thumbnailFileId: 41,
        ),
      ],
    );
    ChatMessage replyTo(int id) => ChatMessage(
      id: '${_chatId}_2',
      chatId: _chatId,
      messageId: 2,
      isOutgoing: true,
      text: 'about that',
      sentAt: DateTime(2026),
      replyToMessageId: id,
    );

    test('a photo is quoted as what it is, with its thumbnail', () {
      final filled = ChatMessageMapper.fillReplyExcerpts([photo(), replyTo(1)]);
      final reply = filled.last;

      expect(reply.replyToText, 'Photo');
      expect(reply.replyToAuthorName, 'You');
      expect(reply.replyToThumbnailFileId, 41);
    });

    test("somebody else's in a one-to-one chat is not named", () {
      final filled = ChatMessageMapper.fillReplyExcerpts([
        photo(outgoing: false),
        replyTo(1),
      ]);
      expect(filled.last.replyToAuthorName, isNull);
      expect(filled.last.replyToText, 'Photo');
    });
  });

  group('sender names', () {
    // A user posting as their channel, or an anonymous admin posting as the
    // group, is a chat sender rather than a user.
    test('a message sent as a chat is named after that chat', () {
      final json = TdFixtures.textMessageJson(id: 11, chatId: _chatId);
      json['sender_id'] = {'@type': 'messageSenderChat', 'chat_id': -100900};
      json['is_outgoing'] = false;
      json['is_channel_post'] = false;
      final message = td.Message.fromJson(json);
      final channel = TdFixtures.chat(id: -100900, title: 'RaGoose dumps');

      final mapped = ChatMessageMapper.map(
        message,
        users: _users,
        chats: {channel.id: channel},
        lastReadOutboxMessageId: 0,
        isGroup: true,
      );

      expect(mapped.senderName, 'RaGoose dumps');
      expect(mapped.senderAvatarColorHex, isNotNull);
      // Not a person, so there is no profile for the avatar to open.
      expect(mapped.senderId, isNull);
    });

    // In a private chat both senders are obvious, so names would be noise.
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

    // TDLib only inlines reply content for cross-chat replies and quotes. A
    // reply within the chat usually quotes a message already on the page.
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

  // Service messages render as a line of text, or not at all, never as an
  // empty row.
  group('service lines', () {
    td.Message service(
      Map<String, dynamic> content, {
      int senderUserId = _them,
      int id = 30,
      int date = 1700000000,
    }) {
      final json = TdFixtures.textMessageJson(
        id: id,
        chatId: _chatId,
        date: date,
      );
      json['sender_id'] = {
        '@type': 'messageSenderUser',
        'user_id': senderUserId,
      };
      json['is_channel_post'] = false;
      json['content'] = content;
      return td.Message.fromJson(json);
    }

    test('say who joined, left, or was added', () {
      expect(
        _map(
          service({
            '@type': 'messageChatAddMembers',
            'member_user_ids': [_them],
          }),
          isGroup: true,
        ).text,
        'Ada Lovelace joined the group',
      );
      expect(
        _map(
          service({
            '@type': 'messageChatAddMembers',
            'member_user_ids': [_me],
          }),
          isGroup: true,
        ).text,
        'Ada Lovelace added Me',
      );
      expect(
        _map(
          service({'@type': 'messageChatDeleteMember', 'user_id': _them}),
          isGroup: true,
        ).text,
        'Ada Lovelace left the group',
      );
      expect(
        _map(service({'@type': 'messageChatJoinByLink'}), isGroup: true).text,
        'Ada Lovelace joined the group via invite link',
      );
    });

    test('a pin and a rename say what changed', () {
      expect(
        _map(
          service({'@type': 'messagePinMessage', 'message_id': 1}),
          isGroup: true,
        ).text,
        'Ada Lovelace pinned a message',
      );
      expect(
        _map(
          service({'@type': 'messageChatChangeTitle', 'title': 'Flutter'}),
          isGroup: true,
        ).text,
        'Ada Lovelace changed the group name to "Flutter"',
      );
    });

    test('a kind with nothing to say is left out, with its empty day', () {
      final day1 = DateTime(2026, 9, 19, 12).millisecondsSinceEpoch ~/ 1000;
      final day2 = DateTime(2026, 9, 20, 12).millisecondsSinceEpoch ~/ 1000;
      final messages = ChatMessageMapper.mapHistory(
        [
          // A theme change: no line for it.
          service(
            {'@type': 'messageChatSetTheme', 'theme_name': ''},
            id: 1,
            date: day1,
          ),
          TdFixtures.chatMessage(
            id: 2,
            chatId: _chatId,
            senderUserId: _them,
            date: day2,
          ),
        ],
        users: _users,
        lastReadOutboxMessageId: 0,
        isGroup: true,
      );

      final rows = ConversationRows.build(messages);
      expect(rows.whereType<ConversationDateRow>(), hasLength(1));
      expect(rows.whereType<ConversationMessageRow>(), hasLength(1));
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

    // Without a time limit, a reply an hour later would join the earlier run.
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

    // `ListView.builder` builds nothing far from the viewport, so the screen
    // walks up the scrollback to the band and needs to know how far it is.
    test('the band knows how far it is from the newest row', () {
      final rows = ConversationRows.build([
        msg(100),
        msg(200),
        msg(300),
        msg(400),
      ], firstUnreadMessageId: 300);

      final fromNewest = ConversationRows.unreadRowFromNewest(rows)!;

      // Counted from the bottom: the two newest messages sit below the band.
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

    // Must differ from "far up", or the screen scrolls for nothing.
    test('no band means no distance', () {
      expect(
        ConversationRows.unreadRowFromNewest(
          ConversationRows.build([msg(100)]),
        ),
        isNull,
      );
    });

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
