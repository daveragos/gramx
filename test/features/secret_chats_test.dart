import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/chats/data/chat_list_builder.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';

import '../support/td_fixtures.dart';

void main() {
  group('the cache', () {
    test('mirrors a secret chat record off the update stream', () {
      final state = ChatCacheState();
      state.apply(TdFixtures.secretChatUpdate(secretChatId: 5, userId: 42));

      expect(state.secretChats[5], isNotNull);
      expect(state.secretChats[5]!.userId, 42);
    });

    test('a secret chat belongs in the conversation list', () {
      final chat = TdFixtures.secretChat(id: -900, userId: 42);
      expect(ChatCacheState.isConversation(chat), isTrue);
    });

    test('resolves the record behind a chat by its secret chat id', () {
      final state = ChatCacheState();
      state.apply(TdFixtures.secretChatUpdate(secretChatId: 5, userId: 42));

      final chat = TdFixtures.secretChat(id: -900, userId: 42, secretChatId: 5);
      expect(state.secretChatFor(chat)?.id, 5);
      // A chat that is not secret has no record, whatever is in the map.
      expect(state.secretChatFor(TdFixtures.privateChat(id: 7)), isNull);
    });

    // While pending (key exchange unfinished), Telegram refuses sends.
    test('ready and pending are told apart', () {
      final ready = TdFixtures.secretChatUpdate(userId: 42).secretChat;
      final pending = TdFixtures.secretChatUpdate(
        userId: 42,
        isReady: false,
      ).secretChat;

      expect(ChatCacheState.isSecretChatReady(ready), isTrue);
      expect(ChatCacheState.isSecretChatReady(pending), isFalse);
      // No record means TDLib has not described the chat yet.
      expect(ChatCacheState.isSecretChatReady(null), isFalse);
    });

    // Channel posts cannot be forwarded into a secret chat.
    test('a secret chat is still not a forward destination', () {
      expect(
        ChatCacheState.canPostIn(
          TdFixtures.secretChat(id: -900, userId: 42),
          null,
        ),
        isFalse,
      );
    });
  });

  group('the row', () {
    test('is drawn as secret, and names the person it is with', () {
      final user = TdFixtures.user(id: 42, firstName: 'Ada');
      final summary = ChatListBuilder.summaryFor(
        TdFixtures.secretChat(id: -900, userId: 42, secretChatId: 5),
        users: {42: user},
        supergroups: const {},
        secretChats: {
          5: TdFixtures.secretChatUpdate(
            secretChatId: 5,
            userId: 42,
          ).secretChat,
        },
      );

      expect(summary.isSecret, isTrue);
      expect(summary.isSecretPending, isFalse);
    });

    test('says so while the key exchange is still going', () {
      final summary = ChatListBuilder.summaryFor(
        TdFixtures.secretChat(id: -900, userId: 42, secretChatId: 5),
        users: const {},
        supergroups: const {},
        secretChats: {
          5: TdFixtures.secretChatUpdate(
            secretChatId: 5,
            userId: 42,
            isReady: false,
          ).secretChat,
        },
      );

      expect(summary.isSecret, isTrue);
      expect(summary.isSecretPending, isTrue);
    });

    // Not ready until TDLib says so, since Telegram refuses sends before then.
    test('with no record yet it is pending', () {
      final summary = ChatListBuilder.summaryFor(
        TdFixtures.secretChat(id: -900, userId: 42),
        users: const {},
        supergroups: const {},
      );

      expect(summary.isSecretPending, isTrue);
    });

    test('an ordinary chat is neither', () {
      final summary = ChatListBuilder.summaryFor(
        TdFixtures.privateChat(id: 7),
        users: const {},
        supergroups: const {},
      );

      expect(summary.isSecret, isFalse);
      expect(summary.isSecretPending, isFalse);
    });
  });

  group('what may be sent into one', () {
    test('media yes, polls no', () {
      final chat = TdFixtures.secretChat(id: -900, userId: 42);

      expect(
        ChatCacheState.canSendIn(chat, null, ChatSendRight.photos),
        isTrue,
      );
      expect(
        ChatCacheState.canSendIn(chat, null, ChatSendRight.voiceNotes),
        isTrue,
      );
      // TDLib's own line: polls cannot be sent to secret chats.
      expect(
        ChatCacheState.canSendIn(chat, null, ChatSendRight.polls),
        isFalse,
      );
    });
  });
}
