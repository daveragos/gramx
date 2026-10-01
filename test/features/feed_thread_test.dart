import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/domain/feed_thread.dart';
import 'package:gramx/features/feed/domain/post.dart';

Post post({
  int chatId = -1,
  required int messageId,
  required int minutesAgo,
  int? replyTo,
}) => Post(
  id: '${chatId}_$messageId',
  chatId: chatId,
  channelId: '$chatId',
  messageId: messageId,
  channelTitle: 'Channel $chatId',
  replyToMessageId: replyTo,
  publishedAt: DateTime(2026, 1, 1, 12).subtract(Duration(minutes: minutesAgo)),
);

void main() {
  group('groupIntoThreads', () {
    test('a post with no replies is its own thread', () {
      final threads = groupIntoThreads([post(messageId: 1, minutesAgo: 5)]);

      expect(threads, hasLength(1));
      expect(threads.single.hasReplies, isFalse);
    });

    // Keeps a burst of follow-ups from one channel from burying the others.
    test('collapses follow-ups under the post they reply to', () {
      final threads = groupIntoThreads([
        post(messageId: 1, minutesAgo: 30),
        post(messageId: 2, minutesAgo: 20, replyTo: 1),
        post(messageId: 3, minutesAgo: 10, replyTo: 1),
      ]);

      expect(threads, hasLength(1));
      expect(threads.single.root.messageId, 1);
      expect(threads.single.replies.map((p) => p.messageId), [2, 3]);
    });

    test('folds a chain all the way to its root', () {
      final threads = groupIntoThreads([
        post(messageId: 1, minutesAgo: 30),
        post(messageId: 2, minutesAgo: 20, replyTo: 1),
        post(messageId: 3, minutesAgo: 10, replyTo: 2),
      ]);

      expect(threads, hasLength(1));
      expect(threads.single.root.messageId, 1);
      expect(threads.single.replies.map((p) => p.messageId), [2, 3]);
    });

    // A reply preview on the card already shows cross-channel context; treating
    // it as a thread would hide one channel's post under another's.
    test('does not thread across channels', () {
      final threads = groupIntoThreads([
        post(chatId: -1, messageId: 1, minutesAgo: 30),
        post(chatId: -2, messageId: 2, minutesAgo: 20, replyTo: 1),
      ]);

      expect(threads, hasLength(2));
    });

    // Otherwise a reply whose parent scrolled out of the window would vanish.
    test('a reply whose parent is absent stands on its own', () {
      final threads = groupIntoThreads([
        post(messageId: 5, minutesAgo: 10, replyTo: 999),
      ]);

      expect(threads, hasLength(1));
      expect(threads.single.root.messageId, 5);
    });

    test('replies are ordered oldest first, as written', () {
      final threads = groupIntoThreads([
        post(messageId: 1, minutesAgo: 30),
        post(messageId: 3, minutesAgo: 5, replyTo: 1),
        post(messageId: 2, minutesAgo: 20, replyTo: 1),
      ]);

      expect(threads.single.replies.map((p) => p.messageId), [2, 3]);
    });

    test('threads are ordered by their most recent activity', () {
      final threads = groupIntoThreads([
        // Old root, but a fresh follow-up.
        post(messageId: 1, minutesAgo: 100),
        post(messageId: 2, minutesAgo: 1, replyTo: 1),
        // Standalone post in between.
        post(chatId: -2, messageId: 9, minutesAgo: 50),
      ]);

      expect(
        threads.first.root.messageId,
        1,
        reason: 'a follow-up should surface the thread',
      );
      expect(threads.last.root.messageId, 9);
    });

    test('lastActivity reports the newest post in the thread', () {
      final threads = groupIntoThreads([
        post(messageId: 1, minutesAgo: 100),
        post(messageId: 2, minutesAgo: 4, replyTo: 1),
      ]);

      expect(
        threads.single.lastActivity,
        threads.single.replies.single.publishedAt,
      );
    });

    // A thread surfaces because of its newest post, so the collapsed card
    // shows that one.
    test('latest is the newest post, earlier is everything before it', () {
      final thread = groupIntoThreads([
        post(messageId: 1, minutesAgo: 30),
        post(messageId: 2, minutesAgo: 20, replyTo: 1),
        post(messageId: 3, minutesAgo: 2, replyTo: 1),
      ]).single;

      expect(thread.latest.messageId, 3);
      expect(thread.earlier.map((p) => p.messageId), [1, 2]);
    });

    test('a thread with no replies is its own latest, with no earlier', () {
      final thread = groupIntoThreads([
        post(messageId: 1, minutesAgo: 5),
      ]).single;

      expect(thread.latest.messageId, 1);
      expect(thread.earlier, isEmpty);
    });

    test('latest plus earlier covers every post exactly once', () {
      final thread = groupIntoThreads([
        post(messageId: 1, minutesAgo: 30),
        post(messageId: 2, minutesAgo: 20, replyTo: 1),
        post(messageId: 3, minutesAgo: 10, replyTo: 2),
      ]).single;

      expect(
        [...thread.earlier, thread.latest].map((p) => p.messageId),
        thread.allPosts.map((p) => p.messageId),
      );
    });

    test('allPosts lists the root first', () {
      final threads = groupIntoThreads([
        post(messageId: 1, minutesAgo: 30),
        post(messageId: 2, minutesAgo: 20, replyTo: 1),
      ]);

      expect(threads.single.allPosts.map((p) => p.messageId), [1, 2]);
    });

    test('an empty list yields no threads', () {
      expect(groupIntoThreads([]), isEmpty);
    });

    // Malformed data must not hang the feed.
    test('a self-reply does not loop', () {
      final threads = groupIntoThreads([
        post(messageId: 1, minutesAgo: 5, replyTo: 1),
        post(messageId: 2, minutesAgo: 4),
      ]);

      expect(threads, hasLength(2));
    });

    // In a cycle no post is a root, so without care the whole group would
    // drop out of the feed.
    test('a reply cycle keeps both posts in the feed', () {
      final posts = [
        post(messageId: 1, minutesAgo: 5, replyTo: 2),
        post(messageId: 2, minutesAgo: 4, replyTo: 1),
      ];

      final seen = groupIntoThreads(
        posts,
      ).expand((t) => t.allPosts).map((p) => p.id).toSet();

      expect(seen, posts.map((p) => p.id).toSet());
    });

    test('every post survives grouping', () {
      final posts = [
        post(messageId: 1, minutesAgo: 30),
        post(messageId: 2, minutesAgo: 20, replyTo: 1),
        post(messageId: 3, minutesAgo: 10, replyTo: 2),
        post(chatId: -2, messageId: 4, minutesAgo: 5),
      ];

      final seen = groupIntoThreads(
        posts,
      ).expand((t) => t.allPosts).map((p) => p.id).toSet();

      expect(seen, posts.map((p) => p.id).toSet());
    });
  });

  // Unrelated posts from one channel within a minute would take over the top
  // of the feed, and groupIntoThreads can't collapse them.
  group('scatterChannelBursts', () {
    List<String> idsOf(List<FeedThread> threads) => [
      for (final t in threads) t.root.id,
    ];

    List<FeedThread> threadsOf(List<Post> posts) => [
      for (final p in posts) FeedThread(root: p),
    ];

    test('a burst is broken up by whatever else is in the feed', () {
      final scattered = scatterChannelBursts(
        threadsOf([
          post(chatId: -1, messageId: 1, minutesAgo: 1),
          post(chatId: -1, messageId: 2, minutesAgo: 2),
          post(chatId: -1, messageId: 3, minutesAgo: 3),
          post(chatId: -2, messageId: 1, minutesAgo: 20),
          post(chatId: -3, messageId: 1, minutesAgo: 30),
          post(chatId: -4, messageId: 1, minutesAgo: 40),
        ]),
      );

      // No two neighbours from the same channel.
      for (var i = 0; i < scattered.length - 1; i++) {
        expect(
          scattered[i].root.chatId == scattered[i + 1].root.chatId,
          isFalse,
          reason: 'row $i and ${i + 1} are both from one channel',
        );
      }
      expect(scattered, hasLength(6));
    });

    // Only bursts are spread out; the feed otherwise stays chronological.
    test('a channel posting steadily is left exactly as it was', () {
      final posts = threadsOf([
        post(chatId: -1, messageId: 3, minutesAgo: 60),
        post(chatId: -1, messageId: 2, minutesAgo: 120),
        post(chatId: -1, messageId: 1, minutesAgo: 180),
      ]);

      expect(idsOf(scatterChannelBursts(posts)), idsOf(posts));
    });

    // A later post must never overtake an earlier one from the same channel.
    test('a channel\'s own posts keep their order', () {
      final scattered = scatterChannelBursts(
        threadsOf([
          post(chatId: -1, messageId: 3, minutesAgo: 1),
          post(chatId: -1, messageId: 2, minutesAgo: 2),
          post(chatId: -1, messageId: 1, minutesAgo: 3),
          post(chatId: -2, messageId: 1, minutesAgo: 10),
          post(chatId: -2, messageId: 2, minutesAgo: 11),
        ]),
      );

      final ownOrder = [
        for (final t in scattered)
          if (t.root.chatId == -1) t.root.messageId,
      ];
      expect(ownOrder, [3, 2, 1]);
    });

    test('nothing is dropped when there is nothing to interleave with', () {
      final posts = threadsOf([
        post(chatId: -1, messageId: 3, minutesAgo: 1),
        post(chatId: -1, messageId: 2, minutesAgo: 2),
        post(chatId: -1, messageId: 1, minutesAgo: 3),
      ]);

      expect(idsOf(scatterChannelBursts(posts)), idsOf(posts));
    });

    test('a feed too short to have a run is left alone', () {
      final posts = threadsOf([
        post(chatId: -1, messageId: 2, minutesAgo: 1),
        post(chatId: -1, messageId: 1, minutesAgo: 2),
      ]);

      expect(identical(scatterChannelBursts(posts), posts), isTrue);
    });
  });
}
