import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';

import '../support/td_fixtures.dart';

void main() {
  group('canPostIn', () {
    test('a private chat always takes a forward', () {
      expect(
        ChatCacheState.canPostIn(TdFixtures.privateChat(id: 7), null),
        isTrue,
      );
    });

    test('a channel you only read is not a destination', () {
      final chat = TdFixtures.chat(id: -100123, mainOrder: 10);
      final supergroup = TdFixtures.supergroup(
        id: 123,
        isChannel: true,
      ).supergroup;

      expect(ChatCacheState.canPostIn(chat, supergroup), isFalse);
    });

    test('a channel you can post to is', () {
      final chat = TdFixtures.chat(id: -100123, mainOrder: 10);
      final supergroup = TdFixtures.supergroup(
        id: 123,
        isChannel: true,
        status: TdFixtures.adminStatus(),
      ).supergroup;

      expect(ChatCacheState.canPostIn(chat, supergroup), isTrue);
    });

    test('an admin without posting rights still cannot', () {
      final chat = TdFixtures.chat(id: -100123, mainOrder: 10);
      final supergroup = TdFixtures.supergroup(
        id: 123,
        isChannel: true,
        status: TdFixtures.adminStatus(canPostMessages: false),
      ).supergroup;

      expect(ChatCacheState.canPostIn(chat, supergroup), isFalse);
    });

    test('your own channel is', () {
      final chat = TdFixtures.chat(id: -100123, mainOrder: 10);
      final supergroup = TdFixtures.supergroup(
        id: 123,
        isChannel: true,
        status: TdFixtures.creatorStatus(),
      ).supergroup;

      expect(ChatCacheState.canPostIn(chat, supergroup), isTrue);
    });

    test('a group where members may write is', () {
      final chat = TdFixtures.chat(
        id: -100456,
        isChannel: false,
        canSendBasicMessages: true,
        mainOrder: 10,
      );
      final supergroup = TdFixtures.supergroup(
        id: 456,
        isChannel: false,
      ).supergroup;

      expect(ChatCacheState.canPostIn(chat, supergroup), isTrue);
    });

    test('a group where members are muted is not', () {
      final chat = TdFixtures.chat(
        id: -100456,
        isChannel: false,
        canSendBasicMessages: false,
        mainOrder: 10,
      );
      final supergroup = TdFixtures.supergroup(
        id: 456,
        isChannel: false,
      ).supergroup;

      expect(ChatCacheState.canPostIn(chat, supergroup), isFalse);
    });

    test('a basic group falls back to its default permissions', () {
      expect(
        ChatCacheState.canPostIn(TdFixtures.basicGroupChat(id: -900), null),
        isFalse,
      );
    });
  });

  // Narrower than canPostIn: Telegram can accept messages but refuse polls.
  group('canSendPollsIn', () {
    test('a private chat with a person never takes a poll', () {
      expect(
        ChatCacheState.canSendPollsIn(TdFixtures.privateChat(id: 7), null),
        isFalse,
      );
    });

    test('a group that permits polls does', () {
      final chat = TdFixtures.chat(
        id: -100456,
        isChannel: false,
        canSendBasicMessages: true,
        canSendPolls: true,
        mainOrder: 10,
      );
      final supergroup = TdFixtures.supergroup(
        id: 456,
        isChannel: false,
      ).supergroup;

      expect(ChatCacheState.canSendPollsIn(chat, supergroup), isTrue);
    });

    test('a group that permits messages but not polls does not', () {
      final chat = TdFixtures.chat(
        id: -100456,
        isChannel: false,
        canSendBasicMessages: true,
        mainOrder: 10,
      );
      final supergroup = TdFixtures.supergroup(
        id: 456,
        isChannel: false,
      ).supergroup;

      expect(ChatCacheState.canSendPollsIn(chat, supergroup), isFalse);
    });

    test('a channel you only read does not', () {
      final chat = TdFixtures.chat(id: -100123, mainOrder: 10);
      final supergroup = TdFixtures.supergroup(
        id: 123,
        isChannel: true,
      ).supergroup;

      expect(ChatCacheState.canSendPollsIn(chat, supergroup), isFalse);
    });

    test('a channel you can post to does', () {
      final chat = TdFixtures.chat(id: -100123, mainOrder: 10);
      final supergroup = TdFixtures.supergroup(
        id: 123,
        isChannel: true,
        status: TdFixtures.adminStatus(),
      ).supergroup;

      expect(ChatCacheState.canSendPollsIn(chat, supergroup), isTrue);
    });
  });

  // Telegram grants media rights per kind, so a group can allow photos and
  // forbid voice notes. The composer shows one control per kind.
  group('canSendIn, per kind', () {
    test('a private chat takes every kind but a poll', () {
      final chat = TdFixtures.privateChat(id: 7);

      expect(
        ChatCacheState.canSendIn(chat, null, ChatSendRight.photos),
        isTrue,
      );
      expect(
        ChatCacheState.canSendIn(chat, null, ChatSendRight.voiceNotes),
        isTrue,
      );
      expect(
        ChatCacheState.canSendIn(chat, null, ChatSendRight.polls),
        isFalse,
      );
    });

    test('a group permits each kind separately', () {
      final chat = TdFixtures.chat(
        id: -100456,
        isChannel: false,
        canSendBasicMessages: true,
        canSendVoiceNotes: true,
        mainOrder: 10,
      );
      final supergroup = TdFixtures.supergroup(
        id: 456,
        isChannel: false,
      ).supergroup;

      expect(
        ChatCacheState.canSendIn(chat, supergroup, ChatSendRight.voiceNotes),
        isTrue,
      );
      // Allowing messages does not imply documents.
      expect(
        ChatCacheState.canSendIn(chat, supergroup, ChatSendRight.documents),
        isFalse,
      );
    });

    test('an admin is not bound by the members\' permissions', () {
      final chat = TdFixtures.chat(
        id: -100456,
        isChannel: false,
        mainOrder: 10,
      );
      final supergroup = TdFixtures.supergroup(
        id: 456,
        isChannel: false,
        status: TdFixtures.adminStatus(),
      ).supergroup;

      expect(
        ChatCacheState.canSendIn(chat, supergroup, ChatSendRight.voiceNotes),
        isTrue,
      );
    });

    test('a channel is an admin question, kind by kind', () {
      final chat = TdFixtures.chat(id: -100123, mainOrder: 10);
      final readOnly = TdFixtures.supergroup(
        id: 123,
        isChannel: true,
      ).supergroup;
      final mine = TdFixtures.supergroup(
        id: 123,
        isChannel: true,
        status: TdFixtures.creatorStatus(),
      ).supergroup;

      expect(
        ChatCacheState.canSendIn(chat, readOnly, ChatSendRight.photos),
        isFalse,
      );
      expect(
        ChatCacheState.canSendIn(chat, mine, ChatSendRight.photos),
        isTrue,
      );
    });
  });

  group('canSetAutoDeleteIn', () {
    test('either person may set it in a one-to-one chat', () {
      expect(
        ChatCacheState.canSetAutoDeleteIn(TdFixtures.privateChat(id: 7), null),
        isTrue,
      );
    });

    // In groups the timer needs the right to delete messages.
    test('an ordinary member of a group may not', () {
      final chat = TdFixtures.chat(
        id: -100456,
        isChannel: false,
        canSendBasicMessages: true,
        mainOrder: 10,
      );
      final supergroup = TdFixtures.supergroup(
        id: 456,
        isChannel: false,
      ).supergroup;

      expect(ChatCacheState.canSetAutoDeleteIn(chat, supergroup), isFalse);
    });

    test('the creator may', () {
      final chat = TdFixtures.chat(
        id: -100456,
        isChannel: false,
        mainOrder: 10,
      );
      final supergroup = TdFixtures.supergroup(
        id: 456,
        isChannel: false,
        status: TdFixtures.creatorStatus(),
      ).supergroup;

      expect(ChatCacheState.canSetAutoDeleteIn(chat, supergroup), isTrue);
    });
  });

  group('ChatCacheState.forwardTargets', () {
    test('lists only chats that can take a post, most recent first', () {
      final state = ChatCacheState();

      state.apply(TdFixtures.newChat(TdFixtures.privateChat(id: 7)));
      state.apply(
        TdFixtures.newChat(
          TdFixtures.chat(id: -100123, title: 'Read-only', mainOrder: 50),
        ),
      );
      state.apply(
        TdFixtures.newChat(
          TdFixtures.chat(
            id: -100456,
            title: 'My group',
            isChannel: false,
            canSendBasicMessages: true,
            mainOrder: 200,
          ),
        ),
      );
      state.apply(TdFixtures.supergroup(id: 123, isChannel: true));
      state.apply(TdFixtures.supergroup(id: 456, isChannel: false));

      expect(state.forwardTargets.map((c) => c.title), [
        'My group',
        'A Person',
      ]);
    });

    // A chat with no chat-list position is one the user is not in.
    test('a chat the user is not in is excluded', () {
      final state = ChatCacheState();
      state.apply(
        TdFixtures.newChat(TdFixtures.privateChat(id: 7)..positions.clear()),
      );

      expect(state.forwardTargets, isEmpty);
    });
  });
}
