import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';

Post post(int messageId, {int chatId = -100500, int minutesAgo = 0}) => Post(
      id: '${chatId}_$messageId',
      chatId: chatId,
      channelId: '$chatId',
      messageId: messageId,
      channelTitle: 'Channel',
      publishedAt:
          DateTime(2026, 8, 23, 12).subtract(Duration(minutes: minutesAgo)),
    );

/// Answers history requests from a script, and records what it was asked for.
class ScriptedRepository implements FeedRepository {
  ScriptedRepository(this.pages);

  /// Reply for each successive call, in order. The last one repeats.
  final List<List<Post>> pages;

  final List<int> requestedFrom = [];
  int calls = 0;

  @override
  Future<List<Post>> fetchChannelPosts(
    int chatId, {
    int fromMessageId = 0,
    int limit = 50,
  }) async {
    requestedFrom.add(fromMessageId);
    final page = pages[calls.clamp(0, pages.length - 1)];
    calls++;
    // A real request is never instant; this is what lets the test hold two
    // callers in flight at once.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return page;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// The channel list layers the merged feed's copy of a post over its own, so
/// the feed has to exist — but not to reach TDLib.
class _EmptyFeed extends FeedNotifier {
  @override
  Future<List<Post>> build() async => const [];
}

ProviderContainer containerWith(
  ScriptedRepository repo, {
  required List<Post> initial,
}) {
  final container = ProviderContainer(overrides: [
    feedRepositoryProvider.overrideWithValue(repo),
    feedPostsProvider.overrideWith(_EmptyFeed.new),
    initialChannelPostsProvider.overrideWith((ref, channelId) async => initial),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('channelPostsProvider', () {
    test('is newest first, whatever order the pages arrived in', () async {
      final repo = ScriptedRepository([[]]);
      final container = containerWith(repo, initial: [
        post(30, minutesAgo: 10),
        post(10, minutesAgo: 90),
        post(20, minutesAgo: 50),
      ]);

      container.listen(channelPostsProvider('c'), (_, _) {});
      await container.read(initialChannelPostsProvider('c').future);

      expect(
        container.read(channelPostsProvider('c')).value!.map((p) => p.messageId),
        [30, 20, 10],
      );
    });
  });

  group('loadMore', () {
    test('pages back from the oldest post, not the last in the list',
        () async {
      final repo = ScriptedRepository([
        [post(5, minutesAgo: 200)]
      ]);
      final container = containerWith(repo, initial: [
        post(30, minutesAgo: 10),
        post(10, minutesAgo: 90),
        post(20, minutesAgo: 50),
      ]);
      container.listen(channelPostsProvider('c'), (_, _) {});
      await container.read(initialChannelPostsProvider('c').future);

      await container.read(olderChannelPostsProvider.notifier).loadMore('c');

      expect(repo.requestedFrom, [10]);
      expect(
        container.read(channelPostsProvider('c')).value!.map((p) => p.messageId),
        [30, 20, 10, 5],
      );
    });

    // The scroll listener fires on every frame near the bottom. Without this
    // guard that is one request per frame, against a rate-limited account.
    test('two overlapping calls make one request', () async {
      final repo = ScriptedRepository([
        [post(5, minutesAgo: 200)]
      ]);
      final container = containerWith(repo, initial: [post(10, minutesAgo: 90)]);
      container.listen(channelPostsProvider('c'), (_, _) {});
      await container.read(initialChannelPostsProvider('c').future);

      final older = container.read(olderChannelPostsProvider.notifier);
      await Future.wait([older.loadMore('c'), older.loadMore('c')]);

      expect(repo.calls, 1);
    });

    test('a page with nothing new ends the paging', () async {
      final repo = ScriptedRepository([
        [post(10, minutesAgo: 90)] // the post we already have
      ]);
      final container = containerWith(repo, initial: [post(10, minutesAgo: 90)]);
      container.listen(channelPostsProvider('c'), (_, _) {});
      await container.read(initialChannelPostsProvider('c').future);

      final older = container.read(olderChannelPostsProvider.notifier);
      expect(await older.loadMore('c'), isFalse);
      expect(older.isExhausted('c'), isTrue);

      // And it stops asking.
      expect(await older.loadMore('c'), isFalse);
      expect(repo.calls, 1);
    });

    test('an empty channel is not paged at all', () async {
      final repo = ScriptedRepository([[]]);
      final container = containerWith(repo, initial: const []);
      container.listen(channelPostsProvider('c'), (_, _) {});
      await container.read(initialChannelPostsProvider('c').future);

      expect(
        await container.read(olderChannelPostsProvider.notifier).loadMore('c'),
        isFalse,
      );
      expect(repo.calls, 0);
    });

    // Refreshing has to start clean, or the pages already loaded stack a
    // second copy of the history under the first.
    test('reset drops the pages and lets paging start again', () async {
      final repo = ScriptedRepository([
        [post(5, minutesAgo: 200)],
        [],
      ]);
      final container = containerWith(repo, initial: [post(10, minutesAgo: 90)]);
      container.listen(channelPostsProvider('c'), (_, _) {});
      await container.read(initialChannelPostsProvider('c').future);

      final older = container.read(olderChannelPostsProvider.notifier);
      await older.loadMore('c');
      expect(container.read(channelPostsProvider('c')).value, hasLength(2));

      older.reset('c');

      expect(container.read(channelPostsProvider('c')).value, hasLength(1));
      expect(older.isExhausted('c'), isFalse);
    });
  });
}
