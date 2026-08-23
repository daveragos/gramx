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

    // The reported bug: the picker listed every subscribed channel, and picking
    // one of them could only ever fail.
    test('a channel you only read is not a destination', () {
      final chat = TdFixtures.chat(id: -100123, mainOrder: 10);
      final supergroup =
          TdFixtures.supergroup(id: 123, isChannel: true).supergroup;

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
      final supergroup =
          TdFixtures.supergroup(id: 456, isChannel: false).supergroup;

      expect(ChatCacheState.canPostIn(chat, supergroup), isTrue);
    });

    test('a group where members are muted is not', () {
      final chat = TdFixtures.chat(
        id: -100456,
        isChannel: false,
        canSendBasicMessages: false,
        mainOrder: 10,
      );
      final supergroup =
          TdFixtures.supergroup(id: 456, isChannel: false).supergroup;

      expect(ChatCacheState.canPostIn(chat, supergroup), isFalse);
    });

    test('a basic group falls back to its default permissions', () {
      expect(
        ChatCacheState.canPostIn(TdFixtures.basicGroupChat(id: -900), null),
        isFalse,
      );
    });
  });

  group('ChatCacheState.forwardTargets', () {
    test('lists only chats that can take a post, most recent first', () {
      final state = ChatCacheState();

      state.apply(TdFixtures.newChat(TdFixtures.privateChat(id: 7)));
      state.apply(TdFixtures.newChat(
          TdFixtures.chat(id: -100123, title: 'Read-only', mainOrder: 50)));
      state.apply(TdFixtures.newChat(TdFixtures.chat(
        id: -100456,
        title: 'My group',
        isChannel: false,
        canSendBasicMessages: true,
        mainOrder: 200,
      )));
      state.apply(TdFixtures.supergroup(id: 123, isChannel: true));
      state.apply(TdFixtures.supergroup(id: 456, isChannel: false));

      expect(
        state.forwardTargets.map((c) => c.title),
        ['My group', 'A Person'],
      );
    });

    // A chat only in the cache because a forward origin was resolved by id has
    // no chat-list position, and is not somewhere the user can send anything.
    test('a chat the user is not in is excluded', () {
      final state = ChatCacheState();
      state.apply(TdFixtures.newChat(
          TdFixtures.privateChat(id: 7)..positions.clear()));

      expect(state.forwardTargets, isEmpty);
    });
  });
}
