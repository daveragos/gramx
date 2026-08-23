import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';

Post post(
  String id, {
  required int minutesAgo,
  bool isBookmarked = false,
  bool isRead = false,
  Map<String, int> reactions = const {},
}) {
  final parts = id.split('_');
  return Post(
    id: id,
    chatId: int.parse(parts[0]),
    channelId: parts[0],
    messageId: int.parse(parts[1]),
    channelTitle: 'Channel ${parts[0]}',
    publishedAt: DateTime(2026, 1, 1, 12).subtract(Duration(minutes: minutesAgo)),
    isBookmarked: isBookmarked,
    isRead: isRead,
    reactions: reactions,
  );
}

void main() {
  group('dropAlreadyRead', () {
    // Pulling for new material and being handed back what you just read is the
    // opposite of what the gesture asks for.
    test('drops posts that were on screen and are now read', () {
      final fetched = [
        post('-1_1', minutesAgo: 10, isRead: true),
        post('-1_2', minutesAgo: 5, isRead: false),
      ];

      final kept = dropAlreadyRead(fetched, {'-1_1', '-1_2'});

      expect(kept.map((p) => p.id), ['-1_2']);
    });

    // The reported bug: a post finished seconds before the refresh came
    // straight back, because the acknowledgement was still queued and
    // Telegram's cursor had not moved yet.
    test('drops posts this app marked read, before Telegram agrees', () {
      final fetched = [
        post('-1_1', minutesAgo: 10, isRead: false),
        post('-1_2', minutesAgo: 5, isRead: false),
      ];

      final kept = dropAlreadyRead(
        fetched,
        {'-1_1', '-1_2'},
        readHere: {'-1_1'},
      );

      expect(kept.map((p) => p.id), ['-1_2']);
    });

    test('a post read here but never on screen still survives', () {
      final fetched = [post('-1_1', minutesAgo: 10)];

      expect(
        dropAlreadyRead(fetched, const {}, readHere: {'-1_1'}),
        hasLength(1),
      );
    });

    // Filtering on "read" alone would empty the feed on a cold start —
    // everything older than the read cursor is read.
    test('keeps read posts that were never on screen', () {
      final fetched = [post('-1_1', minutesAgo: 10, isRead: true)];

      expect(dropAlreadyRead(fetched, const {}), hasLength(1));
      expect(dropAlreadyRead(fetched, {'-9_9'}), hasLength(1));
    });

    // Filtering on "seen" alone would drop unread posts the reader
    // deliberately scrolled past to come back to.
    test('keeps unread posts even if they were on screen', () {
      final fetched = [post('-1_1', minutesAgo: 10, isRead: false)];

      expect(dropAlreadyRead(fetched, {'-1_1'}), hasLength(1));
    });

    test('new posts always survive', () {
      final fetched = [
        post('-1_1', minutesAgo: 10, isRead: true),
        post('-1_9', minutesAgo: 1, isRead: false),
      ];

      expect(dropAlreadyRead(fetched, {'-1_1'}).map((p) => p.id), ['-1_9']);
    });

    test('can legitimately empty the feed when everything is read', () {
      final fetched = [
        post('-1_1', minutesAgo: 10, isRead: true),
        post('-1_2', minutesAgo: 5, isRead: true),
      ];

      expect(dropAlreadyRead(fetched, {'-1_1', '-1_2'}), isEmpty);
    });
  });

  group('mergePostsNewestFirst', () {
    test('adds new posts and orders newest first', () {
      final current = [post('-1_2', minutesAgo: 10)];
      final incoming = [
        post('-1_3', minutesAgo: 1),
        post('-2_9', minutesAgo: 30),
      ];

      final merged = mergePostsNewestFirst(current, incoming);

      expect(merged.map((p) => p.id), ['-1_3', '-1_2', '-2_9']);
    });

    // Optimistic state lives on the post in the list. Replacing an existing
    // entry with a freshly fetched copy would silently undo a reaction or
    // bookmark the user just tapped.
    test('keeps the existing copy of a post it already has', () {
      final current = [post('-1_2', minutesAgo: 10, isBookmarked: true)];
      final incoming = [post('-1_2', minutesAgo: 10)];

      final merged = mergePostsNewestFirst(current, incoming);

      expect(merged, hasLength(1));
      expect(merged.single.isBookmarked, isTrue,
          reason: 'the optimistic bookmark must survive');
    });

    test('returns the original list untouched when nothing is new', () {
      final current = [post('-1_2', minutesAgo: 10)];

      expect(
        identical(mergePostsNewestFirst(current, [post('-1_2', minutesAgo: 10)]),
            current),
        isTrue,
        reason: 'callers use identity to skip a pointless state update',
      );
      expect(identical(mergePostsNewestFirst(current, []), current), isTrue);
    });

    // Album members race each other onto the update stream, so the same post
    // can appear twice inside one incoming batch.
    test('deduplicates within the incoming batch too', () {
      final merged = mergePostsNewestFirst([], [
        post('-1_5', minutesAgo: 1),
        post('-1_5', minutesAgo: 1),
      ]);

      expect(merged, hasLength(1));
      expect(merged.single.id, '-1_5');
    });

    test('merging into an empty list keeps everything, sorted', () {
      final merged = mergePostsNewestFirst([], [
        post('-1_1', minutesAgo: 50),
        post('-1_2', minutesAgo: 5),
        post('-1_3', minutesAgo: 20),
      ]);

      expect(merged.map((p) => p.id), ['-1_2', '-1_3', '-1_1']);
    });

    test('interleaves posts from different channels by time', () {
      final current = [
        post('-1_10', minutesAgo: 5),
        post('-1_9', minutesAgo: 25),
      ];
      final incoming = [
        post('-2_1', minutesAgo: 15),
        post('-2_2', minutesAgo: 1),
      ];

      final merged = mergePostsNewestFirst(current, incoming);

      expect(merged.map((p) => p.id), ['-2_2', '-1_10', '-2_1', '-1_9']);
    });
  });
}
