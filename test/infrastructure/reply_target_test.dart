import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/domain/feed_thread.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';
import 'package:handy_tdlib/api.dart' as td;

import '../support/td_fixtures.dart';

/// A message replying to [messageId], optionally in another chat.
td.Message replyMessage({
  required int chatId,
  required int messageId,
  int replyChatId = 0,
}) {
  final json = TdFixtures.textMessageJson(id: 900, chatId: chatId);
  json['reply_to'] = {
    '@type': 'messageReplyToMessage',
    'chat_id': replyChatId,
    'message_id': messageId,
    // TDLib's fromJson casts this straight to int, so it has to be present.
    'origin_send_date': 0,
  };
  return td.Message.fromJson(json);
}

Post threadPost(
  String id, {
  int? replyToMessageId,
  int? replyToChatId,
  int minutesAgo = 0,
}) {
  final parts = id.split('_');
  return Post(
    id: id,
    chatId: int.parse(parts[0]),
    channelId: parts[0],
    messageId: int.parse(parts[1]),
    channelTitle: 'Channel',
    publishedAt: DateTime(
      2026,
      8,
      23,
      12,
    ).subtract(Duration(minutes: minutesAgo)),
    replyToMessageId: replyToMessageId,
    replyToChatId: replyToChatId,
  );
}

void main() {
  group('reply targets', () {
    // Telegram replies can cross chats; without the chat id the lookup fails.
    test('a reply into another chat keeps that chat id', () {
      final post = TdlibMappers.mapMessageToPost(
        replyMessage(chatId: -1001, messageId: 50, replyChatId: -1002),
        TdFixtures.chat(id: -1001),
      );

      expect(post.replyToMessageId, 50);
      expect(post.replyToChatId, -1002);
    });

    // 0 means the same chat, as does the chat's own id.
    test('a reply within the same chat carries no chat id', () {
      for (final replyChatId in [0, -1001]) {
        final post = TdlibMappers.mapMessageToPost(
          replyMessage(chatId: -1001, messageId: 50, replyChatId: replyChatId),
          TdFixtures.chat(id: -1001),
        );

        expect(post.replyToChatId, isNull, reason: 'chat_id $replyChatId');
        expect(post.replyToMessageId, 50);
      }
    });

    test('a message with no reply has neither', () {
      final post = TdlibMappers.mapMessageToPost(
        TdFixtures.textMessage(id: 900, chatId: -1001),
        TdFixtures.chat(id: -1001),
      );

      expect(post.replyToMessageId, isNull);
      expect(post.replyToChatId, isNull);
    });
  });

  group('threading', () {
    test('a same-chat reply still collapses into its parent', () {
      final threads = groupIntoThreads([
        threadPost('-1_1', minutesAgo: 20),
        threadPost('-1_2', replyToMessageId: 1, minutesAgo: 10),
      ]);

      expect(threads, hasLength(1));
      expect(threads.single.replies, hasLength(1));
    });

    // Message ids are only unique within a chat.
    test('a cross-chat reply is a quote, not a thread', () {
      final threads = groupIntoThreads([
        threadPost('-1_1', minutesAgo: 20),
        threadPost(
          '-1_2',
          replyToMessageId: 1,
          replyToChatId: -999,
          minutesAgo: 10,
        ),
      ]);

      expect(threads, hasLength(2));
    });
  });
}
