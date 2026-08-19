import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/infrastructure/telegram/message_content_support.dart';

td.MessageContent content(Map<String, dynamic> json) =>
    td.MessageContent.fromJson(json);

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
      'video': {
        '@type': 'file',
        'id': 1,
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
      },
      'is_secret': false,
    },
    'is_viewed': false,
    'is_secret': false,
  });

  final pinned = content({'@type': 'messagePinMessage', 'message_id': 42});
  final titleChanged =
      content({'@type': 'messageChatChangeTitle', 'title': 'New name'});
  final unsupported = content({'@type': 'messageUnsupported'});

  group('isRendered', () {
    test('true for content the mapper draws in full', () {
      expect(MessageContentSupport.isRendered(text), isTrue);
    });

    test('false for content it does not', () {
      expect(MessageContentSupport.isRendered(videoNote), isFalse);
      expect(MessageContentSupport.isRendered(unsupported), isFalse);
    });
  });

  group('isServiceMessage', () {
    // These are Telegram's notices about the chat itself, not posts.
    test('true for pins and chat changes', () {
      expect(MessageContentSupport.isServiceMessage(pinned), isTrue);
      expect(MessageContentSupport.isServiceMessage(titleChanged), isTrue);
    });

    test('false for real content', () {
      expect(MessageContentSupport.isServiceMessage(text), isFalse);
      expect(MessageContentSupport.isServiceMessage(videoNote), isFalse);
    });
  });

  group('belongsInFeed', () {
    test('service messages are dropped', () {
      expect(MessageContentSupport.belongsInFeed(pinned), isFalse);
      expect(MessageContentSupport.belongsInFeed(titleChanged), isFalse);
    });

    test('real content is kept, even if unrenderable', () {
      expect(MessageContentSupport.belongsInFeed(text), isTrue);
      expect(MessageContentSupport.belongsInFeed(videoNote), isTrue);
      expect(MessageContentSupport.belongsInFeed(unsupported), isTrue);
    });
  });

  group('describe', () {
    // The bug this fixes: unhandled content produced a card with a header, a
    // timestamp, an action bar, and nothing in between.
    test('labels content the feed cannot draw', () {
      expect(MessageContentSupport.describe(videoNote), '🎥 Video message');
    });

    test('never labels content that renders properly', () {
      expect(MessageContentSupport.describe(text), isNull);
    });

    test('never labels a service message, which is dropped instead', () {
      expect(MessageContentSupport.describe(pinned), isNull);
      expect(MessageContentSupport.describe(titleChanged), isNull);
    });

    test('falls back to a generic label for anything unknown', () {
      final label = MessageContentSupport.describe(unsupported);
      expect(label, isNotNull);
      expect(label, contains('Telegram'));
    });

    test('every label is non-empty', () {
      for (final c in [videoNote, unsupported]) {
        expect(MessageContentSupport.describe(c), isNotEmpty);
      }
    });
  });
}
