import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/guest/data/guest_channel_store.dart';
import 'package:gramx/features/guest/domain/guest_page.dart';
import 'package:gramx/features/guest/data/tme_preview_client.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';

/// The guest feed merges every added channel, newest first.
///
/// Riverpod calls `onDispose` on a rebuild but keeps the notifier, so a
/// disposed flag would stop later passes after one channel. The tests check
/// that every channel is requested on every pass, not just that posts appear.
void main() {
  // ── Fixtures ───────────────────────────────────────────────────────────────

  GuestChannel channel(String username) => GuestChannel(
    username: username,
    title: 'Channel $username',
    addedAt: DateTime.utc(2026, 1, 1),
  );

  GuestChannelPage page(
    String username, {
    required List<int> seqs,
    int? olderCursor,
  }) => GuestChannelPage(
    channel: GuestChannelInfo(username: username, title: 'Channel $username'),
    posts: [
      for (final seq in seqs)
        GuestPost(
          id: '$username/$seq',
          seq: seq,
          // Higher sequence number, more recent post.
          publishedAt: DateTime.utc(
            2026,
            8,
            25,
          ).subtract(Duration(minutes: 100 - seq)),
          text: '$username #$seq',
        ),
    ],
    olderCursor: olderCursor,
  );

  /// Answers `t.me/s/` from a script and records every request, keyed
  /// `<username>` for the newest page and `<username>|<before>` for history.
  ScriptedTme client(Map<String, GuestChannelPage> pages) => ScriptedTme(pages);

  ProviderContainer containerWith(
    ScriptedTme tme, {
    required List<GuestChannel> channels,
  }) {
    final container = ProviderContainer(
      overrides: [
        guestChannelStoreProvider.overrideWithValue(MemoryStore(channels)),
        tmePreviewClientProvider.overrideWithValue(tme),
      ],
    );
    addTearDown(container.dispose);
    // Keep the feed alive between reads, so rebuilds reuse the same notifier.
    container.listen(guestFeedProvider, (_, _) {});
    return container;
  }

  /// Waits for the fill-in workers, which [GuestFeedNotifier.build] does not
  /// await.
  Future<GuestFeed> settle(ProviderContainer container) async {
    var feed = await container.read(guestFeedProvider.future);
    for (var turn = 0; turn < 200 && feed.isFilling; turn++) {
      await Future<void>.delayed(Duration.zero);
      feed = container.read(guestFeedProvider).value ?? feed;
    }
    return feed;
  }

  List<String> channelsOf(GuestFeed feed) =>
      feed.posts.map((p) => p.channelUsername!).toSet().toList()..sort();

  // ── The merge ──────────────────────────────────────────────────────────────

  group('the merged feed', () {
    test('holds every added channel, newest first', () async {
      final tme = client({
        'alpha': page('alpha', seqs: [30]),
        'bravo': page('bravo', seqs: [20]),
        'delta': page('delta', seqs: [10]),
      });
      final container = containerWith(
        tme,
        channels: [channel('alpha'), channel('bravo'), channel('delta')],
      );

      final feed = await settle(container);

      expect(channelsOf(feed), ['alpha', 'bravo', 'delta']);
      expect(feed.posts.map((p) => p.messageId), [
        30,
        20,
        10,
      ], reason: 'the guest feed is plainly chronological');
      expect(feed.answered, 3);
      expect(feed.total, 3);
    });

    // Adding a channel rebuilds the feed; the second build must fetch them all.
    test('asks every channel again after one is added', () async {
      final tme = client({
        'alpha': page('alpha', seqs: [30]),
        'bravo': page('bravo', seqs: [20]),
        'delta': page('delta', seqs: [10]),
      });
      final container = containerWith(
        tme,
        channels: [channel('alpha'), channel('bravo')],
      );
      await settle(container);

      tme.requested.clear();
      await container.read(guestChannelsProvider.notifier).add('delta');
      final feed = await settle(container);

      expect(
        tme.requested.toSet(),
        containsAll(['alpha', 'bravo', 'delta']),
        reason: 'a rebuild must fetch the whole list, not just its first row',
      );
      expect(channelsOf(feed), ['alpha', 'bravo', 'delta']);
    });

    // Pull-to-refresh rebuilds the existing notifier the same way.
    test('asks every channel again on a refresh', () async {
      final tme = client({
        'alpha': page('alpha', seqs: [30]),
        'bravo': page('bravo', seqs: [20]),
      });
      final container = containerWith(
        tme,
        channels: [channel('alpha'), channel('bravo')],
      );
      await settle(container);

      tme.requested.clear();
      container.invalidate(guestFeedProvider);
      final feed = await settle(container);

      expect(tme.requested.toSet(), {'alpha', 'bravo'});
      expect(channelsOf(feed), ['alpha', 'bravo']);
    });

    test('drops the posts of a channel that was removed', () async {
      final tme = client({
        'alpha': page('alpha', seqs: [30]),
        'bravo': page('bravo', seqs: [20]),
      });
      final container = containerWith(
        tme,
        channels: [channel('alpha'), channel('bravo')],
      );
      await settle(container);

      await container.read(guestChannelsProvider.notifier).remove('bravo');
      final feed = await settle(container);

      expect(channelsOf(feed), ['alpha']);
    });

    test('a post that arrives twice appears once', () async {
      final tme = client({
        'alpha': page('alpha', seqs: [30, 29]),
      });
      final container = containerWith(tme, channels: [channel('alpha')]);
      await settle(container);

      container.invalidate(guestFeedProvider);
      final feed = await settle(container);

      expect(feed.posts.length, 2);
    });
  });

  // ── Failures ───────────────────────────────────────────────────────────────

  group('a channel that will not load', () {
    test('costs that channel, and is named', () async {
      final tme = client({
        'alpha': page('alpha', seqs: [30]),
      })..failing.add('bravo');
      final container = containerWith(
        tme,
        channels: [channel('alpha'), channel('bravo')],
      );

      final feed = await settle(container);

      expect(channelsOf(feed), ['alpha']);
      expect(feed.failures.map((f) => f.username), ['bravo']);
      expect(feed.hasFailedEntirely, isFalse);
    });

    // Someone who has added channels should not see the empty-state text.
    test('is not mistaken for an empty reading list', () async {
      final tme = client({})..failing.addAll({'alpha', 'bravo'});
      final container = containerWith(
        tme,
        channels: [channel('alpha'), channel('bravo')],
      );

      final feed = await settle(container);

      expect(feed.posts, isEmpty);
      expect(feed.hasFailedEntirely, isTrue);
      expect(feed.isEmpty, isFalse);
    });

    test('an empty reading list still reads as empty', () async {
      final container = containerWith(client({}), channels: []);
      final feed = await settle(container);

      expect(feed.isEmpty, isTrue);
      expect(feed.hasFailedEntirely, isFalse);
    });

    // A private or deleted channel is reported, not shown as zero posts.
    test('a channel that has gone private is a failure, not silence', () async {
      final tme = client({
        'alpha': page('alpha', seqs: [30]),
      })..unavailable.add('bravo');
      final container = containerWith(
        tme,
        channels: [channel('alpha'), channel('bravo')],
      );

      final feed = await settle(container);

      expect(feed.failures.single.username, 'bravo');
      expect(feed.failures.single.message, contains('private'));
    });

    test('retrying asks only the channels that failed', () async {
      final tme = client({
        'alpha': page('alpha', seqs: [30]),
      })..failing.add('bravo');
      final container = containerWith(
        tme,
        channels: [channel('alpha'), channel('bravo')],
      );
      await settle(container);

      tme.failing.clear();
      tme.pages['bravo'] = page('bravo', seqs: [20]);
      tme.requested.clear();

      await container.read(guestFeedProvider.notifier).retryFailed();
      final feed = await settle(container);

      expect(tme.requested, ['bravo'], reason: 'a is already on screen');
      expect(channelsOf(feed), ['alpha', 'bravo']);
      expect(feed.failures, isEmpty);
    });
  });

  // ── Paging ─────────────────────────────────────────────────────────────────

  group('loadMore', () {
    ProviderContainer pagedContainer(ScriptedTme tme) =>
        containerWith(tme, channels: [channel('alpha'), channel('bravo')]);

    test('pages every channel that has history left', () async {
      final tme = client({
        'alpha': page('alpha', seqs: [30, 29], olderCursor: 29),
        'alpha|29': page('alpha', seqs: [28, 27], olderCursor: 27),
        // No cursor: this channel has nothing older to give.
        'bravo': page('bravo', seqs: [20]),
      });
      final container = pagedContainer(tme);
      await settle(container);

      tme.requested.clear();
      await container.read(guestFeedProvider.notifier).loadMore();
      final feed = container.read(guestFeedProvider).value!;

      expect(tme.requested, [
        'alpha|29',
      ], reason: 'b has no cursor to page from');
      expect(feed.posts.map((p) => p.messageId), [30, 29, 28, 27, 20]);
      expect(feed.isLoadingMore, isFalse);
    });

    test('stops once every channel has run out', () async {
      final tme = client({
        'alpha': page('alpha', seqs: [30], olderCursor: 30),
        'alpha|30': page('alpha', seqs: []),
        'bravo': page('bravo', seqs: [20]),
      });
      final container = pagedContainer(tme);
      await settle(container);

      await container.read(guestFeedProvider.notifier).loadMore();
      expect(container.read(guestFeedProvider).value!.exhausted, isTrue);

      tme.requested.clear();
      await container.read(guestFeedProvider.notifier).loadMore();
      expect(tme.requested, isEmpty, reason: 'an exhausted feed stops asking');
    });

    // The scroll listener fires every frame near the bottom and t.me
    // rate-limits the client, so a call while one is in flight sends nothing.
    test('two overlapping calls make one pass', () async {
      final tme = client({
        'alpha': page('alpha', seqs: [30], olderCursor: 30),
        'alpha|30': page('alpha', seqs: [29], olderCursor: 29),
        'bravo': page('bravo', seqs: [20]),
      });
      final container = pagedContainer(tme);
      await settle(container);

      tme.requested.clear();
      final notifier = container.read(guestFeedProvider.notifier);
      await Future.wait([notifier.loadMore(), notifier.loadMore()]);

      expect(tme.requested, ['alpha|30']);
    });

    // A refresh's cursor points at pages already loaded; it must not win.
    test(
      'a refresh does not rewind how far back the reader has paged',
      () async {
        final tme = client({
          'alpha': page('alpha', seqs: [30, 29], olderCursor: 29),
          'alpha|29': page('alpha', seqs: [28], olderCursor: 28),
          'alpha|28': page('alpha', seqs: [27], olderCursor: 27),
          'bravo': page('bravo', seqs: [20]),
        });
        final container = pagedContainer(tme);
        await settle(container);
        await container.read(guestFeedProvider.notifier).loadMore();

        container.invalidate(guestFeedProvider);
        await settle(container);

        tme.requested.clear();
        await container.read(guestFeedProvider.notifier).loadMore();

        expect(tme.requested, ['alpha|28']);
      },
    );
  });
}

/// A [TmePreviewClient] that answers from a map instead of the network.
class ScriptedTme extends TmePreviewClient {
  ScriptedTme(this.pages);

  /// `<username>` for the newest page, `<username>|<before>` for history.
  final Map<String, GuestChannelPage> pages;

  final List<String> requested = [];

  /// Usernames that answer with a transport failure.
  final Set<String> failing = {};

  /// Usernames that answer as private, deleted, or not a public preview.
  final Set<String> unavailable = {};

  @override
  Future<TmeFetchResult> fetchPage(
    String username, {
    int? before,
    String? etag,
    String? lastModified,
  }) async {
    final key = before == null ? username : '$username|$before';
    requested.add(key);
    // Yield, so the fill-in workers interleave as they would on a network.
    await Future<void>.delayed(Duration.zero);

    if (failing.contains(username)) {
      return const TmeFetchFailure('Could not reach Telegram');
    }
    if (unavailable.contains(username)) return const TmeFetchUnavailable();

    final page = pages[key];
    if (page == null) {
      // No scripted history: an exhausted `before=` page.
      if (before != null) {
        return TmeFetchSuccess(
          GuestChannelPage(
            channel: GuestChannelInfo(username: username, title: username),
            posts: const [],
          ),
        );
      }
      return const TmeFetchUnavailable();
    }
    return TmeFetchSuccess(page, etag: 'W/"$key"');
  }
}

/// The channel list, without a file behind it.
class MemoryStore extends GuestChannelStore {
  MemoryStore(this._channels);

  List<GuestChannel> _channels;

  @override
  Future<List<GuestChannel>> load() async => _channels;

  @override
  Future<void> save(List<GuestChannel> channels) async => _channels = channels;

  @override
  Future<void> clear() async => _channels = [];
}
