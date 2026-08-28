import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/guest/data/guest_channel_store.dart';
import 'package:gramx/features/guest/data/guest_media_cache.dart';
import 'package:gramx/features/guest/data/guest_post_mapper.dart';
import 'package:gramx/features/guest/data/tme_preview_client.dart';
import 'package:gramx/features/guest/domain/reader_capabilities.dart';
import 'package:gramx/features/settings/data/settings_store.dart';

/// Whether the reader is browsing without a Telegram account.
///
/// Signing in wins: someone who has an account is not a guest even if the flag
/// is still set from before, and leaving the flag to decide would show them a
/// scraped feed instead of their own.
final isGuestModeProvider = Provider<bool>((ref) {
  final signedIn = ref.watch(
    authControllerProvider.select(
      (auth) => auth.step == AuthStep.authenticated,
    ),
  );
  if (signedIn) return false;
  return ref.watch(settingsProvider.select((s) => s.guestMode));
});

/// What the reader may do. Watched by every control that could write to
/// Telegram — see [ReaderCapabilities] for why it is one object.
final readerCapabilitiesProvider = Provider<ReaderCapabilities>((ref) {
  return ref.watch(isGuestModeProvider)
      ? ReaderCapabilities.guest
      : ReaderCapabilities.signedIn;
});

/// The public channels a guest has added, newest first.
class GuestChannelsNotifier extends AsyncNotifier<List<GuestChannel>> {
  @override
  Future<List<GuestChannel>> build() async {
    return ref.read(guestChannelStoreProvider).load();
  }

  /// Resolves what the reader typed, then adds it.
  ///
  /// Returns null on success, or a reason to show them. Resolving before
  /// adding is the point: a channel that cannot be read is a row that would
  /// sit in their list doing nothing, and finding that out at add time is
  /// better than finding it out as a permanently empty feed.
  Future<String?> add(String input) async {
    final username = TmePreviewClient.parseUsername(input);
    if (username == null) return AppStrings.guestNotAUsername;

    final existing = state.value ?? [];
    if (existing.any(
      (c) => c.username.toLowerCase() == username.toLowerCase(),
    )) {
      return AppStrings.guestAlreadyAdded(username);
    }

    final result = await ref.read(tmePreviewClientProvider).fetchPage(username);
    return switch (result) {
      TmeFetchSuccess(:final page, :final etag, :final lastModified) =>
        await _store([
          GuestChannel(
            username: page.channel.username,
            title: page.channel.title,
            avatarUrl: page.channel.avatarUrl,
            subscribers: page.channel.subscribers,
            isVerified: page.channel.isVerified,
            addedAt: DateTime.now(),
            etag: etag,
            lastModified: lastModified,
          ),
          ...existing,
        ]),
      TmeFetchUnavailable() => AppStrings.guestChannelNotPublic(username),
      TmeFetchFailure(:final message) => message,
      // Nothing was sent, so nothing can have been unchanged.
      TmeFetchNotModified() => AppStrings.guestChannelUnreadable(username),
    };
  }

  /// Puts a removed channel back where it was.
  ///
  /// Undo restores the row itself — validators included — rather than
  /// re-resolving the username, so taking back a mistap costs no request and
  /// cannot fail differently from the original add.
  Future<void> restore(GuestChannel channel, int index) async {
    final existing = state.value ?? [];
    if (existing.any((c) => c.username == channel.username)) return;
    final at = index.clamp(0, existing.length);
    await _store([...existing]..insert(at, channel));
  }

  Future<void> remove(String username) async {
    final existing = state.value ?? [];
    await _store(existing.where((c) => c.username != username).toList());
  }

  /// Records the validators from a fetch, so the next one can be a 304.
  Future<void> noteFetched(
    String username, {
    String? etag,
    String? lastModified,
    String? title,
    String? avatarUrl,
  }) async {
    final existing = state.value ?? [];
    var changed = false;

    final next = [
      for (final channel in existing)
        if (channel.username == username)
          () {
            final updated = channel.copyWith(
              etag: etag,
              lastModified: lastModified,
              title: title,
              avatarUrl: avatarUrl,
            );
            // Only when something is genuinely different. Writing an identical
            // row still publishes new state, and anything watching this list
            // would refetch, write the same validators again, and go round —
            // which is precisely the loop that made the guest feed spin.
            if (updated != channel) changed = true;
            return updated;
          }()
        else
          channel,
    ];

    if (changed) await _store(next);
  }

  /// Forgets everything: the list, and the media cached for it.
  ///
  /// Leaving someone's browsing behind on disk after they have left guest mode
  /// is not something they asked for.
  Future<void> clear() async {
    await ref.read(guestChannelStoreProvider).clear();
    await ref.read(guestMediaCacheProvider).clear();
    state = const AsyncData([]);
  }

  Future<String?> _store(List<GuestChannel> channels) async {
    await ref.read(guestChannelStoreProvider).save(channels);
    state = AsyncData(channels);
    return null;
  }
}

final guestChannelsProvider =
    AsyncNotifierProvider<GuestChannelsNotifier, List<GuestChannel>>(
      GuestChannelsNotifier.new,
    );

/// Which channels are in the list, as one comparable value.
///
/// The feed must rebuild when a channel is added or removed, and must *not*
/// rebuild when a row is merely rewritten — fetching a page records its ETag
/// back onto the row, so a feed that depended on the rows themselves refetched
/// every time it finished fetching. That is an infinite loop pointed at
/// Telegram, and it is what "the home page just kept loading" was.
///
/// A `String` rather than the list: Riverpod skips notifying dependents when
/// the new value equals the old one, and two lists with the same contents are
/// not `==` while two equal strings are.
///
/// **A plain `Provider`, and an `AsyncValue` rather than a `Future`.** It was a
/// `FutureProvider`, which dependents could only reach by watching its
/// `.future` — and a recomputed `FutureProvider` hands out a *new* future
/// whether or not its value changed, so every ETag written back after a fetch
/// still restarted the feed. That no longer ran forever, because the second
/// pass wrote identical validators and stopped, but it did mean every channel
/// was fetched exactly twice on every cold start, against an endpoint that
/// rate-limits the whole client. `AsyncValue` compares by value, so an
/// unchanged list is now genuinely no news.
final guestChannelKeysProvider = Provider<AsyncValue<String>>((ref) {
  return ref
      .watch(guestChannelsProvider)
      .whenData((channels) => channels.map((c) => c.username).join(','));
});

/// One page of one channel: the posts on it, and where the next page starts.
@immutable
class GuestChannelFetch {
  final List<Post> posts;

  /// Pass back as `before=` for the page above this one in age. Null when the
  /// channel has nothing older.
  final int? olderCursor;

  const GuestChannelFetch(this.posts, {this.olderCursor});
}

/// Fetches and maps one channel's newest page, recording its validators.
///
/// Shared by the per-channel provider and the merged feed so the 304 handling
/// exists once. Throws [GuestFetchException] for anything the reader should be
/// told about — including a channel that has gone private, which used to be
/// swallowed as an empty result and read on screen as a channel that simply
/// never posts.
Future<GuestChannelFetch> fetchGuestChannelPage(
  Ref ref,
  GuestChannel channel,
) async {
  final client = ref.read(tmePreviewClientProvider);
  final result = await client.fetchPage(
    channel.username,
    etag: channel.etag,
    lastModified: channel.lastModified,
  );

  switch (result) {
    case TmeFetchSuccess(:final page, :final etag, :final lastModified):
      unawaited(
        ref
            .read(guestChannelsProvider.notifier)
            .noteFetched(
              channel.username,
              etag: etag,
              lastModified: lastModified,
              title: page.channel.title,
              avatarUrl: page.channel.avatarUrl,
            ),
      );
      return GuestChannelFetch(
        GuestPostMapper.mapPage(page),
        olderCursor: page.olderCursor,
      );

    // Nothing changed since last time. There is no body to parse, and no
    // cached posts to hand back either — so ask once more without the
    // validators. One extra request, only when a refresh found nothing new.
    case TmeFetchNotModified():
      final fresh = await client.fetchPage(channel.username);
      if (fresh is TmeFetchSuccess) {
        return GuestChannelFetch(
          GuestPostMapper.mapPage(fresh.page),
          olderCursor: fresh.page.olderCursor,
        );
      }
      throw GuestFetchException(
        AppStrings.guestChannelUnreadable(channel.username),
      );

    case TmeFetchUnavailable():
      throw GuestFetchException(
        AppStrings.guestChannelNotPublic(channel.username),
      );

    case TmeFetchFailure(:final message):
      throw GuestFetchException(message);
  }
}

/// Fetches the page of posts older than [before].
///
/// Deliberately unconditional: the validators stored on a channel belong to its
/// *newest* page, and sending them with a `before=` request would compare the
/// wrong two documents. Nothing is recorded back for the same reason.
Future<GuestChannelFetch> fetchGuestOlderPage(
  Ref ref,
  String username, {
  required int before,
}) async {
  final result = await ref
      .read(tmePreviewClientProvider)
      .fetchPage(username, before: before);

  return switch (result) {
    TmeFetchSuccess(:final page) => GuestChannelFetch(
      GuestPostMapper.mapPage(page),
      olderCursor: page.olderCursor,
    ),
    // A page that will not load is the end of what we can show, not an error
    // worth taking the feed down for — the reader already has everything above
    // it on screen.
    _ => const GuestChannelFetch([]),
  };
}

/// One channel's most recent posts, for the channel screen.
final guestChannelPostsProvider = FutureProvider.family<List<Post>, String>((
  ref,
  username,
) async {
  // Membership only, for the reason in guestChannelKeysProvider: this fetch
  // records validators back onto the channel row, and watching the rows would
  // make it restart itself.
  if (!ref.watch(guestChannelKeysProvider).hasValue) return const [];

  final channels = ref.read(guestChannelsProvider).value ?? const [];
  final matches = channels.where((c) => c.username == username);
  if (matches.isEmpty) return [];
  return (await fetchGuestChannelPage(ref, matches.first)).posts;
});

/// A channel the guest feed could not read, and why.
@immutable
class GuestChannelFailure {
  final String username;
  final String message;

  const GuestChannelFailure(this.username, this.message);

  @override
  bool operator ==(Object other) =>
      other is GuestChannelFailure &&
      other.username == username &&
      other.message == message;

  @override
  int get hashCode => Object.hash(username, message);
}

/// The guest feed, and everything the screen needs to be honest about it.
///
/// One value rather than a bare `List<Post>` plus side channels: a guest feed
/// is assembled from several independent fetches, any of which can fail on its
/// own, and a screen that only receives the posts cannot tell "no channels
/// yet" from "all four channels failed" — which is why a failed refresh used
/// to show the reader an invitation to add the channels they had already
/// added.
@immutable
class GuestFeed {
  final List<Post> posts;

  /// Channels whose last fetch failed. Empty on a clean feed.
  final List<GuestChannelFailure> failures;

  /// How many channels have answered — successfully or not — out of [total].
  final int answered;
  final int total;

  /// True while a page of older posts is on its way.
  final bool isLoadingMore;

  /// True when every channel has reached the end of its history.
  final bool exhausted;

  /// False until the stored channel list has been read from disk. Nothing
  /// about a feed is knowable before then — least of all whether it is empty.
  final bool ready;

  const GuestFeed({
    this.posts = const [],
    this.failures = const [],
    this.answered = 0,
    this.total = 0,
    this.isLoadingMore = false,
    this.exhausted = false,
    this.ready = true,
  });

  static const empty = GuestFeed();

  /// True while channels are still being fetched for this pass.
  bool get isFilling => !ready || answered < total;

  /// True when there is nothing to show and nothing left that could produce
  /// something — the only case in which "add a channel" is the right thing to
  /// say.
  bool get isEmpty =>
      ready && posts.isEmpty && failures.isEmpty && answered >= total;

  /// True when every channel failed, so the screen owes the reader a reason
  /// rather than an empty page.
  bool get hasFailedEntirely =>
      posts.isEmpty && failures.isNotEmpty && !isFilling;

  @override
  bool operator ==(Object other) =>
      other is GuestFeed &&
      listEquals(other.posts, posts) &&
      listEquals(other.failures, failures) &&
      other.answered == answered &&
      other.total == total &&
      other.isLoadingMore == isLoadingMore &&
      other.exhausted == exhausted &&
      other.ready == ready;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(posts),
    Object.hashAll(failures),
    answered,
    total,
    isLoadingMore,
    exhausted,
    ready,
  );
}

/// Every added channel's posts, merged newest first, arriving as they land.
///
/// The guest feed is plainly chronological. The signed-in feed weaves unread
/// backlog into it, and "unread" is a property of a Telegram account — a guest
/// has none, so there is nothing to weave.
///
/// **Why this is a notifier and not a `FutureProvider` over the whole list.**
/// It was the latter, awaiting every channel in a `for` loop before returning
/// anything, and that is exactly as slow as it sounds: each `t.me/s/` fetch is
/// its own request with a 15-second timeout, so three channels on a bad
/// connection was three quarters of a minute of spinner with nothing behind
/// it. Worse, one slow channel held up every channel that had already
/// answered. Now the first page to arrive is painted, and the rest fill in
/// underneath it — the same shape as the signed-in feed's backfill.
class GuestFeedNotifier extends AsyncNotifier<GuestFeed> {
  /// How many channels are fetched at once.
  ///
  /// Bounded rather than unlimited: `t.me/s/` is one rate-limit bucket for the
  /// whole client (see [TmePreviewClient]), and firing twenty requests at it
  /// earns a 429 that costs more than the parallelism saved.
  static const int maxConcurrent = 4;

  /// Which pass of this feed is current.
  ///
  /// Bumped when a build starts and again when one is torn down, so work
  /// started under an earlier pass can see that it has been superseded and
  /// drop what it collected instead of writing it into the new feed.
  ///
  /// **This replaces a `bool _disposed`, and that flag is the bug.** Riverpod
  /// keeps the notifier instance across a rebuild *and* fires the previous
  /// build's `onDispose` callbacks, so the flag latched true the first time a
  /// channel was added and never went back — from then on every build fetched
  /// `channels.first` and its workers exited immediately, because they test
  /// that flag. Channels are stored newest first, so what the reader saw was
  /// the last channel they added, alone, with the rest of their list missing.
  int _generation = 0;

  /// Posts by id, so a channel refetched at the top of the feed replaces its
  /// own rows rather than doubling them.
  final Map<String, Post> _posts = {};
  final List<GuestChannelFailure> _failures = [];
  final Set<String> _answered = {};

  /// Where each channel's next `before=` page starts, and which channels have
  /// run out of history. Survive a rebuild for channels that survive it, so a
  /// refresh does not re-page ground the reader has already scrolled past.
  final Map<String, int> _cursors = {};
  final Set<String> _exhausted = {};

  List<GuestChannel> _channels = const [];

  @override
  Future<GuestFeed> build() async {
    final generation = ++_generation;
    ref.onDispose(() => _generation++);

    // Membership only — see guestChannelKeysProvider. The rows themselves are
    // read, not watched, so recording an ETag onto one does not restart this.
    if (!ref.watch(guestChannelKeysProvider).hasValue) {
      // The stored list has not come off disk yet. Saying so is not the same
      // as saying the reader has no channels, which is what an empty feed
      // would have the screen announce.
      return const GuestFeed(ready: false);
    }

    final channels = ref.read(guestChannelsProvider).value ?? const [];
    _channels = channels;
    _forgetChannelsNotIn(channels);

    // Both describe *this* pass rather than the feed's contents: a refresh
    // re-asks every channel, so who has answered and who failed start over
    // while the posts already on screen stay where they are.
    _answered.clear();
    _failures.clear();

    if (channels.isEmpty) return GuestFeed.empty;

    // The first channel is awaited so the feed opens with real posts rather
    // than an empty state it would have to take back a second later. Posts
    // already on screen are kept meanwhile, so a pull-to-refresh does not
    // collapse the list to one channel and grow it back.
    await _fetchChannel(channels.first, generation);
    if (generation != _generation) return GuestFeed.empty;

    final rest = channels.skip(1).toList();
    if (rest.isNotEmpty) _fillRemaining(rest, generation);

    return _snapshot();
  }

  /// Loads the next page of older posts from every channel that has one.
  ///
  /// The guest feed used to be one page per channel and nothing beneath it —
  /// roughly twenty posts, after which scrolling simply stopped. `t.me/s/`
  /// pages backwards with `before=`, so there is history to give; this asks
  /// every unexhausted channel for one page and merges the answers.
  Future<void> loadMore() async {
    final generation = _generation;
    final current = state.value;
    if (current == null || current.isLoadingMore) return;

    final pending = _channels
        .where((c) => !_exhausted.contains(c.username))
        .where((c) => _cursors.containsKey(c.username))
        .toList();
    if (pending.isEmpty) return;

    state = AsyncData(_snapshot(isLoadingMore: true));

    final queue = List<GuestChannel>.from(pending);

    Future<void> worker() async {
      while (queue.isNotEmpty && generation == _generation) {
        final channel = queue.removeAt(0);
        final before = _cursors[channel.username];
        if (before == null) continue;

        try {
          final page = await fetchGuestOlderPage(
            ref,
            channel.username,
            before: before,
          );
          if (generation != _generation) return;

          for (final post in page.posts) {
            _posts[post.id] = post;
          }
          // No cursor, or a cursor that has stopped moving, both mean the same
          // thing: there is nothing further back to ask for.
          final next = page.olderCursor;
          if (page.posts.isEmpty || next == null || next >= before) {
            _exhausted.add(channel.username);
          } else {
            _cursors[channel.username] = next;
          }
        } catch (e) {
          if (generation != _generation) return;
          // A page that will not load costs that page. The reader keeps
          // everything above it, and pulling to refresh tries again.
          debugPrint('[Guest] paging ${channel.username} failed: $e');
          _exhausted.add(channel.username);
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < math.min(maxConcurrent, queue.length); i++) worker(),
    ]);

    if (generation != _generation) return;
    state = AsyncData(_snapshot());
  }

  /// Re-fetches only the channels that failed, keeping the ones that worked.
  ///
  /// Retrying the whole feed would spend a request on every channel that
  /// already answered, against a service that rate-limits the client as a
  /// whole — so the retry is scoped to what actually needs it.
  Future<void> retryFailed() async {
    final generation = _generation;
    final failed = _failures.map((f) => f.username).toSet();
    if (failed.isEmpty) return;

    final targets = _channels
        .where((c) => failed.contains(c.username))
        .toList();
    if (targets.isEmpty) return;

    _failures.clear();
    _answered.removeAll(failed);
    state = AsyncData(_snapshot());

    await _fetchChannel(targets.first, generation);
    if (generation != _generation) return;
    state = AsyncData(_snapshot());

    final rest = targets.skip(1).toList();
    if (rest.isNotEmpty) _fillRemaining(rest, generation);
  }

  /// Fetches the rest in bounded parallel, publishing after each one.
  ///
  /// Not awaited by [build]: every one of these starts with a real request, so
  /// by the time any of them writes `state` the build has long returned — a
  /// provider must not be modified while it is building.
  void _fillRemaining(List<GuestChannel> channels, int generation) {
    final queue = List<GuestChannel>.from(channels);
    // Fixed before the loop starts: each `worker()` runs synchronously up to
    // its first await, so reading `queue.length` inside the condition sees a
    // queue that has already shrunk and starts one worker too few.
    final workers = math.min(maxConcurrent, queue.length);

    Future<void> worker() async {
      while (queue.isNotEmpty && generation == _generation) {
        await _fetchChannel(queue.removeAt(0), generation);
        if (generation != _generation) return;
        state = AsyncData(_snapshot());
      }
    }

    for (var i = 0; i < workers; i++) {
      worker();
    }
  }

  Future<void> _fetchChannel(GuestChannel channel, int generation) async {
    try {
      final page = await fetchGuestChannelPage(ref, channel);
      if (generation != _generation) return;

      for (final post in page.posts) {
        _posts[post.id] = post;
      }
      // Only when this channel has no cursor yet. The stored cursor tracks how
      // far back the reader has paged; the newest page's cursor is above that,
      // and letting it win would re-fetch pages already on screen.
      final cursor = page.olderCursor;
      if (cursor != null && !_cursors.containsKey(channel.username)) {
        _cursors[channel.username] = cursor;
      }
      if (cursor == null && !_cursors.containsKey(channel.username)) {
        _exhausted.add(channel.username);
      }
    } on GuestFetchException catch (e) {
      if (generation != _generation) return;
      // One unreachable channel costs that channel, not the whole feed — but
      // it is recorded rather than swallowed, so the screen can say which.
      _failures.add(GuestChannelFailure(channel.username, e.message));
    } catch (e) {
      if (generation != _generation) return;
      debugPrint('[Guest] ${channel.username} failed: $e');
      _failures.add(
        GuestChannelFailure(
          channel.username,
          AppStrings.guestChannelUnreadable(channel.username),
        ),
      );
    } finally {
      if (generation == _generation) _answered.add(channel.username);
    }
  }

  /// Drops everything belonging to channels the reader has removed.
  ///
  /// Kept for the ones that remain, which is what makes a refresh feel like a
  /// refresh: the posts stay on screen and are replaced in place as each
  /// channel answers.
  void _forgetChannelsNotIn(List<GuestChannel> channels) {
    final names = channels.map((c) => c.username).toSet();
    final chatIds = names.map(GuestPostMapper.syntheticChatId).toSet();

    _posts.removeWhere((_, post) => !chatIds.contains(post.chatId));
    _cursors.removeWhere((name, _) => !names.contains(name));
    _exhausted.removeWhere((name) => !names.contains(name));
  }

  GuestFeed _snapshot({bool isLoadingMore = false}) {
    final posts = _posts.values.toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return GuestFeed(
      posts: posts,
      failures: List.unmodifiable(_failures),
      answered: _answered.length,
      total: _channels.length,
      isLoadingMore: isLoadingMore,
      exhausted:
          _channels.isNotEmpty &&
          _channels.every((c) => _exhausted.contains(c.username)),
    );
  }
}

final guestFeedProvider = AsyncNotifierProvider<GuestFeedNotifier, GuestFeed>(
  GuestFeedNotifier.new,
);

/// A failure worth showing the reader, as opposed to one worth swallowing.
class GuestFetchException implements Exception {
  final String message;
  const GuestFetchException(this.message);

  @override
  String toString() => message;
}
