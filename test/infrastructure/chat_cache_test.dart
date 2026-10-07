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

    // A post counts as read once its id is behind the chat's read cursor.
    test(
      'UpdateChatReadInbox advances the read cursor, not just the count',
      () {
        state.apply(
          TdFixtures.newChat(TdFixtures.chat(id: -100123, unreadCount: 7)),
        );

        final changed = state.apply(
          td.UpdateChatReadInbox(
            chatId: -100123,
            lastReadInboxMessageId: 4194304,
            unreadCount: 2,
          ),
        );

        expect(changed, isTrue);
        expect(state.chats[-100123]?.lastReadInboxMessageId, 4194304);
        expect(state.chats[-100123]?.unreadCount, 2);
      },
    );

    // The composer kept the rights a group had when it loaded.
    test('UpdateChatPermissions changes what members may send', () {
      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -100123)));
      final permissions = state.chats[-100123]!.permissions.copyWith(
        canSendBasicMessages: true,
      );

      expect(
        state.apply(
          td.UpdateChatPermissions(chatId: -100123, permissions: permissions),
        ),
        isTrue,
      );
      expect(state.chats[-100123]!.permissions.canSendBasicMessages, isTrue);
    });

    test('UpdateChatReadInbox for an unknown chat changes nothing', () {
      expect(
        state.apply(
          td.UpdateChatReadInbox(
            chatId: -100999,
            lastReadInboxMessageId: 1,
            unreadCount: 0,
          ),
        ),
        isFalse,
      );
    });

    test('UpdateChatLastMessage updates a known chat', () {
      final chat = TdFixtures.chat(id: -100123);
      state.apply(TdFixtures.newChat(chat));

      final message = TdFixtures.textMessage(id: 4194304, chatId: -100123);
      final changed = state.apply(
        TdFixtures.lastMessage(
          chatId: -100123,
          message: message,
          mainOrder: 90,
        ),
      );

      expect(changed, isTrue);
      expect(state.chats[-100123]?.lastMessage?.id, 4194304);
      expect(ChatCacheState.mainListOrder(state.chats[-100123]!), 90);
    });

    // TDLib can send a chat's last message before the UpdateNewChat for it.
    test('last message arriving before its chat is buffered, then flushed', () {
      final message = TdFixtures.textMessage(id: 4194304, chatId: -100123);

      final bufferedChange = state.apply(
        TdFixtures.lastMessage(
          chatId: -100123,
          message: message,
          mainOrder: 77,
        ),
      );

      expect(bufferedChange, isFalse, reason: 'nothing to change yet');
      expect(state.chats, isEmpty);
      expect(state.pendingLastMessages.containsKey(-100123), isTrue);

      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -100123)));

      expect(
        state.chats[-100123]?.lastMessage?.id,
        4194304,
        reason: 'buffered message must survive and be applied',
      );
      expect(ChatCacheState.mainListOrder(state.chats[-100123]!), 77);
      expect(state.pendingLastMessages, isEmpty);
    });

    test('updates for unknown chats are ignored, not crashed on', () {
      expect(
        state.apply(
          td.UpdateChatReadInbox(
            chatId: -999,
            lastReadInboxMessageId: 1,
            unreadCount: 5,
          ),
        ),
        isFalse,
      );
      expect(state.chats, isEmpty);
    });

    test('UpdateChatReadInbox updates the unread count', () {
      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -1, unreadCount: 9)));

      state.apply(
        td.UpdateChatReadInbox(
          chatId: -1,
          lastReadInboxMessageId: 100,
          unreadCount: 0,
        ),
      );

      expect(state.chats[-1]?.unreadCount, 0);
    });

    test('a mention read on its own message lowers the chat\'s count', () {
      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -1)));
      state.apply(
        const td.UpdateChatUnreadMentionCount(
          chatId: -1,
          unreadMentionCount: 2,
        ),
      );

      state.apply(
        const td.UpdateMessageMentionRead(
          chatId: -1,
          messageId: 1048576,
          unreadMentionCount: 0,
        ),
      );

      expect(state.chats[-1]?.unreadMentionCount, 0);
    });

    test('reactions read on their own message lower the chat\'s count', () {
      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -1)));
      state.apply(
        const td.UpdateChatUnreadReactionCount(
          chatId: -1,
          unreadReactionCount: 1,
        ),
      );

      state.apply(
        const td.UpdateMessageUnreadReactions(
          chatId: -1,
          messageId: 1048576,
          unreadReactions: [],
          unreadReactionCount: 0,
        ),
      );

      expect(state.chats[-1]?.unreadReactionCount, 0);
    });

    test('UpdateChatTitle renames without dropping other fields', () {
      state.apply(
        TdFixtures.newChat(
          TdFixtures.chat(id: -1, title: 'Old', unreadCount: 3),
        ),
      );

      state.apply(td.UpdateChatTitle(chatId: -1, title: 'New'));

      expect(state.chats[-1]?.title, 'New');
      expect(state.chats[-1]?.unreadCount, 3);
    });

    test('unrelated updates are ignored', () {
      expect(
        state.apply(
          const td.UpdateChatFolders(
            chatFolders: [],
            mainChatListPosition: 0,
            areTagsEnabled: false,
          ),
        ),
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
      expect(merged.firstWhere((p) => p.list is td.ChatListArchive).order, 20);
      expect(merged.firstWhere((p) => p.list is td.ChatListMain).order, 99);
    });

    // Order 0 means the chat has left this list.
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
      state.apply(
        TdFixtures.newChat(
          TdFixtures.chat(id: -1, isChannel: true, mainOrder: 10),
        ),
      );
      state.apply(
        TdFixtures.newChat(
          TdFixtures.chat(id: -2, isChannel: false, mainOrder: 10),
        ),
      );

      expect(state.channels.map((c) => c.id), [-1]);
    });

    // Resolving a forward's origin adds that channel to the cache via GetChat.
    test('excludes channels the user is not subscribed to', () {
      final state = ChatCacheState();
      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -1, mainOrder: 10)));
      // No chat-list position: TDLib knows this chat, the user is not in it.
      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -2, mainOrder: 0)));

      expect(state.channels.map((c) => c.id), [-1]);
    });

    test('a chat in the archive still counts as subscribed', () {
      final state = ChatCacheState();
      state.apply(
        TdFixtures.newChat(
          TdFixtures.chat(
            id: -1,
            positions: [TdFixtures.archiveListPosition(order: 5)],
          ),
        ),
      );

      expect(state.channels.map((c) => c.id), [-1]);
    });

    test('isSubscribed keys off chat-list position', () {
      expect(
        ChatCacheState.isSubscribed(TdFixtures.chat(id: -1, mainOrder: 3)),
        isTrue,
      );
      expect(
        ChatCacheState.isSubscribed(TdFixtures.chat(id: -2, mainOrder: 0)),
        isFalse,
      );
    });

    test('sorts by main-list order, most recently active first', () {
      final state = ChatCacheState();
      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -1, mainOrder: 10)));
      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -2, mainOrder: 90)));
      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -3, mainOrder: 50)));

      expect(state.channels.map((c) => c.id), [-2, -3, -1]);
    });

    test('an archived channel sorts below one in the main list', () {
      final state = ChatCacheState();
      state.apply(
        TdFixtures.newChat(
          TdFixtures.chat(
            id: -1,
            positions: [TdFixtures.archiveListPosition(order: 900)],
          ),
        ),
      );
      state.apply(TdFixtures.newChat(TdFixtures.chat(id: -2, mainOrder: 5)));

      expect(state.channels.map((c) => c.id), [-2, -1]);
    });
  });

  group('ChatCacheState supergroups', () {
    test('UpdateSupergroup is mirrored and looked up by chat', () {
      final state = ChatCacheState();
      final chat = TdFixtures.chat(id: -1001234);
      state.apply(TdFixtures.newChat(chat));

      expect(
        state.supergroupForChat(chat),
        isNull,
        reason: 'nothing volunteered yet',
      );

      final supergroupId = (chat.type as td.ChatTypeSupergroup).supergroupId;
      state.apply(
        TdFixtures.supergroup(
          id: supergroupId,
          memberCount: 4200,
          isVerified: true,
          username: 'news',
        ),
      );

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
      state.apply(
        TdFixtures.lastMessage(
          chatId: -99,
          message: TdFixtures.textMessage(id: 1, chatId: -99),
        ),
      );

      state.apply(TdFixtures.supergroup(id: 7));

      state.clear();

      expect(state.chats, isEmpty);
      expect(state.supergroups, isEmpty);
      expect(state.pendingLastMessages, isEmpty);
    });
  });

  // Conversation fields follow TDLib's updates rather than the first snapshot.
  group('ChatCacheState conversation fields', () {
    late ChatCacheState state;

    setUp(() => state = ChatCacheState());

    test('mirrors users, so a chat row costs no GetUser', () {
      state.apply(
        TdFixtures.userUpdate(TdFixtures.user(id: 7, firstName: 'Ada')),
      );
      expect(state.users[7]?.firstName, 'Ada');
    });

    // A status update carries only the status, so it folds into the record.
    test('a status update folds into the user rather than replacing it', () {
      state.apply(
        TdFixtures.userUpdate(
          TdFixtures.user(id: 7, firstName: 'Ada', username: 'ada'),
        ),
      );
      state.apply(
        const td.UpdateUserStatus(
          userId: 7,
          status: td.UserStatusOnline(expires: 0),
        ),
      );

      expect(state.users[7]?.status, isA<td.UserStatusOnline>());
      expect(state.users[7]?.firstName, 'Ada');
      expect(state.users[7]?.usernames?.activeUsernames, ['ada']);
    });

    test('a status for an unknown user is not invented', () {
      expect(
        state.apply(
          const td.UpdateUserStatus(
            userId: 7,
            status: td.UserStatusOnline(expires: 0),
          ),
        ),
        isFalse,
      );
      expect(state.users, isEmpty);
    });

    // Without this, sent messages never show as read.
    test('the outbox cursor moves', () {
      state.apply(TdFixtures.newChat(TdFixtures.conversation(id: 5)));
      state.apply(
        const td.UpdateChatReadOutbox(chatId: 5, lastReadOutboxMessageId: 42),
      );
      expect(state.chats[5]?.lastReadOutboxMessageId, 42);
    });

    // A chat marked unread by hand carries no unread count.
    test('a hand-set unread mark is kept', () {
      state.apply(TdFixtures.newChat(TdFixtures.conversation(id: 5)));
      state.apply(
        const td.UpdateChatIsMarkedAsUnread(chatId: 5, isMarkedAsUnread: true),
      );
      expect(state.chats[5]?.isMarkedAsUnread, isTrue);
    });

    test('the action bar is kept, which is what Requests reads', () {
      state.apply(TdFixtures.newChat(TdFixtures.conversation(id: 5)));
      state.apply(
        td.UpdateChatActionBar(
          chatId: 5,
          actionBar: td.ChatActionBar.fromJson(TdFixtures.reportAddBlockBar()),
        ),
      );
      expect(state.chats[5]?.actionBar, isA<td.ChatActionBarReportAddBlock>());
    });

    test('a draft is kept, so the list can mark one', () {
      state.apply(TdFixtures.newChat(TdFixtures.conversation(id: 5)));
      final withDraft = TdFixtures.conversation(
        id: 5,
        draftText: 'half a thought',
      );
      state.apply(
        td.UpdateChatDraftMessage(
          chatId: 5,
          draftMessage: withDraft.draftMessage,
          positions: const [],
        ),
      );
      expect(state.chats[5]?.draftMessage, isNotNull);
    });

    test('conversations exclude broadcast channels', () {
      state.apply(
        TdFixtures.newChat(TdFixtures.conversation(id: 5, mainOrder: 300)),
      );
      state.apply(
        TdFixtures.newChat(TdFixtures.groupChat(id: -100200, mainOrder: 200)),
      );
      state.apply(
        TdFixtures.newChat(TdFixtures.chat(id: -100999, mainOrder: 400)),
      );

      expect(state.conversations.map((c) => c.id), [5, -100200]);
    });

    test('clear drops the users too', () {
      state.apply(TdFixtures.userUpdate(TdFixtures.user(id: 7)));
      state.clear();
      expect(state.users, isEmpty);
    });
  });

  // A person's channel lives on `UserFullInfo`. Keeping the ones TDLib sends
  // avoids a `GetUserFullInfo` per chat row.
  group('ChatCacheState full user records', () {
    late ChatCacheState state;

    setUp(() => state = ChatCacheState());

    test('an UpdateUserFullInfo is folded in', () {
      final changed = state.apply(
        td.UpdateUserFullInfo(
          userId: 7,
          userFullInfo: TdFixtures.userFullInfo(personalChatId: -100),
        ),
      );

      expect(changed, isTrue);
      expect(state.userFullInfos[7]?.personalChatId, -100);
    });

    test('a later one replaces the earlier', () {
      state.apply(
        td.UpdateUserFullInfo(
          userId: 7,
          userFullInfo: TdFixtures.userFullInfo(personalChatId: -100),
        ),
      );
      state.apply(
        td.UpdateUserFullInfo(
          userId: 7,
          userFullInfo: TdFixtures.userFullInfo(),
        ),
      );

      expect(state.userFullInfos[7]?.personalChatId, 0);
    });

    test('nothing arrives for a user TDLib has not described fully', () {
      state.apply(TdFixtures.userUpdate(TdFixtures.user(id: 7)));
      expect(state.userFullInfos, isEmpty);
    });

    test('clear drops them', () {
      state.apply(
        td.UpdateUserFullInfo(
          userId: 7,
          userFullInfo: TdFixtures.userFullInfo(),
        ),
      );
      state.clear();
      expect(state.userFullInfos, isEmpty);
    });
  });

  // TDLib clears a field with null, which its generated copyWith reads as keep.
  group('a field TDLib clears is cleared', () {
    late ChatCacheState state;

    setUp(() {
      state = ChatCacheState();
      state.apply(TdFixtures.newChat(TdFixtures.privateChat(id: 42)));
    });

    // Sending clears the draft, so it must not come back to the composer.
    test('a draft, once sent', () {
      state.apply(
        const td.UpdateChatDraftMessage(
          chatId: 42,
          draftMessage: td.DraftMessage(
            date: 1700000000,
            inputMessageText: td.InputMessageText(
              text: td.FormattedText(text: 'half a thought', entities: []),
              clearDraft: false,
            ),
            effectId: 0,
          ),
          positions: [],
        ),
      );
      expect(state.chats[42]?.draftMessage, isNotNull);

      state.apply(const td.UpdateChatDraftMessage(chatId: 42, positions: []));
      expect(state.chats[42]?.draftMessage, isNull);
    });

    test('the stranger bar, once dismissed', () {
      state.apply(
        const td.UpdateChatActionBar(
          chatId: 42,
          actionBar: td.ChatActionBarReportAddBlock(
            canUnarchive: false,
            distance: -1,
          ),
        ),
      );
      expect(state.chats[42]?.actionBar, isNotNull);

      state.apply(const td.UpdateChatActionBar(chatId: 42));
      expect(state.chats[42]?.actionBar, isNull);
    });

    test('the last message, once it is gone', () {
      state.apply(
        td.UpdateChatLastMessage(
          chatId: 42,
          lastMessage: TdFixtures.chatMessage(
            id: 1 << 20,
            chatId: 42,
            senderUserId: 42,
          ),
          positions: const [],
        ),
      );
      expect(state.chats[42]?.lastMessage, isNotNull);

      state.apply(const td.UpdateChatLastMessage(chatId: 42, positions: []));
      expect(state.chats[42]?.lastMessage, isNull);
    });

    test('and nothing else about the chat changes on the way', () {
      final before = state.chats[42]!;
      state.apply(const td.UpdateChatActionBar(chatId: 42));
      final after = state.chats[42]!;

      expect(after.title, before.title);
      expect(after.type, isA<td.ChatTypePrivate>());
      expect(after.positions.length, before.positions.length);
    });
  });
}
