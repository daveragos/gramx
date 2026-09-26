import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/data/chat_events.dart';

import '../support/td_fixtures.dart';

void main() {
  group('what a conversation cares about', () {
    test('a new message becomes an arrival', () {
      final event = ChatEvents.map(
        td.UpdateNewMessage(
          message: TdFixtures.chatMessage(id: 1, chatId: -5, senderUserId: 2),
        ),
      );
      expect(event, isA<ChatMessageArrived>());
      expect(event!.chatId, -5);
    });

    // `fromCache` means TDLib dropped it locally to save room — the message
    // still exists for everybody. Folding that in as a deletion is how a
    // scrollback develops holes.
    test('a cache eviction is not a deletion', () {
      expect(
        ChatEvents.map(
          const td.UpdateDeleteMessages(
            chatId: -5,
            messageIds: [1],
            isPermanent: false,
            fromCache: true,
          ),
        ),
        isNull,
      );

      expect(
        ChatEvents.map(
          const td.UpdateDeleteMessages(
            chatId: -5,
            messageIds: [1],
            isPermanent: true,
            fromCache: false,
          ),
        ),
        isA<ChatMessagesDeleted>(),
      );
    });

    // The id changes when Telegram accepts a message, and everything keyed on
    // it has to move with it.
    test('a successful send carries the id it replaces', () {
      final event =
          ChatEvents.map(
                td.UpdateMessageSendSucceeded(
                  message: TdFixtures.chatMessage(
                    id: 900,
                    chatId: -5,
                    senderUserId: 1,
                    isOutgoing: true,
                  ),
                  oldMessageId: -1,
                ),
              )
              as ChatMessageSent;
      expect(event.oldMessageId, -1);
      expect(event.message.id, 900);
    });

    test('an outbox read becomes a cursor move', () {
      final event =
          ChatEvents.map(
                const td.UpdateChatReadOutbox(
                  chatId: -5,
                  lastReadOutboxMessageId: 42,
                ),
              )
              as ChatOutboxRead;
      expect(event.lastReadOutboxMessageId, 42);
    });

    test('an update nothing here cares about answers null', () {
      expect(
        ChatEvents.map(const td.UpdateChatTitle(chatId: -5, title: 'x')),
        isNull,
      );
    });
  });

  group('reactions', () {
    // Reactions reach a user client through interaction info and nowhere else
    // — `updateMessageReactions` is documented bots-only.
    test('come from interaction info', () {
      final update = TdFixtures.interactionInfo(
        chatId: -5,
        messageId: 10,
        reactions: [
          TdFixtures.reactionJson(
            type: TdFixtures.emojiReactionType('❤️'),
            totalCount: 3,
            isChosen: true,
          ),
        ],
      );

      final event = ChatEvents.map(update) as ChatReactionsChanged;
      expect(event.reactions, {'❤️': 3});
      expect(event.chosen, {'❤️'});
    });

    // Absent interaction info is the last reaction being taken back, which is
    // an empty map rather than "no news".
    test('no interaction info clears them', () {
      final event =
          ChatEvents.map(
                const td.UpdateMessageInteractionInfo(
                  chatId: -5,
                  messageId: 10,
                  interactionInfo: null,
                ),
              )
              as ChatReactionsChanged;
      expect(event.reactions, isEmpty);
    });
  });

  group('chat actions', () {
    test('become the phrase the header shows', () {
      expect(
        ChatEvents.describeAction(const td.ChatActionTyping()),
        AppStrings.chatActionTyping,
      );
      expect(
        ChatEvents.describeAction(
          const td.ChatActionUploadingPhoto(progress: 0),
        ),
        AppStrings.chatActionSendingPhoto,
      );
    });

    // The switch is exhaustive over a sealed class with no default, so a TDLib
    // that adds an action fails the analyzer rather than reaching a reader as
    // a blank line. This pins the one case that means "stopped".
    test('a cancel means nobody is doing anything', () {
      expect(ChatEvents.describeAction(const td.ChatActionCancel()), isNull);
    });

    test('an action update names who is doing it', () {
      final event =
          ChatEvents.map(
                const td.UpdateChatAction(
                  chatId: -5,
                  messageThreadId: 0,
                  senderId: td.MessageSenderUser(userId: 7),
                  action: td.ChatActionTyping(),
                ),
              )
              as ChatActionChanged;
      expect(event.userId, 7);
      expect(event.action, AppStrings.chatActionTyping);
    });
  });
}
