import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';

import '../support/td_fixtures.dart';

/// The regression this file exists for: `updateMessageReactions` is documented
/// "for bots only" and never fires on a user client, so the *only* place a
/// reader hears about a reaction is `updateMessageInteractionInfo`. That
/// handler read the view and forward counts and walked past `reactions`, which
/// is why gramX drew an empty reaction row under a post Telegram showed with
/// ⭐1 ❤️5 🕊1 — and why an optimistic tap never got reconciled.
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

    // Taking back the last reaction arrives as an empty list, and it has to be
    // distinguishable from "this update said nothing about reactions" — an
    // empty map clears the row, a null leaves it alone.
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
