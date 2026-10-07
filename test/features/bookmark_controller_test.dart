import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/bookmarks/presentation/bookmark_providers.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';

Post post(String id, {bool bookmarked = false}) => Post(
  id: id,
  chatId: int.parse(id.split('_').first),
  channelId: id.split('_').first,
  messageId: int.parse(id.split('_').last),
  channelTitle: 'Nasa',
  publishedAt: DateTime(2026, 10, 7),
  isBookmarked: bookmarked,
);

/// Keeps bookmarks in a set, and can hold writes back to test their order.
class _Repository implements FeedRepository {
  final Set<String> stored;
  final List<bool> writes = [];

  /// When set, each write waits for it.
  Completer<void>? gate;

  _Repository(this.stored);

  @override
  Future<void> setBookmarked(
    int chatId,
    int messageId, {
    required bool bookmarked,
  }) async {
    await gate?.future;
    writes.add(bookmarked);
    final id = '${chatId}_$messageId';
    bookmarked ? stored.add(id) : stored.remove(id);
  }

  @override
  Future<({List<Post> posts, Set<String> restoredIds})> loadBookmarks() async =>
      (
        posts: [for (final id in stored) post(id, bookmarked: true)],
        restoredIds: <String>{},
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

class _EmptyFeed extends FeedNotifier {
  @override
  Future<List<Post>> build() async => const [];
}

void main() {
  ProviderContainer containerWith(_Repository repo) {
    final c = ProviderContainer(
      overrides: [
        feedRepositoryProvider.overrideWithValue(repo),
        feedPostsProvider.overrideWith(_EmptyFeed.new),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('BookmarkController', () {
    // Each button ran a provider that only ever ran once per post, so the
    // second tap did nothing.
    test('a second tap removes the bookmark the first one made', () async {
      final repo = _Repository({});
      final c = containerWith(repo);
      final controller = c.read(bookmarkControllerProvider.notifier);
      final p = post('-100_5');

      await controller.toggle(p);
      expect(repo.stored, {'-100_5'});

      await controller.toggle(p);
      expect(repo.stored, isEmpty);
    });

    test('a bookmark loaded as such comes off at the first tap', () async {
      final repo = _Repository({'-100_5'});
      final c = containerWith(repo);

      await c
          .read(bookmarkControllerProvider.notifier)
          .toggle(post('-100_5', bookmarked: true));

      expect(repo.stored, isEmpty);
      expect(repo.writes, [false]);
    });

    test('quick taps are written in order, and the last one wins', () async {
      final repo = _Repository({})..gate = Completer<void>();
      final c = containerWith(repo);
      final controller = c.read(bookmarkControllerProvider.notifier);
      final p = post('-100_5');

      final writes = [
        controller.toggle(p),
        controller.toggle(p),
        controller.toggle(p),
      ];
      repo.gate!.complete();
      await Future.wait(writes);

      expect(repo.writes, [true, false, true]);
      expect(repo.stored, {'-100_5'});
    });

    test('an unbookmarked post leaves the list at once', () async {
      final repo = _Repository({'-100_5', '-100_6'});
      final c = containerWith(repo);
      await c.read(bookmarksProvider.future);
      expect(c.read(bookmarkedPostsProvider).value, hasLength(2));

      final removal = c
          .read(bookmarkControllerProvider.notifier)
          .toggle(post('-100_5', bookmarked: true));

      expect(c.read(bookmarkedPostsProvider).value!.map((p) => p.id), [
        '-100_6',
      ]);
      await removal;
    });
  });

  group('filterBookmarks', () {
    final posts = [post('-100_1'), post('-100_2'), post('-100_3')];
    const restored = {'-100_2'};

    test('shows them all, or either kind', () {
      expect(filterBookmarks(posts, restored, BookmarkFilter.all), posts);
      expect(
        filterBookmarks(posts, restored, BookmarkFilter.here).map((p) => p.id),
        ['-100_1', '-100_3'],
      );
      expect(
        filterBookmarks(
          posts,
          restored,
          BookmarkFilter.restored,
        ).map((p) => p.id),
        ['-100_2'],
      );
    });
  });

  // A restored bookmark's Saved Messages copy can be the user's own save,
  // so it must never be deleted along with the bookmark.
  group('FeedRepository.wasRestored', () {
    final bookmarkedAt = DateTime.utc(2026, 10, 7, 12);
    int seconds(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

    test('a copy written when bookmarking is gramX\'s own', () {
      final copy = bookmarkedAt.subtract(const Duration(seconds: 3));
      expect(FeedRepository.wasRestored(bookmarkedAt, seconds(copy)), isFalse);
    });

    test('a copy from long before was there already', () {
      final copy = bookmarkedAt.subtract(const Duration(days: 40));
      expect(FeedRepository.wasRestored(bookmarkedAt, seconds(copy)), isTrue);
    });
  });
}
