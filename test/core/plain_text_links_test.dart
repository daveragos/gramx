import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/core/text/plain_text_links.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';

/// A channel's bio is the one piece of text Telegram hands over with no
/// entities at all, so every link in it rendered as grey prose. These entities
/// are re-derived, which means the offsets have to be right against the same
/// string [TextEntityRenderer] will slice — an entity one code unit out puts
/// the link on the wrong words.
void main() {
  String sliceOf(String text, TextEntity entity) =>
      text.substring(entity.offset, entity.offset + entity.length);

  group('linkifyPlainText', () {
    test('empty text has no links', () {
      expect(linkifyPlainText(''), isEmpty);
    });

    test('plain prose has no links', () {
      expect(linkifyPlainText('Daily reading, in Amharic and English.'),
          isEmpty);
    });

    test('finds a URL and slices it exactly', () {
      const text = 'Read more at https://gramx.dev/docs today';
      final entities = linkifyPlainText(text);

      expect(entities, hasLength(1));
      expect(entities.single.type, TextEntityType.url);
      expect(sliceOf(text, entities.single), 'https://gramx.dev/docs');
    });

    test('a bare www host counts too', () {
      const text = 'www.example.org';
      final entities = linkifyPlainText(text);

      expect(sliceOf(text, entities.single), 'www.example.org');
    });

    // The classic over-eager-linkifier bug: the sentence's full stop becomes
    // part of the host and the tap goes nowhere.
    test('trailing punctuation belongs to the sentence', () {
      const text = 'See https://gramx.dev.';
      final entities = linkifyPlainText(text);

      expect(sliceOf(text, entities.single), 'https://gramx.dev');
    });

    test('a link in brackets does not swallow the bracket', () {
      const text = 'Source (https://gramx.dev/about) below';
      final entities = linkifyPlainText(text);

      expect(sliceOf(text, entities.single), 'https://gramx.dev/about');
    });

    test('finds a channel mention', () {
      const text = 'Chat at @gramxchat';
      final entities = linkifyPlainText(text);

      expect(entities.single.type, TextEntityType.mention);
      expect(sliceOf(text, entities.single), '@gramxchat');
    });

    // Telegram usernames are at least five characters. Without the floor an
    // email's local part and every "@me" became a channel that cannot open.
    test('something too short to be a username is not a mention', () {
      expect(linkifyPlainText('ping @me'), isEmpty);
    });

    test('finds a hashtag', () {
      const text = 'Filed under #release notes';
      final entities = linkifyPlainText(text);

      expect(entities.single.type, TextEntityType.hashtag);
      expect(sliceOf(text, entities.single), '#release');
    });

    // An address contains an @handle-shaped run. Claiming ranges in order is
    // what stops it being read as both.
    test('an email is one entity, not an email plus a mention', () {
      const text = 'Write to hello@gramx.dev';
      final entities = linkifyPlainText(text);

      expect(entities, hasLength(1));
      expect(entities.single.type, TextEntityType.emailAddress);
      expect(sliceOf(text, entities.single), 'hello@gramx.dev');
    });

    test('entities never overlap and arrive in reading order', () {
      const text =
          'Site https://gramx.dev · chat @gramxchat · mail hi@gramx.dev #news';
      final entities = linkifyPlainText(text);

      expect(entities, hasLength(4));
      for (var i = 0; i < entities.length - 1; i++) {
        final end = entities[i].offset + entities[i].length;
        expect(entities[i + 1].offset, greaterThanOrEqualTo(end));
      }
    });

    // The offsets are UTF-16 code units, the same units substring counts in.
    // A bio with an emoji in it is where an offset scheme goes wrong.
    test('offsets survive text with emoji before the link', () {
      const text = '🇪🇹 news · https://gramx.dev';
      final entities = linkifyPlainText(text);

      expect(sliceOf(text, entities.single), 'https://gramx.dev');
    });
  });
}
