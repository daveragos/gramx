import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';

import '../support/td_fixtures.dart';

/// Reactions were the one thing on a post that gramX could see in Telegram and
/// not draw. Two separate causes, one test file:
///
///  * only `reactionTypeEmoji` survived the mapper, so the ⭐ paid reaction and
///    custom-emoji reactions on a real channel post silently vanished;
///  * the mapper and the live-update path each had their own copy of the loop,
///    which is how they came to disagree in the first place.
void main() {
  group('TdlibMappers.mapReactions', () {
    test('reads counts and the reader\'s own choice off an emoji reaction', () {
      final mapped = TdlibMappers.mapReactions(
        TdFixtures.messageReactions([
          TdFixtures.reactionJson(
            type: TdFixtures.emojiReactionType('❤️'),
            totalCount: 5,
          ),
          TdFixtures.reactionJson(
            type: TdFixtures.emojiReactionType('😂'),
            totalCount: 2,
            isChosen: true,
          ),
        ]),
      );

      expect(mapped.counts, {'❤️': 5, '😂': 2});
      expect(mapped.chosen, {'😂'});
    });

    // Telegram Stars. It carries no emoji of its own, so dropping anything
    // without one dropped it — and it is the first chip on plenty of posts.
    test('a paid reaction becomes a star chip rather than nothing', () {
      final mapped = TdlibMappers.mapReactions(
        TdFixtures.messageReactions([
          TdFixtures.reactionJson(
            type: TdFixtures.paidReactionType(),
            totalCount: 1,
          ),
        ]),
      );

      expect(mapped.counts, {TdlibMappers.paidReactionEmoji: 1});
    });

    test('a custom emoji reaction keeps its count under a placeholder', () {
      final mapped = TdlibMappers.mapReactions(
        TdFixtures.messageReactions([
          TdFixtures.reactionJson(
            type: TdFixtures.customEmojiReactionType('5789'),
            totalCount: 3,
            isChosen: true,
          ),
        ]),
      );

      expect(mapped.counts, {TdlibMappers.customReactionEmoji: 3});
      expect(mapped.chosen, {TdlibMappers.customReactionEmoji});
    });

    // Two different custom emoji collapse onto one key, so the counts have to
    // add. Overwriting would report the second reaction's count as the total.
    test('custom emoji reactions sharing the placeholder add up', () {
      final mapped = TdlibMappers.mapReactions(
        TdFixtures.messageReactions([
          TdFixtures.reactionJson(
            type: TdFixtures.customEmojiReactionType('1'),
            totalCount: 3,
          ),
          TdFixtures.reactionJson(
            type: TdFixtures.customEmojiReactionType('2'),
            totalCount: 4,
          ),
        ]),
      );

      expect(mapped.counts, {TdlibMappers.customReactionEmoji: 7});
    });

    // The exact shape of image 4: a paid star, a heart, and a custom emoji.
    test('mixed reaction types all survive together', () {
      final mapped = TdlibMappers.mapReactions(
        TdFixtures.messageReactions([
          TdFixtures.reactionJson(
            type: TdFixtures.paidReactionType(),
            totalCount: 1,
          ),
          TdFixtures.reactionJson(
            type: TdFixtures.emojiReactionType('❤️'),
            totalCount: 5,
          ),
          TdFixtures.reactionJson(
            type: TdFixtures.customEmojiReactionType('7'),
            totalCount: 1,
          ),
        ]),
      );

      expect(mapped.counts.values.reduce((a, b) => a + b), 7);
      expect(mapped.counts, hasLength(3));
    });

    test('no reactions is an empty map, not a null', () {
      final mapped = TdlibMappers.mapReactions(null);
      expect(mapped.counts, isEmpty);
      expect(mapped.chosen, isEmpty);
    });
  });

  group('mapMessageToPost', () {
    test('carries reactions from a message through to the post', () {
      final chat = TdFixtures.chat(id: -1001, title: 'Ashangulit');
      final post = TdlibMappers.mapMessageToPost(
        TdFixtures.messageWithReactions(
          id: 4096,
          chatId: -1001,
          viewCount: 48,
          reactions: [
            TdFixtures.reactionJson(
              type: TdFixtures.paidReactionType(),
              totalCount: 1,
            ),
            TdFixtures.reactionJson(
              type: TdFixtures.emojiReactionType('❤️'),
              totalCount: 5,
            ),
          ],
        ),
        chat,
      );

      expect(post.reactions, {TdlibMappers.paidReactionEmoji: 1, '❤️': 5});
      expect(post.viewCount, 48);
    });
  });
}
