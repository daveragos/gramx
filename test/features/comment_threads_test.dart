import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/post_detail/domain/comment_threads.dart';

Post comment(int messageId, {int? replyTo}) => Post(
  id: '-1_$messageId',
  chatId: -1,
  channelId: '-1',
  messageId: messageId,
  channelTitle: 'Discussion',
  replyToMessageId: replyTo,
  publishedAt: DateTime(2026, 1, 1).add(Duration(minutes: messageId)),
);

List<int> ids(List<Post> posts) => [for (final p in posts) p.messageId];

void main() {
  group('threadComments', () {
    test('top-level comments come newest first', () {
      final threads = threadComments([comment(1), comment(3), comment(2)]);
      expect(threads.map((t) => t.root.messageId), [3, 2, 1]);
    });

    // TDLib returns newest first, which read a conversation upside down.
    test('replies come oldest first under their top-level comment', () {
      final threads = threadComments([
        comment(9, replyTo: 7),
        comment(8, replyTo: 7),
        comment(7, replyTo: 1),
        comment(1),
      ]);

      expect(threads, hasLength(1));
      expect(threads.single.root.messageId, 1);
      expect(ids(threads.single.replies), [7, 8, 9]);
    });

    test('a long chain stays together however deep it goes', () {
      final chain = [
        comment(1),
        for (var id = 2; id <= 30; id++) comment(id, replyTo: id - 1),
      ];

      final threads = threadComments(chain.reversed.toList());

      expect(threads, hasLength(1));
      expect(threads.single.replies, hasLength(29));
    });

    test('a reply to a comment that isn\'t loaded is top-level', () {
      final threads = threadComments([comment(5, replyTo: 2), comment(6)]);
      expect(threads.map((t) => t.root.messageId), [6, 5]);
    });

    test('a reply loop ends instead of hanging', () {
      final threads = threadComments([
        comment(1, replyTo: 2),
        comment(2, replyTo: 1),
      ]);
      expect(threads.expand((t) => [t.root, ...t.replies]), hasLength(2));
    });
  });

  group('replyingToLabel', () {
    final all = [comment(1), comment(2, replyTo: 1), comment(3, replyTo: 1)];

    test('is left out right under the parent', () {
      expect(replyingToLabel(all[1], all[0], all), isNull);
    });

    test('names the parent when another reply sits in between', () {
      expect(replyingToLabel(all[2], all[1], all)?.messageId, 1);
    });
  });
}
