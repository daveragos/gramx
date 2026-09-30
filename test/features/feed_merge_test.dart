import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';

import '../support/td_fixtures.dart';

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
    publishedAt: DateTime(
      2026,
      1,
      1,
      12,
    ).subtract(Duration(minutes: minutesAgo)),
    isBookmarked: isBookmarked,
    isRead: isRead,
    reactions: reactions,
  );
}

void main() {
  // The reported fault: every launch opened on the posts the reader went
  // through the time before, because a launch kept read posts and only a
  // refresh dropped them.
  group('unreadOnly', () {
    test('drops posts Telegram counts as read', () {
      final posts = [
        post('-1_1', minutesAgo: 10, isRead: true),
        post('-1_2', minutesAgo: 5),
      ];

      expect(unreadOnly(posts).map((p) => p.id), ['-1_2']);
    });

    // The acknowledgement is still queued, so Telegram's cursor has not
    // caught up yet. This app's own record is what knows.
    test('drops posts read here before Telegram agrees', () {
      final posts = [post('-1_1', minutesAgo: 10), post('-1_2', minutesAgo: 5)];

      expect(unreadOnly(posts, readHere: {'-1_1'}).map((p) => p.id), ['-1_2']);
    });

    test('hands back the same list when nothing is read', () {
      final posts = [post('-1_1', minutesAgo: 10), post('-1_2', minutesAgo: 5)];

      expect(identical(unreadOnly(posts), posts), isTrue);
    });

    test('can empty the feed when everything is read', () {
      final posts = [
        post('-1_1', minutesAgo: 10, isRead: true),
        post('-1_2', minutesAgo: 5, isRead: true),
      ];

      expect(unreadOnly(posts), isEmpty);
    });
  });

  // A headline card is built before the names of forwarded-from channels and
  // the excerpts of replied-to posts are looked up; the local pass that
  // follows has them, and must not lose to the card it improves on.
  group('replacePostsNewestFirst', () {
    test('takes the incoming copy of a post both hold', () {
      final current = [post('-1_2', minutesAgo: 5)];
      final fuller = post('-1_2', minutesAgo: 5, reactions: {'👍': 3});

      final merged = replacePostsNewestFirst(current, [fuller]);

      expect(merged, hasLength(1));
      expect(merged.single.reactions, {'👍': 3});
    });

    test('keeps what only the current list has, newest first', () {
      final current = [
        post('-1_2', minutesAgo: 5),
        post('-2_7', minutesAgo: 30),
      ];
      final incoming = [
        post('-1_2', minutesAgo: 5),
        post('-3_1', minutesAgo: 1),
      ];

      final merged = replacePostsNewestFirst(current, incoming);

      expect(merged.map((p) => p.id), ['-3_1', '-1_2', '-2_7']);
    });

    test('nothing incoming changes nothing', () {
      final current = [post('-1_2', minutesAgo: 5)];

      expect(
        identical(replacePostsNewestFirst(current, const []), current),
        isTrue,
      );
    });
  });

  // Paging a channel whose older history is all read fetches a page the
  // unread rule then throws away, on every scroll to the bottom.
  group('cursorsWithUnreadBehind', () {
    td.Chat channel(int id, {required int unread, required int lastRead}) =>
        TdFixtures.chat(
          id: id,
          unreadCount: unread,
        ).copyWith(lastReadInboxMessageId: lastRead);

    test('keeps a channel whose read cursor is behind its oldest post', () {
      final chats = {-1: channel(-1, unread: 40, lastRead: 100)};

      expect(cursorsWithUnreadBehind({-1: 150}, (id) => chats[id]), {-1: 150});
    });

    test('drops a channel read past its oldest loaded post', () {
      final chats = {-1: channel(-1, unread: 3, lastRead: 150)};

      expect(cursorsWithUnreadBehind({-1: 120}, (id) => chats[id]), isEmpty);
    });

    // A channel this account runs: its posts are its own, so nothing in it is
    // ever unread, however far behind the inbox cursor sits.
    test('drops a channel with nothing unread', () {
      final chats = {-1: channel(-1, unread: 0, lastRead: 0)};

      expect(cursorsWithUnreadBehind({-1: 120}, (id) => chats[id]), isEmpty);
    });

    test('drops a channel the cache does not know', () {
      expect(cursorsWithUnreadBehind({-1: 120}, (_) => null), isEmpty);
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
      expect(
        merged.single.isBookmarked,
        isTrue,
        reason: 'the optimistic bookmark must survive',
      );
    });

    test('returns the original list untouched when nothing is new', () {
      final current = [post('-1_2', minutesAgo: 10)];

      expect(
        identical(
          mergePostsNewestFirst(current, [post('-1_2', minutesAgo: 10)]),
          current,
        ),
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
