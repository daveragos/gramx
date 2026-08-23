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
        backlogIds: {'-200_1'},
      );

      expect(entries.first.isBacklog, isFalse);
      expect(entries.first.thread.root.id, '-100_1');
    });

    test('backlog rows land one in every four', () {
      final entries = buildFeedEntries(
        [
          for (var i = 1; i <= 9; i++) post('-100_$i', i),
          for (var i = 1; i <= 3; i++)
            post('-200_$i', 5000 + i, chatId: -200),
        ],
        backlogIds: {'-200_1', '-200_2', '-200_3'},
      );

      expect(backlogFlags(entries).take(8), [
        false, false, false, true, // three fresh, then one owed
        false, false, false, true,
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
        backlogIds: {'-200_1', '-200_2'},
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
        backlogIds: {'-200_1'},
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
        backlogIds: {'-200_1', '-200_2', '-200_3', '-200_4'},
      );

      expect(idsOf(entries), hasLength(6));
      expect(entries.last.isBacklog, isTrue);
    });

    // Nothing new at all: opening the feed on something from last week would
    // break the same promise as putting a backlog post first.
    test('with nothing fresh, the feed stays newest first', () {
      final entries = buildFeedEntries(
        [
          post('-200_1', 5000, chatId: -200),
          post('-200_2', 9000, chatId: -200),
        ],
        backlogIds: {'-200_1', '-200_2'},
      );

      expect(idsOf(entries), ['-200_1', '-200_2']);
      expect(backlogFlags(entries), everyElement(isTrue));
    });

    // The reason the backlog set is fixed rather than recomputed: pagination
    // must not reshuffle what the reader is looking at.
    test('loading older posts does not move the rows already on screen', () {
      final firstPage = [for (var i = 1; i <= 8; i++) post('-100_$i', i)];
      final backlog = {'-200_1'};
      final before = buildFeedEntries(
        [...firstPage, post('-200_1', 5000, chatId: -200)],
        backlogIds: backlog,
      );

      final after = buildFeedEntries(
        [
          ...firstPage,
          post('-200_1', 5000, chatId: -200),
          // A page of older posts arrives, unread ones among them.
          for (var i = 20; i <= 30; i++) post('-300_$i', 1000 + i, chatId: -300),
        ],
        backlogIds: backlog,
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
            backlogIds: {'-200_1'},
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
