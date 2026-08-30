import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/feed/data/feed_repository.dart';

import '../support/td_fixtures.dart';

/// A saved copy carries `forwardInfo`; the origin says where it came from.
td.Message _saved(int id, {required Map<String, dynamic>? origin}) {
  final json = TdFixtures.textMessageJson(id: id, chatId: 777);
  if (origin != null) {
    json['forward_info'] = {
      '@type': 'messageForwardInfo',
      'origin': origin,
      'date': 1700000000,
      'source': null,
      'public_service_announcement_type': '',
    };
  }
  return td.Message.fromJson(json);
}

Map<String, dynamic> _channelOrigin({
  required int chatId,
  required int messageId,
}) => {
  '@type': 'messageOriginChannel',
  'chat_id': chatId,
  'message_id': messageId,
  'author_signature': '',
};

void main() {
  // Saved Messages holds everything a reader has ever sent themselves. Only a
  // forward *from a channel*, with a message id behind it, is a bookmark — so
  // this is the filter that stops a restore turning somebody's notes to self
  // into bookmarks.
  group('FeedRepository.bookmarkOriginOf', () {
    test('a forwarded channel post is a bookmark', () {
      final message = _saved(
        1,
        origin: _channelOrigin(chatId: -100123, messageId: 4194304),
      );

      final origin = FeedRepository.bookmarkOriginOf(message);
      expect(origin, isNotNull);
      expect(origin!.chatId, -100123);
      expect(origin.messageId, 4194304);
    });

    test('a note typed to yourself is not', () {
      expect(FeedRepository.bookmarkOriginOf(_saved(1, origin: null)), isNull);
    });

    test('a forward from a person is not', () {
      final message = _saved(1, origin: {
        '@type': 'messageOriginUser',
        'sender_user_id': 42,
      });

      expect(FeedRepository.bookmarkOriginOf(message), isNull);
    });

    test('a forward from a hidden sender is not', () {
      final message = _saved(1, origin: {
        '@type': 'messageOriginHiddenUser',
        'sender_name': 'Someone',
      });

      expect(FeedRepository.bookmarkOriginOf(message), isNull);
    });

    // Telegram sometimes attributes a forward to a channel without naming the
    // message. That is not enough to find a post with, and a row built from it
    // would point at message zero.
    test('a channel origin with no message id is not enough', () {
      final message = _saved(
        1,
        origin: _channelOrigin(chatId: -100123, messageId: 0),
      );

      expect(FeedRepository.bookmarkOriginOf(message), isNull);
    });
  });
}
