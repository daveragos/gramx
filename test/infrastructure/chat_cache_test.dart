import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/infrastructure/telegram/chat_cache.dart';

import '../support/td_fixtures.dart';

void main() {
  group('ChatCacheState.apply', () {
    late ChatCacheState state;

    setUp(() => state = ChatCacheState());

    test('UpdateNewChat adds the chat', () {
      final chat = TdFixtures.chat(id: -100123, title: 'News');

      expect(state.apply(TdFixtures.newChat(chat)), isTrue);
      expect(state.chats[-100123]?.title, 'News');
    });

    test('UpdateChatLastMessage updates a known chat', () {
      final chat = TdFixtures.chat(id: -100123);
      state.apply(TdFixtures.newChat(chat));

      final message = TdFixtures.textMessage(id: 4194304, chatId: -100123);
      final changed = state.apply(
        TdFixtures.lastMessage(chatId: -100123, message: message, mainOrder: 90),
      );

      expect(changed, isTrue);
      expect(state.chats[-100123]?.lastMessage?.id, 4194304);
      expect(ChatCacheState.mainListOrder(state.chats[-100123]!), 90);
    });

    // The cold-start race: TDLib can emit a chat's last message before the
    // UpdateNewChat that introduces the chat. Dropping it loses that channel's
    // newest post until the next refresh.
    test('last message arriving before its chat is buffered, then flushed', () {
      final message = TdFixtures.textMessage(id: 4194304, chatId: -100123);

      final bufferedChange = state.apply(
        TdFixtures.lastMessage(chatId: -100123, message: message, mainOrder: 77),
      );

      expect(bufferedChange, isFalse, reason: 'nothing to change yet');
      expect(state.chats, isEmpty);
      expect(state.pendingLastMessages.containsKey(-100123), isTrue);

      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -100123)));

      expect(state.chats[-100123]?.lastMessage?.id, 4194304,
          reason: 'buffered message must survive and be applied');
      expect(ChatCacheState.mainListOrder(state.chats[-100123]!), 77);
      expect(state.pendingLastMessages, isEmpty);
    });

    test('updates for unknown chats are ignored, not crashed on', () {
      expect(
        state.apply(td.UpdateChatReadInbox(
          chatId: -999,
          lastReadInboxMessageId: 1,
          unreadCount: 5,
        )),
        isFalse,
      );
      expect(state.chats, isEmpty);
    });

    test('UpdateChatReadInbox updates the unread count', () {
      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -1, unreadCount: 9)));

      state.apply(td.UpdateChatReadInbox(
        chatId: -1,
        lastReadInboxMessageId: 100,
        unreadCount: 0,
      ));

      expect(state.chats[-1]?.unreadCount, 0);
    });

    test('UpdateChatTitle renames without dropping other fields', () {
      state.apply(TdFixtures.newChat(
        TdFixtures.chat(id: -1, title: 'Old', unreadCount: 3),
      ));

      state.apply(td.UpdateChatTitle(chatId: -1, title: 'New'));

      expect(state.chats[-1]?.title, 'New');
      expect(state.chats[-1]?.unreadCount, 3);
    });

    test('unrelated updates are ignored', () {
      expect(
        state.apply(const td.UpdateChatFolders(
          chatFolders: [],
          mainChatListPosition: 0,
          areTagsEnabled: false,
        )),
        isFalse,
      );
    });
  });

  group('ChatCacheState.mergePosition', () {
    test('replaces the position for the same list', () {
      final current = [TdFixtures.position(order: 10)];
      final merged = ChatCacheState.mergePosition(
        current,
        TdFixtures.position(order: 50),
      );

      expect(merged, hasLength(1));
      expect(merged.single.order, 50);
    });

    test('leaves positions in other lists alone', () {
      final current = [
        TdFixtures.position(order: 10),
        TdFixtures.position(order: 20, archive: true),
      ];

      final merged = ChatCacheState.mergePosition(
        current,
        TdFixtures.position(order: 99),
      );

      expect(merged, hasLength(2));
      expect(
        merged.firstWhere((p) => p.list is td.ChatListArchive).order,
        20,
      );
      expect(merged.firstWhere((p) => p.list is td.ChatListMain).order, 99);
    });

    // order 0 means "not in this list any more" — storing it would leave a dead
    // entry that sorts the chat to the bottom instead of removing it.
    test('order 0 removes the position rather than storing it', () {
      final current = [TdFixtures.position(order: 10)];
      final merged = ChatCacheState.mergePosition(
        current,
        TdFixtures.position(order: 0),
      );

      expect(merged, isEmpty);
    });
  });

  group('ChatCacheState.channels', () {
    test('returns only broadcast channels', () {
      final state = ChatCacheState();
      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -1, isChannel: true)));
      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -2, isChannel: false)));

      expect(state.channels.map((c) => c.id), [-1]);
    });

    test('sorts by main-list order, most recently active first', () {
      final state = ChatCacheState();
      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -1, mainOrder: 10)));
      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -2, mainOrder: 90)));
      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -3, mainOrder: 50)));

      expect(state.channels.map((c) => c.id), [-2, -3, -1]);
    });

    test('a chat with no main-list position sorts last, not crashes', () {
      final state = ChatCacheState();
      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -1, mainOrder: 0)));
      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -2, mainOrder: 5)));

      expect(state.channels.map((c) => c.id), [-2, -1]);
    });
  });

  group('ChatCacheState supergroups', () {
    test('UpdateSupergroup is mirrored and looked up by chat', () {
      final state = ChatCacheState();
      final chat = TdFixtures.chat(id: -1001234);
      state.apply(TdFixtures.newChat(chat));

      expect(state.supergroupForChat(chat), isNull,
          reason: 'nothing volunteered yet');

      final supergroupId = (chat.type as td.ChatTypeSupergroup).supergroupId;
      state.apply(TdFixtures.supergroup(
        id: supergroupId,
        memberCount: 4200,
        isVerified: true,
        username: 'news',
      ));

      final found = state.supergroupForChat(chat);
      expect(found?.memberCount, 4200);
      expect(found?.isVerified, isTrue);
      expect(found?.usernames?.activeUsernames.first, 'news');
    });

    test('a non-supergroup chat resolves to null instead of throwing', () {
      final state = ChatCacheState();
      // Basic-group chats have no supergroup id to look up.
      final chat = TdFixtures.basicGroupChat(id: -55);
      expect(state.supergroupForChat(chat), isNull);
    });
  });

  group('ChatCacheState.clear', () {
    test('drops chats and buffered messages', () {
      final state = ChatCacheState();
      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -1)));
      state.apply(TdFixtures.lastMessage(
        chatId: -99,
        message: TdFixtures.textMessage(id: 1, chatId: -99),
      ));

      state.apply(TdFixtures.supergroup(id: 7));

      state.clear();

      expect(state.chats, isEmpty);
      expect(state.supergroups, isEmpty);
      expect(state.pendingLastMessages, isEmpty);
    });
  });
}
