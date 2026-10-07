import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chat_list_builder.dart';
import 'package:gramx/features/chats/domain/chat_filter.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';

import '../support/td_fixtures.dart';

void main() {
  group('what belongs in the messages list', () {
    test('private chats, bots and groups are conversations', () {
      expect(
        ChatCacheState.isConversation(TdFixtures.conversation(id: -1)),
        isTrue,
      );
      expect(
        ChatCacheState.isConversation(TdFixtures.groupChat(id: -100200)),
        isTrue,
      );
      expect(
        ChatCacheState.isConversation(TdFixtures.basicGroupChat(id: -300)),
        isTrue,
      );
    });

    // Channels belong to the feed, not the messages list.
    test('a broadcast channel is not', () {
      expect(
        ChatCacheState.isConversation(TdFixtures.chat(id: -100999)),
        isFalse,
      );
    });
  });

  group('kind', () {
    test('a private chat with yourself is Saved Messages', () {
      final chat = TdFixtures.conversation(id: 42, userId: 42);
      expect(
        ChatListBuilder.kindOf(chat, selfUserId: 42),
        ChatKind.savedMessages,
      );
    });

    // TDLib titles it with the user's own name.
    test('Saved Messages is called that, and has no presence', () {
      final chat = TdFixtures.conversation(
        id: 42,
        userId: 42,
        title: 'Dave RaGoose',
      );
      final row = ChatListBuilder.summaryFor(
        chat,
        users: {42: TdFixtures.user(id: 42, firstName: 'Dave')},
        supergroups: const {},
        selfUserId: 42,
      );
      expect(row.title, 'Saved Messages');
      expect(row.presence, ChatPresence.unknown);
    });

    test('a bot is told apart by its user record, not its chat', () {
      final chat = TdFixtures.conversation(id: 7, userId: 7);
      expect(ChatListBuilder.kindOf(chat), ChatKind.direct);
      expect(
        ChatListBuilder.kindOf(chat, user: TdFixtures.user(id: 7, isBot: true)),
        ChatKind.bot,
      );
    });

    // Bots have their own filter.
    test('a bot is private but not Direct', () {
      expect(ChatKind.direct.isDirect, isTrue);
      expect(ChatKind.savedMessages.isDirect, isTrue);
      expect(ChatKind.bot.isDirect, isFalse);
      expect(ChatKind.group.isDirect, isFalse);
    });
  });

  group('the row', () {
    test('shows the last message', () {
      final row = _summary(
        TdFixtures.conversation(
          id: 5,
          lastMessage: TdFixtures.textMessageJson(
            id: 10,
            chatId: 5,
            text: 'on my way',
          ),
        ),
      );
      expect(row.preview, 'on my way');
      expect(row.previewIsDraft, isFalse);
    });

    test('a draft wins the preview line and is marked as one', () {
      final row = _summary(
        TdFixtures.conversation(
          id: 5,
          draftText: 'half a thought',
          lastMessage: TdFixtures.textMessageJson(
            id: 10,
            chatId: 5,
            text: 'on my way',
          ),
        ),
      );
      expect(row.preview, 'half a thought');
      expect(row.previewIsDraft, isTrue);
    });

    test('a group prefixes the sender, a private chat does not', () {
      final group = _summary(
        TdFixtures.groupChat(
          id: -100200,
          lastMessage: TdFixtures.textMessageJson(id: 10, chatId: -100200),
        ),
        users: {9: TdFixtures.user(id: 9, firstName: 'Ada')},
        lastSenderUserId: 9,
      );
      expect(group.previewSender, 'Ada');

      final private = _summary(
        TdFixtures.conversation(
          id: 5,
          lastMessage: TdFixtures.textMessageJson(id: 10, chatId: 5),
        ),
      );
      expect(private.previewSender, isNull);
    });

    test('a service message previews as what happened, with no prefix', () {
      final join = TdFixtures.textMessageJson(id: 10, chatId: -100200)
        ..['content'] = {'@type': 'messageChatJoinByLink'}
        ..['is_channel_post'] = false;
      final group = _summary(
        TdFixtures.groupChat(id: -100200, lastMessage: join),
        users: {9: TdFixtures.user(id: 9, firstName: 'Pearlie')},
        lastSenderUserId: 9,
      );

      expect(group.preview, 'Pearlie joined the group via invite link');
      expect(group.previewSender, isNull);
    });

    test('mute follows the chat only when it overrides the default', () {
      expect(_summary(TdFixtures.conversation(id: 1)).isMuted, isFalse);
      expect(
        _summary(TdFixtures.conversation(id: 1, isMuted: true)).isMuted,
        isTrue,
      );
    });

    // With every private chat muted in Telegram, a chat on the default
    // showed here as unmuted.
    test('a chat on the default follows its scope', () {
      const muted = td.ScopeNotificationSettings(
        muteFor: 3600,
        soundId: 0,
        showPreview: true,
        useDefaultMuteStories: true,
        muteStories: false,
        storySoundId: 0,
        showStorySender: true,
        disablePinnedMessageNotifications: false,
        disableMentionNotifications: false,
      );
      final row = ChatListBuilder.summaryFor(
        TdFixtures.conversation(id: 1),
        users: const {},
        supergroups: const {},
        scopeSettings: {NotificationScope.privateChats: muted},
      );
      expect(row.isMuted, isTrue);

      final group = ChatListBuilder.summaryFor(
        TdFixtures.groupChat(id: -100200),
        users: const {},
        supergroups: const {},
        scopeSettings: {NotificationScope.privateChats: muted},
      );
      expect(group.isMuted, isFalse, reason: 'groups have their own default');
    });

    // A chat marked unread by hand has an unreadCount of zero.
    test('a hand-marked chat is unread without a count', () {
      final row = _summary(
        TdFixtures.conversation(id: 1, isMarkedAsUnread: true),
      );
      expect(row.unreadCount, 0);
      expect(row.isMarkedAsUnread, isTrue);
      expect(ChatListBuilder.matchesFilter(row, ChatFilter.unread), isTrue);
    });

    test('a stranger who wrote first is a request', () {
      final row = _summary(
        TdFixtures.conversation(
          id: 1,
          actionBar: TdFixtures.reportAddBlockBar(),
        ),
      );
      expect(row.isRequest, isTrue);
    });

    // The sort already puts pinned chats first; the row must also say why.
    test('a pinned chat says it is pinned', () {
      final pinned = TdFixtures.conversation(id: 1, isPinned: true);
      expect(ChatListBuilder.isPinned(pinned), isTrue);
      expect(_summary(pinned).isPinned, isTrue);
      expect(_summary(TdFixtures.conversation(id: 1)).isPinned, isFalse);
    });
  });

  group('chats with nothing in them', () {
    // Telegram opens a chat for "joined Telegram" notices about contacts.
    test('a contact-registration notice is not a conversation', () {
      final chat = TdFixtures.conversation(
        id: 5,
        lastMessage: TdFixtures.contactRegisteredMessageJson(id: 10, chatId: 5),
      );
      expect(ChatListBuilder.hasContent(chat), isFalse);
      expect(
        ChatListBuilder.build([chat], users: const {}, supergroups: const {}),
        isEmpty,
      );
    });

    test('a chat with no message at all is not one either', () {
      expect(
        ChatListBuilder.hasContent(TdFixtures.conversation(id: 5)),
        isFalse,
      );
    });

    // Only the contact-registration notice hides a chat, not service messages
    // in general.
    test('a real chat survives, whatever its last message is', () {
      final chat = TdFixtures.conversation(
        id: 5,
        lastMessage: TdFixtures.textMessageJson(id: 10, chatId: 5),
      );
      expect(ChatListBuilder.hasContent(chat), isTrue);
    });
  });

  group('the bot tag', () {
    // In Telegram's model a bot chat is a private chat.
    test('is decided by the user record, and only for bots', () {
      final chat = TdFixtures.conversation(id: 7, userId: 7);
      final asBot = ChatListBuilder.summaryFor(
        chat,
        users: {7: TdFixtures.user(id: 7, isBot: true)},
        supergroups: const {},
      );
      final asPerson = ChatListBuilder.summaryFor(
        chat,
        users: {7: TdFixtures.user(id: 7)},
        supergroups: const {},
      );
      expect(asBot.kind, ChatKind.bot);
      expect(asPerson.kind, ChatKind.direct);
    });
  });

  group('presence', () {
    test('reports Telegram\'s own hedged answers', () {
      expect(
        ChatListBuilder.presenceOf(
          TdFixtures.user(
            id: 1,
            status: {'@type': 'userStatusOnline', 'expires': 0},
          ),
        ),
        ChatPresence.online,
      );
      expect(
        ChatListBuilder.presenceOf(
          TdFixtures.user(
            id: 1,
            status: {
              '@type': 'userStatusRecently',
              'by_my_privacy_settings': false,
            },
          ),
        ),
        ChatPresence.recently,
      );
    });

    test('a bot has none', () {
      expect(
        ChatListBuilder.presenceOf(
          TdFixtures.user(
            id: 1,
            isBot: true,
            status: {'@type': 'userStatusOnline', 'expires': 0},
          ),
        ),
        ChatPresence.unknown,
      );
    });

    test('no user record means no claim', () {
      expect(ChatListBuilder.presenceOf(null), ChatPresence.unknown);
    });
  });

  group('ordering', () {
    // Pinned chats have a very high order, so they sort first.
    test('is TDLib\'s own chat-list order, newest first', () {
      final rows = ChatListBuilder.build(
        [
          _withMessage(id: 1, title: 'quiet', mainOrder: 10),
          _withMessage(id: 2, title: 'pinned', mainOrder: 9000),
          _withMessage(id: 3, title: 'busy', mainOrder: 500),
        ],
        users: const {},
        supergroups: const {},
      );
      expect(rows.map((r) => r.title), ['pinned', 'busy', 'quiet']);
    });

    // Otherwise inactive chats could swap places between rebuilds.
    test('ties break on a stable value, not on sort order', () {
      final rows = ChatListBuilder.build(
        [
          _withMessage(id: 9, title: 'b', mainOrder: 0),
          _withMessage(id: 4, title: 'a', mainOrder: 0),
        ],
        users: const {},
        supergroups: const {},
      );
      expect(rows.map((r) => r.chatId), [4, 9]);
    });
  });

  group('filtering', () {
    late List<ChatSummary> rows;

    setUp(() {
      rows = ChatListBuilder.build(
        [
          TdFixtures.conversation(
            id: 1,
            title: 'Ada',
            mainOrder: 400,
            lastMessage: TdFixtures.textMessageJson(id: 1, chatId: 1),
          ),
          TdFixtures.conversation(
            id: 2,
            title: 'Unread Person',
            mainOrder: 300,
            unreadCount: 3,
            lastMessage: TdFixtures.textMessageJson(id: 1, chatId: 2),
          ),
          TdFixtures.groupChat(
            id: -100200,
            title: 'The Group',
            mainOrder: 200,
            lastMessage: TdFixtures.textMessageJson(id: 1, chatId: -100200),
          ),
          TdFixtures.conversation(
            id: 4,
            title: 'A Bot',
            mainOrder: 100,
            lastMessage: TdFixtures.textMessageJson(id: 1, chatId: 4),
          ),
        ],
        users: {4: TdFixtures.user(id: 4, firstName: 'A Bot', isBot: true)},
        supergroups: const {},
      );
    });

    test('each filter selects what its label promises', () {
      expect(_titles(rows, ChatFilter.all), hasLength(4));
      expect(_titles(rows, ChatFilter.unread), ['Unread Person']);
      expect(_titles(rows, ChatFilter.direct), ['Ada', 'Unread Person']);
      expect(_titles(rows, ChatFilter.groups), ['The Group']);
      expect(_titles(rows, ChatFilter.bots), ['A Bot']);
    });

    test('search matches the title, case-insensitively', () {
      final found = ChatListBuilder.filter(rows, query: 'GROUP');
      expect(found.map((r) => r.title), ['The Group']);
    });

    test('the filter and the search both apply', () {
      final found = ChatListBuilder.filter(
        rows,
        filter: ChatFilter.direct,
        query: 'ada',
      );
      expect(found.map((r) => r.title), ['Ada']);
    });

    test('the unread badge counts conversations', () {
      final withMarked = [
        ...rows,
        _summary(TdFixtures.conversation(id: 5, isMarkedAsUnread: true)),
      ];
      expect(ChatListBuilder.unreadChatCount(withMarked), 2);
    });

    // The badge follows the Messages tab's filter, which starts on Direct.
    test('the unread badge counts only what the filter shows', () {
      final busy = [
        ...rows,
        _summary(
          TdFixtures.groupChat(
            id: -100300,
            title: 'Loud Group',
            mainOrder: 50,
            unreadCount: 40,
            lastMessage: TdFixtures.textMessageJson(id: 1, chatId: -100300),
          ),
        ),
        _summary(
          TdFixtures.conversation(
            id: 6,
            title: 'Noisy Bot',
            mainOrder: 40,
            unreadCount: 2,
            lastMessage: TdFixtures.textMessageJson(id: 1, chatId: 6),
          ),
          users: {
            6: TdFixtures.user(id: 6, firstName: 'Noisy Bot', isBot: true),
          },
        ),
      ];

      int count(ChatFilter filter) =>
          ChatListBuilder.unreadChatCount(busy, filter: filter);

      expect(count(ChatFilter.direct), 1);
      expect(count(ChatFilter.groups), 1);
      expect(count(ChatFilter.bots), 1);
      expect(count(ChatFilter.all), 3);
      expect(count(ChatFilter.unread), 3);
    });
  });

  group('display names', () {
    test('joins both halves and falls back when there are none', () {
      expect(
        ChatListBuilder.displayNameOf(
          TdFixtures.user(id: 1, firstName: 'Ada', lastName: 'Lovelace'),
        ),
        'Ada Lovelace',
      );
      expect(
        ChatListBuilder.displayNameOf(
          TdFixtures.user(id: 1, firstName: '', isDeleted: true),
        ),
        'Deleted account',
      );
      expect(
        ChatListBuilder.displayNameOf(
          TdFixtures.user(id: 1, firstName: '', username: 'ada'),
        ),
        '@ada',
      );
    });
  });

  group('premium', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000);

    ChatSummary person(td.User user) => _summary(
      _withMessage(id: user.id, title: 'Ada', mainOrder: 1),
      users: {user.id: user},
    );

    test('a Premium account is marked, with its emoji status', () {
      final row = person(
        TdFixtures.user(id: 9, isPremium: true, emojiStatusId: 5551),
      );

      expect(row.isPremium, isTrue);
      expect(row.emojiStatusId, 5551);
    });

    test('anyone else is not', () {
      final row = person(TdFixtures.user(id: 9));

      expect(row.isPremium, isFalse);
      expect(row.emojiStatusId, isNull);
    });

    // A status set "for an hour" stays on the record once the hour is up.
    test('an expired emoji status is no status', () {
      final user = TdFixtures.user(
        id: 9,
        isPremium: true,
        emojiStatusId: 5551,
        emojiStatusExpires: 1700000000 - 60,
      );

      expect(ChatListBuilder.emojiStatusOf(user, now: now), isNull);
    });

    test('a status that has not expired yet holds', () {
      final user = TdFixtures.user(
        id: 9,
        isPremium: true,
        emojiStatusId: 5551,
        emojiStatusExpires: 1700000000 + 60,
      );

      expect(ChatListBuilder.emojiStatusOf(user, now: now), 5551);
    });

    // The status is Premium only; a lapsed subscription can leave one behind.
    test('a status without Premium is ignored', () {
      final user = TdFixtures.user(id: 9, emojiStatusId: 5551);

      expect(ChatListBuilder.emojiStatusOf(user), isNull);
    });
  });
}

/// A chat with a last message, since [ChatListBuilder.build] drops empty ones.
td.Chat _withMessage({
  required int id,
  required String title,
  required int mainOrder,
}) => TdFixtures.conversation(
  id: id,
  title: title,
  mainOrder: mainOrder,
  lastMessage: TdFixtures.textMessageJson(id: 1, chatId: id),
);

List<String> _titles(List<ChatSummary> rows, ChatFilter filter) =>
    ChatListBuilder.filter(rows, filter: filter).map((r) => r.title).toList();

/// Builds one row, optionally with a sender for the group preview prefix.
ChatSummary _summary(
  td.Chat chat, {
  Map<int, td.User> users = const {},
  int? lastSenderUserId,
}) {
  var subject = chat;
  final last = chat.lastMessage;
  if (lastSenderUserId != null && last != null) {
    subject = chat.copyWith(
      lastMessage: last.copyWith(
        senderId: td.MessageSenderUser(userId: lastSenderUserId),
      ),
    );
  }
  return ChatListBuilder.summaryFor(
    subject,
    users: users,
    supergroups: const {},
  );
}
