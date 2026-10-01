import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/feed/domain/feed_thread.dart';
import 'package:gramx/features/feed/domain/post.dart';

Post post(int messageId, {int? replyTo}) => Post(
  id: '-100_$messageId',
  chatId: -100,
  channelId: '-100',
  messageId: messageId,
  channelTitle: 'Nasa Daily',
  publishedAt: DateTime(2026, 8, 30, 12, messageId),
  replyToMessageId: replyTo,
);

/// A reply already draws what it answers, so a thread hiding just one post has
/// nothing new to reveal.
void main() {
  group('FeedThread.hasEarlierToBeShown', () {
    test('a lone post has nothing behind it', () {
      expect(FeedThread(root: post(1)).hasEarlierToBeShown, isFalse);
    });

    test('one hidden post is one the reply already shows', () {
      final thread = FeedThread(root: post(1), replies: [post(2, replyTo: 1)]);

      expect(thread.earlier.length, 1);
      expect(thread.hasEarlierToBeShown, isFalse);
    });

    test('two is where there is genuinely something behind the card', () {
      final thread = FeedThread(
        root: post(1),
        replies: [post(2, replyTo: 1), post(3, replyTo: 2)],
      );

      expect(thread.earlier.length, 2);
      expect(thread.hasEarlierToBeShown, isTrue);
    });

    test('and stays true as the thread grows', () {
      final thread = FeedThread(
        root: post(1),
        replies: [
          post(2, replyTo: 1),
          post(3, replyTo: 2),
          post(4, replyTo: 3),
        ],
      );

      expect(thread.hasEarlierToBeShown, isTrue);
    });

    /// A thread surfaces by its newest message, so the card always shows it.
    test('the newest post is the card either way', () {
      final two = FeedThread(root: post(1), replies: [post(2, replyTo: 1)]);
      final three = FeedThread(
        root: post(1),
        replies: [post(2, replyTo: 1), post(3, replyTo: 2)],
      );

      expect(two.latest.messageId, 2);
      expect(three.latest.messageId, 3);
    });
  });
}
