import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';

import '../support/td_fixtures.dart';

/// `updateMessageReactions` is for bots only, so a user client learns about
/// reactions from `updateMessageInteractionInfo`.
void main() {
  group('mapCounterUpdate', () {
    test('interaction info carries reactions, not just view counts', () {
      final event =
          mapCounterUpdate(
                TdFixtures.interactionInfo(
                  chatId: -1001,
                  messageId: 4096,
                  viewCount: 48,
                  forwardCount: 2,
                  reactions: [
                    TdFixtures.reactionJson(
                      type: TdFixtures.emojiReactionType('❤️'),
                      totalCount: 5,
                    ),
                  ],
                ),
              )
              as LiveInteractionUpdate;

      expect(event.postId, '-1001_4096');
      expect(event.viewCount, 48);
      expect(event.forwardCount, 2);
      expect(event.reactions, {'❤️': 5});
    });

    test('the reader\'s own reaction comes through as chosen', () {
      final event =
          mapCounterUpdate(
                TdFixtures.interactionInfo(
                  chatId: -1001,
                  messageId: 4096,
                  reactions: [
                    TdFixtures.reactionJson(
                      type: TdFixtures.emojiReactionType('🔥'),
                      totalCount: 1,
                      isChosen: true,
                    ),
                  ],
                ),
              )
              as LiveInteractionUpdate;

      expect(event.chosenReactions, {'🔥'});
    });

    test('paid and custom reactions survive the live path too', () {
      final event =
          mapCounterUpdate(
                TdFixtures.interactionInfo(
                  chatId: -1001,
                  messageId: 4096,
                  reactions: [
                    TdFixtures.reactionJson(
                      type: TdFixtures.paidReactionType(),
                      totalCount: 1,
                    ),
                    TdFixtures.reactionJson(
                      type: TdFixtures.customEmojiReactionType('7'),
                      totalCount: 1,
                    ),
                  ],
                ),
              )
              as LiveInteractionUpdate;

      expect(event.reactions, {
        TdlibMappers.paidReactionEmoji: 1,
        TdlibMappers.customReactionEmoji: 1,
      });
    });

    // Removing the last reaction sends an empty list. An empty map clears the
    // row, while null leaves it alone.
    test('no reactions on the message is an empty map, not null', () {
      final event =
          mapCounterUpdate(
                TdFixtures.interactionInfo(
                  chatId: -1001,
                  messageId: 4096,
                  viewCount: 3,
                  reactions: [],
                ),
              )
              as LiveInteractionUpdate;

      expect(event.reactions, isEmpty);
      expect(event.reactions, isNotNull);
    });

    test('an update with no interaction info yields no event', () {
      expect(
        mapCounterUpdate(TdFixtures.newChat(TdFixtures.chat(id: -1001))),
        isNull,
      );
    });
  });
}
