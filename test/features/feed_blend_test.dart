import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/domain/feed_thread.dart';
import 'package:gramx/features/feed/domain/post.dart';

/// [minutesAgo] doubles as the ordering: bigger is older.
Post post(String id, int minutesAgo, {bool isRead = false, int chatId = -100}) =>
    Post(
      id: id,
      chatId: chatId,
      channelId: '$chatId',
      messageId: int.parse(id.split('_').last),
      channelTitle: 'Channel $chatId',
      publishedAt:
          DateTime(2026, 8, 23, 12).subtract(Duration(minutes: minutesAgo)),
      isRead: isRead,
    );

List<String> idsOf(List<FeedEntry> entries) =>
    [for (final e in entries) e.thread.root.id];

List<bool> backlogFlags(List<FeedEntry> entries) =>
    [for (final e in entries) e.isBacklog];

void main() {
  group('orderBacklogIds', () {
    // Straight chronological order clusters: one quiet channel contributes a
    // run of consecutive rows and the mix reads as that channel.
    test('rotates channels instead of emptying one at a time', () {
      final ordered = orderBacklogIds([
        post('-100_1', 500, chatId: -100),
        post('-100_2', 400, chatId: -100),
        post('-100_3', 300, chatId: -100),
        post('-200_1', 450, chatId: -200),
        post('-200_2', 350, chatId: -200),
        post('-300_1', 480, chatId: -300),
      ]);

      expect(ordered, [
        '-100_1', '-300_1', '-200_1', // one from each, oldest channel first
        '-100_2', '-200_2',
        '-100_3',
      ]);
    });

    test('within a channel, oldest first', () {
      final ordered = orderBacklogIds([
        post('-100_2', 100, chatId: -100),
        post('-100_1', 900, chatId: -100),
      ]);

      expect(ordered, ['-100_1', '-100_2']);
    });

    test('no two neighbours share a channel while others have posts left', () {
      final ordered = orderBacklogIds([
        for (var i = 1; i <= 4; i++) post('-100_$i', 500 - i, chatId: -100),
        for (var i = 1; i <= 4; i++) post('-200_$i', 500 - i, chatId: -200),
      ]);

      for (var i = 0; i < ordered.length - 1; i++) {
        expect(ordered[i].split('_').first,
            isNot(ordered[i + 1].split('_').first));
      }
    });
  });

  group('selectBacklogCandidates', () {
    test('the newest posts are left where they are', () {
      final posts = [for (var i = 1; i <= 40; i++) post('-100_$i', i)];
      final candidates = selectBacklogCandidates(posts, freshWindow: 25);

      // Positions 1..25 are the fresh window; 26..40 are candidates.
      expect(candidates, hasLength(15));
      expect(candidates, isNot(contains('-100_1')));
      expect(candidates, contains('-100_40'));
    });

    // The first painted feed is short — one post per channel plus whatever
    // TDLib had cached — so the window has to be small enough that a cold
    // start still has something to mix in.
    test('a cold start has candidates as soon as the feed is painted', () {
      final posts = [for (var i = 1; i <= 30; i++) post('-100_$i', i)];

      expect(selectBacklogCandidates(posts), isNotEmpty);
      expect(kFreshWindow, lessThan(30));
    });

    test('posts already read are not candidates', () {
      final posts = [
        for (var i = 1; i <= 30; i++) post('-100_$i', i, isRead: i > 25),
      ];

      expect(selectBacklogCandidates(posts, freshWindow: 25), isEmpty);
    });

    // Unread is unread: one that arrived with the ordinary backfill belongs in
    // the mix on the same terms as one the unread sweep went and fetched.
    test('a short feed has nothing behind the window to offer', () {
      final posts = [for (var i = 1; i <= 10; i++) post('-100_$i', i)];
      expect(selectBacklogCandidates(posts, freshWindow: 25), isEmpty);
    });
  });


  group('buildFeedEntries', () {
    test('with no backlog it is the feed it always was: newest first', () {
      final entries = buildFeedEntries([
        post('-100_1', 30),
        post('-100_2', 10),
        post('-100_3', 20),
      ]);

      expect(idsOf(entries), ['-100_2', '-100_3', '-100_1']);
      expect(backlogFlags(entries), everyElement(isFalse));
    });

    test('an empty feed has no rows', () {
      expect(buildFeedEntries(const []), isEmpty);
    });

    // The feed's one promise: the top is the most recent thing.
    test('the first row is never a backlog post', () {
      final entries = buildFeedEntries(
        [
          for (var i = 1; i <= 8; i++) post('-100_$i', i),
          post('-200_1', 5000, chatId: -200),
        ],
        backlogOrder: const ['-200_1'],
      );

      expect(entries.first.isBacklog, isFalse);
      expect(entries.first.thread.root.id, '-100_1');
    });

    test('backlog rows land one in every three', () {
      final entries = buildFeedEntries(
        [
          for (var i = 1; i <= 9; i++) post('-100_$i', i),
          for (var i = 1; i <= 3; i++)
            post('-200_$i', 5000 + i, chatId: -200),
        ],
        backlogOrder: const ['-200_1', '-200_2', '-200_3'],
      );

      expect(backlogFlags(entries).take(9), [
        false, false, true, // two fresh, then one owed
        false, false, true,
        false, false, true,
      ]);
    });

    // Read forwards, the way the channel wrote it.
    test('the backlog is woven in oldest first', () {
      final entries = buildFeedEntries(
        [
          for (var i = 1; i <= 12; i++) post('-100_$i', i),
          post('-200_1', 5000, chatId: -200),
          post('-200_2', 9000, chatId: -200),
        ],
        backlogOrder: const ['-200_2', '-200_1'],
      );

      final backlogOrder = [
        for (final e in entries)
          if (e.isBacklog) e.thread.root.id,
      ];
      expect(backlogOrder, ['-200_2', '-200_1'],
          reason: '-200_2 is the older of the two');
    });

    test('a backlog post appears once, not twice', () {
      final entries = buildFeedEntries(
        [
          for (var i = 1; i <= 6; i++) post('-100_$i', i),
          post('-200_1', 5000, chatId: -200),
        ],
        backlogOrder: const ['-200_1'],
      );

      expect(idsOf(entries).where((id) => id == '-200_1'), hasLength(1));
    });

    test('leftover backlog goes on the end rather than being dropped', () {
      final entries = buildFeedEntries(
        [
          post('-100_1', 1),
          post('-100_2', 2),
          for (var i = 1; i <= 4; i++) post('-200_$i', 5000 + i, chatId: -200),
        ],
        backlogOrder: const ['-200_1', '-200_2', '-200_3', '-200_4'],
      );

      expect(idsOf(entries), hasLength(6));
      expect(entries.last.isBacklog, isTrue);
    });

    // Too short to weave into: the feed stays exactly as it was rather than
    // opening on something from last week.
    test('a feed shorter than one cadence is left alone', () {
      final entries = buildFeedEntries(
        [
          post('-200_1', 5000, chatId: -200),
          post('-200_2', 9000, chatId: -200),
        ],
        backlogOrder: const ['-200_2', '-200_1'],
      );

      expect(idsOf(entries), ['-200_1', '-200_2']);
      expect(backlogFlags(entries), everyElement(isFalse));
    });

    // The cadence sets the ceiling: lifting everything unread would leave a
    // reverse-ordered tail of week-old posts under the fresh ones.
    test('only as many rows are lifted as there are slots for', () {
      final entries = buildFeedEntries(
        [
          for (var i = 1; i <= 6; i++) post('-100_$i', i),
          for (var i = 1; i <= 6; i++) post('-200_$i', 5000 + i, chatId: -200),
        ],
        backlogOrder: [for (var i = 1; i <= 6; i++) '-200_$i'],
      );

      // Twelve rows, so four slots — the other two backlog posts keep their
      // chronological place at the end.
      expect(backlogFlags(entries).where((flag) => flag), hasLength(4));
      expect(entries, hasLength(12));
    });

    // The reason the backlog set is fixed rather than recomputed: pagination
    // must not reshuffle what the reader is looking at.
    test('loading older posts does not move the rows already on screen', () {
      final firstPage = [for (var i = 1; i <= 8; i++) post('-100_$i', i)];
      const backlog = ['-200_1'];
      final before = buildFeedEntries(
        [...firstPage, post('-200_1', 5000, chatId: -200)],
        backlogOrder: backlog,
      );

      final after = buildFeedEntries(
        [
          ...firstPage,
          post('-200_1', 5000, chatId: -200),
          // A page of older posts arrives, unread ones among them.
          for (var i = 20; i <= 30; i++) post('-300_$i', 1000 + i, chatId: -300),
        ],
        backlogOrder: backlog,
      );

      expect(idsOf(after).take(before.length), idsOf(before));
    });

    // "Stays until you refresh": reading a backlog post must not make it jump
    // back to its chronological place under the reader's thumb.
    test('reading a backlog post leaves it where it is', () {
      List<FeedEntry> build({required bool read}) => buildFeedEntries(
            [
              for (var i = 1; i <= 8; i++) post('-100_$i', i),
              post('-200_1', 5000, chatId: -200, isRead: read),
            ],
            backlogOrder: const ['-200_1'],
          );

      expect(idsOf(build(read: true)), idsOf(build(read: false)));
    });

    test('a channel burst still collapses into one row', () {
      final entries = buildFeedEntries([
        post('-100_1', 30),
        Post(
          id: '-100_2',
          chatId: -100,
          channelId: '-100',
          messageId: 2,
          channelTitle: 'Channel -100',
          publishedAt: DateTime(2026, 8, 23, 11, 50),
          replyToMessageId: 1,
        ),
      ]);

      expect(entries, hasLength(1));
      expect(entries.single.thread.hasReplies, isTrue);
    });
  });
}
