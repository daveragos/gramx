import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chat_list_builder.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';

import '../support/td_fixtures.dart';

/// The two things a row of the messages list now says that
/// it did not before — whether your own last message has been read, and which
/// channel the person you are talking to runs.
void main() {
  group('the delivery tick on a row', () {
    td.Chat chatWithLast(
      td.Message message, {
      int lastReadOutboxMessageId = 0,
      String? draftText,
    }) => TdFixtures.conversation(
      id: 7,
      userId: 7,
      lastMessage: message.toJson(),
      lastReadOutboxMessageId: lastReadOutboxMessageId,
      draftText: draftText,
    );

    test('a message from the other side gets no tick at all', () {
      final chat = chatWithLast(
        TdFixtures.chatMessage(id: 20, chatId: 7, senderUserId: 7),
      );

      expect(ChatListBuilder.sendStateOf(chat, chat.lastMessage), isNull);
    });

    test('an outgoing message behind the outbox cursor reads as read', () {
      final chat = chatWithLast(
        TdFixtures.chatMessage(
          id: 20,
          chatId: 7,
          senderUserId: 1,
          isOutgoing: true,
        ),
        lastReadOutboxMessageId: 20,
      );

      expect(
        ChatListBuilder.sendStateOf(chat, chat.lastMessage),
        MessageSendState.read,
      );
    });

    test('and ahead of it reads as sent', () {
      final chat = chatWithLast(
        TdFixtures.chatMessage(
          id: 30,
          chatId: 7,
          senderUserId: 1,
          isOutgoing: true,
        ),
        lastReadOutboxMessageId: 20,
      );

      expect(
        ChatListBuilder.sendStateOf(chat, chat.lastMessage),
        MessageSendState.sent,
      );
    });

    test('a queued message is still going, however far the cursor is', () {
      final chat = chatWithLast(
        TdFixtures.chatMessage(
          id: 30,
          chatId: 7,
          senderUserId: 1,
          isOutgoing: true,
          sendingState: 'pending',
        ),
        lastReadOutboxMessageId: 99,
      );

      expect(
        ChatListBuilder.sendStateOf(chat, chat.lastMessage),
        MessageSendState.sending,
      );
    });

    test('a refused message says so', () {
      final chat = chatWithLast(
        TdFixtures.chatMessage(
          id: 30,
          chatId: 7,
          senderUserId: 1,
          isOutgoing: true,
          sendingState: 'failed',
        ),
      );

      expect(
        ChatListBuilder.sendStateOf(chat, chat.lastMessage),
        MessageSendState.failed,
      );
    });

    test('an empty chat has nothing to tick', () {
      expect(
        ChatListBuilder.sendStateOf(TdFixtures.conversation(id: 7), null),
        isNull,
      );
    });

    // The regression this guards: a draft has not been sent, so a tick beside
    // one would claim the other side had seen something nobody sent.
    test('a draft wins the preview and carries no tick', () {
      final chat = chatWithLast(
        TdFixtures.chatMessage(
          id: 20,
          chatId: 7,
          senderUserId: 1,
          isOutgoing: true,
        ),
        lastReadOutboxMessageId: 20,
        draftText: 'half a thought',
      );

      final row = ChatListBuilder.summaryFor(
        chat,
        users: const {},
        supergroups: const {},
      );

      expect(row.previewIsDraft, isTrue);
      expect(row.previewSendState, isNull);
    });

    test('the row carries the same state the rule works out', () {
      final chat = chatWithLast(
        TdFixtures.chatMessage(
          id: 20,
          chatId: 7,
          senderUserId: 1,
          isOutgoing: true,
        ),
        lastReadOutboxMessageId: 20,
      );

      final row = ChatListBuilder.summaryFor(
        chat,
        users: const {},
        supergroups: const {},
      );

      expect(row.previewSendState, MessageSendState.read);
    });
  });

  group('the channel a person runs', () {
    final person = TdFixtures.conversation(id: 7, userId: 7, title: 'Ada');

    test('is absent when TDLib has volunteered no full record', () {
      final row = ChatListBuilder.summaryFor(
        person,
        users: const {},
        supergroups: const {},
      );

      expect(row.affiliatedChannelId, isNull);
      expect(row.affiliatedChannelTitle, isNull);
    });

    test('is absent when the record says there is none', () {
      final row = ChatListBuilder.summaryFor(
        person,
        users: const {},
        supergroups: const {},
        userFullInfos: {7: TdFixtures.userFullInfo()},
      );

      expect(row.affiliatedChannelId, isNull);
    });

    test('names the channel when the cache knows its title', () {
      final row = ChatListBuilder.summaryFor(
        person,
        users: const {},
        supergroups: const {},
        userFullInfos: {7: TdFixtures.userFullInfo(personalChatId: -100)},
        chatsById: {-100: TdFixtures.chat(id: -100, title: 'Ada Writes')},
      );

      expect(row.affiliatedChannelId, -100);
      expect(row.affiliatedChannelTitle, 'Ada Writes');
    });

    // Deliberately: resolving the title would be a `GetChat` per row, which is
    // the fan-out the request budget forbids. The id is still carried so the badge
    // can lead somewhere once a title turns up.
    test('carries the id with no title rather than fetching one', () {
      final row = ChatListBuilder.summaryFor(
        person,
        users: const {},
        supergroups: const {},
        userFullInfos: {7: TdFixtures.userFullInfo(personalChatId: -100)},
      );

      expect(row.affiliatedChannelId, -100);
      expect(row.affiliatedChannelTitle, isNull);
    });

    test('a group never claims one, whatever is in the map', () {
      final row = ChatListBuilder.summaryFor(
        TdFixtures.groupChat(id: -55),
        users: const {},
        supergroups: const {},
        userFullInfos: {55: TdFixtures.userFullInfo(personalChatId: -100)},
        chatsById: {-100: TdFixtures.chat(id: -100, title: 'Ada Writes')},
      );

      expect(row.affiliatedChannelId, isNull);
    });

    test('chats are keyed by id from what the cache already holds', () {
      final byId = ChatListBuilder.byId([
        TdFixtures.chat(id: -100, title: 'Ada Writes'),
        TdFixtures.conversation(id: 7, title: 'Ada'),
      ]);

      expect(byId.keys, containsAll(<int>[-100, 7]));
      expect(byId[-100]?.title, 'Ada Writes');
    });

    test('the badge carries the channel picture, not just its name', () {
      final row = ChatListBuilder.summaryFor(
        person,
        users: const {},
        supergroups: const {},
        userFullInfos: {7: TdFixtures.userFullInfo(personalChatId: -100)},
        chatsById: {
          -100: TdFixtures.chatWithPhoto(
            id: -100,
            photoFileId: 900,
            title: 'Ada Writes',
            localPath: '/tmp/channel.jpg',
          ),
        },
      );

      expect(row.affiliatedChannelAvatarPath, '/tmp/channel.jpg');
      expect(row.affiliatedChannelAvatarFileId, 900);
      expect(row.affiliatedChannelAvatarColorHex, isNotNull);
    });
  });
}
