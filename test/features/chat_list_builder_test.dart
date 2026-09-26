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

    // Channels are the feed. Listing them here would show the same post in two
    // places and turn a reader with DMs into a Telegram client.
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

    // TDLib titles it with your own name — which in the forward picker sat
    // beside a channel of the same name, where forwarding publishes.
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

    // Without the user record a bot reads as a person, and the reader gets
    // "last seen recently" under a piece of software.
    test('a bot is told apart by its user record, not its chat', () {
      final chat = TdFixtures.conversation(id: 7, userId: 7);
      expect(ChatListBuilder.kindOf(chat), ChatKind.direct);
      expect(
        ChatListBuilder.kindOf(chat, user: TdFixtures.user(id: 7, isBot: true)),
        ChatKind.bot,
      );
    });

    // A bot is a private chat, but it is not a person, and Bots is its own
    // filter now — folding them into Direct as well would make both mean less.
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

    // A draft that looked like a sent message is how somebody forgets they
    // were mid-sentence with a person.
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

    // A join has no words of its own, so the row read "Pearlie:" and stopped.
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

    // A chat marked unread by hand carries no count, so a list reading only
    // unreadCount draws it as read — the opposite of what was asked for.
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

    // Telegram expresses a pin as a very high order, so the sort already put a
    // pinned chat on top — but nothing said *why*, and an old chat above a new
    // one with no explanation reads as a sorting bug.
    test('a pinned chat says it is pinned', () {
      final pinned = TdFixtures.conversation(id: 1, isPinned: true);
      expect(ChatListBuilder.isPinned(pinned), isTrue);
      expect(_summary(pinned).isPinned, isTrue);
      expect(_summary(TdFixtures.conversation(id: 1)).isPinned, isFalse);
    });
  });

  group('chats with nothing in them', () {
    // Telegram opens a chat the moment it has anything to say about somebody,
    // conversation with one. Those filled the list with people never spoken to.
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

    // The tempting generalisation — hide any chat whose last message is a
    // service notice — would hide a real group the moment somebody changed its
    // photo. Only the one content type, which can only ever be alone.
    test('a real chat survives, whatever its last message is', () {
      final chat = TdFixtures.conversation(
        id: 5,
        lastMessage: TdFixtures.textMessageJson(id: 10, chatId: 5),
      );
      expect(ChatListBuilder.hasContent(chat), isTrue);
    });
  });

  group('the bot tag', () {
    // A bot is a private chat in Telegram's model, so nothing about the row
    // says so unless the user record is consulted.
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

    // A bot answers instantly and always, so a status for one is noise dressed
    // as information.
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
    // Telegram expresses a pinned chat as a very high order, so sorting by it
    // pins the pinned chats for free — where every other client puts them.
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

    // Left to the sort's stability, two chats with no activity could swap
    // places between rebuilds under the reader's thumb.
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
      // Bots are out of Direct now, which is the point of splitting them.
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

    // The badge counts conversations, not messages: "3" should mean three
    // people are waiting, which is a number somebody can act on.
    test('the unread badge counts conversations', () {
      final withMarked = [
        ...rows,
        _summary(TdFixtures.conversation(id: 5, isMarkedAsUnread: true)),
      ];
      expect(ChatListBuilder.unreadChatCount(withMarked), 2);
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
}

/// A conversation with something in it.
///
/// [ChatListBuilder.build] drops chats with no messages, so an ordering test
/// built on bare chats would be asserting against an empty list.
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
