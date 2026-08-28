import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/guest/data/guest_channel_store.dart';
import 'package:gramx/features/guest/domain/guest_page.dart';
import 'package:gramx/features/guest/data/tme_preview_client.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';

/// The guest feed is supposed to be every added channel, merged newest first.
///
/// It was one channel: the last one added, alone. `GuestFeedNotifier` guarded
/// its parallel fetch with a `bool _disposed` set from `ref.onDispose`, and
/// Riverpod fires that on a *rebuild* while keeping the notifier instance — so
/// the flag latched true the first time the channel list changed and every
/// later pass fetched `channels.first` and stopped. Channels are stored newest
/// first, which is why what survived was the most recently added one.
///
/// The regression check is not "the feed has posts from three channels" —
/// posts now survive a refresh, so that would pass on the broken code too. It
/// is that every channel is *asked for* on every pass.
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
          // Higher sequence number, more recent post — the ordering the
          // merge is supposed to produce.
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

  /// Answers `t.me/s/` from a script, and records everything it was asked.
  ///
  /// Keyed `<username>` for the newest page and `<username>|<before>` for a
  /// page of history, which is exactly the distinction the client draws.
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
    // The feed must stay alive between reads: without a listener Riverpod
    // disposes it and the next read builds a fresh notifier, which is the one
    // arrangement in which the bug under test cannot happen.
    container.listen(guestFeedProvider, (_, _) {});
    return container;
  }

  /// Waits for the fill-in workers, which [GuestFeedNotifier.build] starts and
  /// deliberately does not await.
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

    // The regression. Adding a channel rebuilds the feed, and it is the second
    // build that used to stop after one channel.
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

    // The same latch, reached the other way: pull-to-refresh invalidates the
    // provider, which rebuilds the notifier that is already there.
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

    // What the reader used to be shown here was "Nothing here yet — add a
    // public channel", to someone who had added two.
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

    // A private or deleted channel used to come back as zero posts, which on
    // screen is indistinguishable from a channel that never posts.
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

    // The scroll listener fires on every frame near the bottom, and `t.me/s/`
    // rate-limits the whole client — so a second call while one is in flight
    // must not become a second request.
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

    // A refresh re-fetches the newest page, whose cursor points back at ground
    // the reader has already scrolled past. Letting it win would re-page it.
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
    // A real request is never instant, and the fill-in workers only interleave
    // if this yields.
    await Future<void>.delayed(Duration.zero);

    if (failing.contains(username)) {
      return const TmeFetchFailure('Could not reach Telegram');
    }
    if (unavailable.contains(username)) return const TmeFetchUnavailable();

    final page = pages[key];
    if (page == null) {
      // No scripted history means the channel has none, which is what an
      // exhausted `before=` page looks like.
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
