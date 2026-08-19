import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';

void main() {
  group('narrowCursors', () {
    // Without this, scrolling to the bottom of a three-channel folder paged
    // every subscription and filtered almost all of it away — so the visible
    // list barely grew and the scroll listener fired again immediately.
    test('keeps only the chats a folder shows', () {
      final cursors = {-1: 100, -2: 200, -3: 300};

      expect(narrowCursors(cursors, {-1, -3}), {-1: 100, -3: 300});
    });

    test('a null filter passes everything through, for the All tab', () {
      final cursors = {-1: 100, -2: 200};
      expect(narrowCursors(cursors, null), same(cursors));
    });

    test('a folder with no loaded channels narrows to nothing', () {
      expect(narrowCursors({-1: 100}, {-9}), isEmpty);
    });

    test('ids in the filter that have no cursor are ignored', () {
      expect(narrowCursors({-1: 100}, {-1, -2, -3}), {-1: 100});
    });
  });

  group('selectPaginationFrontier', () {
    // Only channels whose oldest loaded post is newest can extend a merged feed
    // backwards; the rest already reach further back than the frontier.
    test('picks the channels with the newest oldest post', () {
      final cursors = {-1: 500, -2: 100, -3: 900, -4: 300};

      final page = FeedRepository.selectPaginationFrontier(cursors, limit: 2);

      expect(page.map((e) => e.key), [-3, -1]);
    });

    test('caps the page size', () {
      final cursors = {for (var i = 1; i <= 50; i++) -i: i * 10};

      expect(
        FeedRepository.selectPaginationFrontier(cursors, limit: 10),
        hasLength(10),
      );
    });

    test('returns everything when there are fewer channels than the limit', () {
      final cursors = {-1: 10, -2: 20};

      expect(
        FeedRepository.selectPaginationFrontier(cursors, limit: 10),
        hasLength(2),
      );
    });

    test('an empty cursor map yields an empty page', () {
      expect(
        FeedRepository.selectPaginationFrontier({}, limit: 10),
        isEmpty,
      );
    });

    test('carries the cursor value through with its chat id', () {
      final page =
          FeedRepository.selectPaginationFrontier({-7: 4242}, limit: 5);

      expect(page.single.key, -7);
      expect(page.single.value, 4242);
    });
  });

  group('pagination is bounded', () {
    test('one page never exceeds the documented channel cap', () {
      expect(FeedRepository.paginationChannelsPerPage, lessThanOrEqualTo(15),
          reason: 'a scroll to the bottom repeats; it must stay small');
    });
  });
}
