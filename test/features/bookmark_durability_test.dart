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
  // Only a forward from a channel with a message id counts as a bookmark;
  // other Saved Messages are the user's own notes.
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
      final message = _saved(
        1,
        origin: {'@type': 'messageOriginUser', 'sender_user_id': 42},
      );

      expect(FeedRepository.bookmarkOriginOf(message), isNull);
    });

    test('a forward from a hidden sender is not', () {
      final message = _saved(
        1,
        origin: {'@type': 'messageOriginHiddenUser', 'sender_name': 'Someone'},
      );

      expect(FeedRepository.bookmarkOriginOf(message), isNull);
    });

    // Telegram sometimes omits the message id on a channel forward.
    test('a channel origin with no message id is not enough', () {
      final message = _saved(
        1,
        origin: _channelOrigin(chatId: -100123, messageId: 0),
      );

      expect(FeedRepository.bookmarkOriginOf(message), isNull);
    });
  });
}
