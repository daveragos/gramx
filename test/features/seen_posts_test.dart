import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/domain/seen_posts.dart';

UnreadMessage shown(int id, {int album = 0}) =>
    (id: id, albumId: album, isShown: true);

UnreadMessage hidden(int id) => (id: id, albumId: 0, isShown: false);

void main() {
  // Telegram's read state is a cursor. The feed shows a channel's newest post
  // first, and acknowledging it used to mark every older post read unseen.
  group('readableUpTo', () {
    test('moves over an unbroken run of seen posts', () {
      expect(
        readableUpTo(
          cursor: 10,
          unread: [shown(11), shown(12), shown(13)],
          seen: {11, 12},
        ),
        12,
      );
    });

    test('stays put when the oldest unread post was not seen', () {
      expect(
        readableUpTo(
          cursor: 10,
          unread: [shown(11), shown(12), shown(13)],
          seen: {12, 13},
        ),
        10,
      );
    });

    // A pin or a rename is dropped from the feed, so the reader can never
    // see it; it must not hold the cursor back for good.
    test('passes notices the feed never shows', () {
      expect(
        readableUpTo(
          cursor: 10,
          unread: [shown(11), hidden(12), shown(13)],
          seen: {11, 13},
        ),
        13,
      );
    });

    // An album is drawn as one post, keyed by its first message.
    test('passes an album whose first message was seen', () {
      expect(
        readableUpTo(
          cursor: 10,
          unread: [
            shown(11, album: 7),
            shown(12, album: 7),
            shown(13, album: 7),
            shown(14),
          ],
          seen: {11},
        ),
        13,
      );
    });

    test('ignores what is already below the cursor', () {
      expect(
        readableUpTo(cursor: 10, unread: [shown(9), shown(11)], seen: {11}),
        11,
      );
    });

    test('takes the messages in any order', () {
      expect(
        readableUpTo(
          cursor: 10,
          unread: [shown(12), shown(11)],
          seen: {11, 12},
        ),
        12,
      );
    });
  });

  group('SeenPosts', () {
    test('remembers posts per chat', () {
      final seen = SeenPosts()
        ..add(-1, 5)
        ..add(-1, 3)
        ..add(-2, 9);

      expect(seen.idsIn(-1), {3, 5});
      expect(seen.postIds, {'-1_3', '-1_5', '-2_9'});
      expect(seen.contains(-2, 9), isTrue);
    });

    test('says whether a post was new', () {
      final seen = SeenPosts();

      expect(seen.add(-1, 5), isTrue);
      expect(seen.add(-1, 5), isFalse);
    });

    // Once Telegram's cursor covers a post, the cursor hides it; the record
    // has nothing left to add.
    test('forgets what the cursor now covers', () {
      final seen = SeenPosts()
        ..add(-1, 5)
        ..add(-1, 9);

      expect(seen.settle(-1, 5), isTrue);
      expect(seen.idsIn(-1), {9});
      seen.settle(-1, 9);
      expect(seen.isEmpty, isTrue);
    });

    test('keeps the newest when a chat grows past the limit', () {
      final seen = SeenPosts();
      for (var id = 1; id <= SeenPosts.maxPerChat + 5; id++) {
        seen.add(-1, id);
      }

      final ids = seen.idsIn(-1);
      expect(ids, hasLength(SeenPosts.maxPerChat));
      expect(ids.first, 6);
    });

    test('survives a round trip through JSON', () {
      final seen = SeenPosts()
        ..add(-1, 5)
        ..add(-2, 9);

      final back = SeenPosts.fromJson(jsonDecode(jsonEncode(seen.toJson())));

      expect(back.postIds, seen.postIds);
    });

    test('reads anything else as empty', () {
      expect(SeenPosts.fromJson('nonsense').isEmpty, isTrue);
      expect(SeenPosts.fromJson({'x': 'y'}).isEmpty, isTrue);
    });
  });
}
