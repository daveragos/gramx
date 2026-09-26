import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/infrastructure/telegram/message_content_support.dart';

td.MessageContent content(Map<String, dynamic> json) =>
    td.MessageContent.fromJson(json);

Map<String, dynamic> _file({int id = 1}) => {
      '@type': 'file',
      'id': id,
      'size': 0,
      'expected_size': 0,
      'local': {
        '@type': 'localFile',
        'path': '',
        'can_be_downloaded': true,
        'can_be_deleted': false,
        'is_downloading_active': false,
        'is_downloading_completed': false,
        'download_offset': 0,
        'downloaded_prefix_size': 0,
        'downloaded_size': 0,
      },
      'remote': {
        '@type': 'remoteFile',
        'id': '',
        'unique_id': '',
        'is_uploading_active': false,
        'is_uploading_completed': true,
        'uploaded_size': 0,
      },
    };

void main() {
  final text = content({
    '@type': 'messageText',
    'text': {'@type': 'formattedText', 'text': 'hi', 'entities': []},
  });

  final videoNote = content({
    '@type': 'messageVideoNote',
    'video_note': {
      '@type': 'videoNote',
      'duration': 5,
      'waveform': '',
      'length': 240,
      'video': _file(),
      'is_secret': false,
    },
    'is_viewed': false,
    'is_secret': false,
  });

  final location = content({
    '@type': 'messageLocation',
    'location': {
      '@type': 'location',
      'latitude': 9.0,
      'longitude': 38.7,
      'horizontal_accuracy': 0.0,
    },
    'live_period': 0,
    'expires_in': 0,
    'heading': 0,
    'proximity_alert_radius': 0,
  });

  final pinned = content({'@type': 'messagePinMessage', 'message_id': 42});
  final titleChanged =
      content({'@type': 'messageChatChangeTitle', 'title': 'New name'});
  final unsupported = content({'@type': 'messageUnsupported'});

  // The types that produced the bug: real things a channel posts, swept into
  // "Unsupported message — open in Telegram to view" by the old `_ =>` default.
  final chatBoost = content({'@type': 'messageChatBoost', 'boost_count': 3});
  final giveawayCreated =
      content({'@type': 'messageGiveawayCreated', 'star_count': 0});
  final expiredPhoto = content({'@type': 'messageExpiredPhoto'});
  final giftedStars = content({
    '@type': 'messageGiftedStars',
    'gifter_user_id': 1,
    'receiver_user_id': 2,
    'currency': 'USD',
    'amount': 100,
    'cryptocurrency': '',
    'cryptocurrency_amount': '0',
    'star_count': 50,
    'transaction_id': 'tx',
    'sticker': null,
  });

  group('isRendered', () {
    test('true for content the mapper draws in full', () {
      expect(MessageContentSupport.isRendered(text), isTrue);
    });

    // A round video message is a video. It was labelled rather than drawn, so
    // a channel that posts them showed a line of text where the video was.
    test('true for a round video message', () {
      expect(MessageContentSupport.isRendered(videoNote), isTrue);
    });

    test('false for content it does not draw', () {
      expect(MessageContentSupport.isRendered(location), isFalse);
      expect(MessageContentSupport.isRendered(unsupported), isFalse);
    });
  });

  group('isServiceMessage', () {
    // These are Telegram's notices about the chat itself, not posts.
    test('true for pins and chat changes', () {
      expect(MessageContentSupport.isServiceMessage(pinned), isTrue);
      expect(MessageContentSupport.isServiceMessage(titleChanged), isTrue);
    });

    // A busy channel generates several boosts a day, and each one used to
    // arrive in the feed as an unsupported message.
    test('true for a channel boost and a giveaway announcement', () {
      expect(MessageContentSupport.isServiceMessage(chatBoost), isTrue);
      expect(MessageContentSupport.isServiceMessage(giveawayCreated), isTrue);
    });

    test('false for real content', () {
      expect(MessageContentSupport.isServiceMessage(text), isFalse);
      expect(MessageContentSupport.isServiceMessage(location), isFalse);
    });
  });

  group('belongsInFeed', () {
    test('service messages are dropped', () {
      expect(MessageContentSupport.belongsInFeed(pinned), isFalse);
      expect(MessageContentSupport.belongsInFeed(titleChanged), isFalse);
      expect(MessageContentSupport.belongsInFeed(chatBoost), isFalse);
    });

    test('real content is kept, even if unrenderable', () {
      expect(MessageContentSupport.belongsInFeed(text), isTrue);
      expect(MessageContentSupport.belongsInFeed(location), isTrue);
      expect(MessageContentSupport.belongsInFeed(unsupported), isTrue);
    });
  });

  group('describe', () {
    // The bug this fixes: unhandled content produced a card with a header, a
    // timestamp, an action bar, and nothing in between.
    test('labels content the feed cannot draw', () {
      expect(MessageContentSupport.describe(location), '📍 Location');
    });

    test('never labels content that renders properly', () {
      expect(MessageContentSupport.describe(text), isNull);
      expect(MessageContentSupport.describe(videoNote), isNull);
    });

    test('never labels a service message, which is dropped instead', () {
      expect(MessageContentSupport.describe(pinned), isNull);
      expect(MessageContentSupport.describe(titleChanged), isNull);
    });

    // The regression: these named things reached the
    // reader as "Unsupported message — open in Telegram to view".
    test('names expired media and gifts rather than calling them unsupported',
        () {
      for (final c in [expiredPhoto, giftedStars]) {
        final label = MessageContentSupport.describe(c);
        expect(label, isNotNull);
        expect(label, isNot(MessageContentSupport.unsupportedLabel));
      }
    });

    test('every label is non-empty', () {
      for (final c in [location, expiredPhoto, giftedStars, unsupported]) {
        expect(MessageContentSupport.describe(c), isNotEmpty);
      }
    });
  });

  group('isUnsupported', () {
    // The whole point of the rewrite: the dead-end label now means only what
    // it says. Everything else is either drawn, named, or dropped — and the
    // switch has no `default`, so the analyzer fails the next TDLib upgrade
    // that adds a content type rather than letting it reach a reader.
    test('only messageUnsupported is a dead end', () {
      expect(MessageContentSupport.isUnsupported(unsupported), isTrue);
      for (final c in [
        text,
        videoNote,
        location,
        pinned,
        chatBoost,
        giveawayCreated,
        expiredPhoto,
        giftedStars,
      ]) {
        expect(MessageContentSupport.isUnsupported(c), isFalse,
            reason: '${c.currentObjectId} should not be a dead end');
      }
    });

    test('the dead-end label points at Telegram', () {
      expect(MessageContentSupport.describe(unsupported),
          MessageContentSupport.unsupportedLabel);
      expect(MessageContentSupport.unsupportedLabel, contains('Telegram'));
    });
  });
}
