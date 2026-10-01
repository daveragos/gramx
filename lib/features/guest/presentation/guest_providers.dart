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

/// Whether the user is browsing without a Telegram account. Being signed in
/// overrides a leftover guest-mode flag.
final isGuestModeProvider = Provider<bool>((ref) {
  final signedIn = ref.watch(
    authControllerProvider.select(
      (auth) => auth.step == AuthStep.authenticated,
    ),
  );
  if (signedIn) return false;
  return ref.watch(settingsProvider.select((s) => s.guestMode));
});

/// What the user may do. See [ReaderCapabilities].
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

  /// Resolves the typed channel and adds it, so an unreadable channel fails
  /// here. Returns null on success, or a message to show.
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
      // No validators were sent, so this shouldn't happen.
      TmeFetchNotModified() => AppStrings.guestChannelUnreadable(username),
    };
  }

  /// Restores a removed channel at [index] without a new request.
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
            // Only real changes, or watchers would refetch in a loop.
            if (updated != channel) changed = true;
            return updated;
          }()
        else
          channel,
    ];

    if (changed) await _store(next);
  }

  /// Clears the channel list and its cached media.
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

/// The channel usernames as one string, so dependents rebuild when a channel
/// is added or removed but not when a fetch writes back an ETag.
///
/// A plain `Provider` of `AsyncValue`, since a recomputed `FutureProvider`
/// hands out a new future even when its value is unchanged.
final guestChannelKeysProvider = Provider<AsyncValue<String>>((ref) {
  return ref
      .watch(guestChannelsProvider)
      .whenData((channels) => channels.map((c) => c.username).join(','));
});

/// One page of one channel: the posts on it, and where the next page starts.
@immutable
class GuestChannelFetch {
  final List<Post> posts;

  /// The `before=` value for the next older page, or null at the end.
  final int? olderCursor;

  const GuestChannelFetch(this.posts, {this.olderCursor});
}

/// Fetches and maps one channel's newest page, recording its validators.
/// Throws [GuestFetchException] with a message to show.
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

    // A 304 has no body and nothing is cached, so refetch unconditionally.
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

/// Fetches the page of posts older than [before]. Sends no validators and
/// records none, since the stored ones belong to the newest page.
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
    // A failed older page ends paging without failing the feed.
    _ => const GuestChannelFetch([]),
  };
}

/// One channel's most recent posts, for the channel screen.
final guestChannelPostsProvider = FutureProvider.family<List<Post>, String>((
  ref,
  username,
) async {
  // Watch membership only (see guestChannelKeysProvider).
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

/// The guest feed's posts plus per-channel progress and failures, so the
/// screen can tell "no channels yet" from "every channel failed".
@immutable
class GuestFeed {
  final List<Post> posts;

  /// Channels whose last fetch failed. Empty on a clean feed.
  final List<GuestChannelFailure> failures;

  /// How many channels have answered (successfully or not) out of [total].
  final int answered;
  final int total;

  /// True while a page of older posts is on its way.
  final bool isLoadingMore;

  /// True when every channel has reached the end of its history.
  final bool exhausted;

  /// False until the stored channel list has been read from disk.
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

  /// True when there is nothing to show and nothing still loading.
  bool get isEmpty =>
      ready && posts.isEmpty && failures.isEmpty && answered >= total;

  /// True when every channel failed.
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

/// Every added channel's posts, merged newest first. Channels fill in as
/// they arrive, so one slow channel doesn't hold up the rest.
class GuestFeedNotifier extends AsyncNotifier<GuestFeed> {
  /// Channels fetched at once; `t.me/s/` rate-limits the whole client.
  static const int maxConcurrent = 4;

  /// The current build pass, bumped on build and teardown so stale work can
  /// tell it was superseded. A counter, not a disposed flag, because Riverpod
  /// reuses the notifier but still runs the old build's `onDispose`.
  int _generation = 0;

  /// Posts by id, so a refetched channel replaces its posts in place.
  final Map<String, Post> _posts = {};
  final List<GuestChannelFailure> _failures = [];
  final Set<String> _answered = {};

  /// Each channel's next `before=` cursor and which channels have no more
  /// history. Kept across rebuilds for channels that remain.
  final Map<String, int> _cursors = {};
  final Set<String> _exhausted = {};

  List<GuestChannel> _channels = const [];

  @override
  Future<GuestFeed> build() async {
    final generation = ++_generation;
    ref.onDispose(() => _generation++);

    // Watch membership only (see guestChannelKeysProvider).
    if (!ref.watch(guestChannelKeysProvider).hasValue) {
      // The stored list hasn't loaded yet; that is not the same as empty.
      return const GuestFeed(ready: false);
    }

    final channels = ref.read(guestChannelsProvider).value ?? const [];
    _channels = channels;
    _forgetChannelsNotIn(channels);

    // Per-pass state; posts already on screen are kept.
    _answered.clear();
    _failures.clear();

    if (channels.isEmpty) return GuestFeed.empty;

    // Await the first channel so the feed opens with posts.
    await _fetchChannel(channels.first, generation);
    if (generation != _generation) return GuestFeed.empty;

    final rest = channels.skip(1).toList();
    if (rest.isNotEmpty) _fillRemaining(rest, generation);

    return _snapshot();
  }

  /// Loads one older page (`before=`) from every channel that has more
  /// history, and merges the results.
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
          // A missing or non-advancing cursor means no more history.
          final next = page.olderCursor;
          if (page.posts.isEmpty || next == null || next >= before) {
            _exhausted.add(channel.username);
          } else {
            _cursors[channel.username] = next;
          }
        } catch (e) {
          if (generation != _generation) return;
          // Stop paging this channel; a refresh tries again.
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

  /// Re-fetches only the channels that failed, to spare the rate limit.
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

  /// Fetches the rest with bounded parallelism, publishing after each one.
  /// Not awaited by [build], since `state` must not change during a build.
  void _fillRemaining(List<GuestChannel> channels, int generation) {
    final queue = List<GuestChannel>.from(channels);
    // Computed up front: each `worker()` dequeues synchronously before its
    // first await, so `queue.length` shrinks during the loop.
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
      // Keep an existing cursor; it tracks how far back the user has paged.
      final cursor = page.olderCursor;
      if (cursor != null && !_cursors.containsKey(channel.username)) {
        _cursors[channel.username] = cursor;
      }
      if (cursor == null && !_cursors.containsKey(channel.username)) {
        _exhausted.add(channel.username);
      }
    } on GuestFetchException catch (e) {
      if (generation != _generation) return;
      // Recorded per channel so the screen can name it.
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

  /// Drops state for removed channels. Remaining channels keep their posts
  /// on screen through a refresh.
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

/// A guest fetch failure with a message to show the user.
class GuestFetchException implements Exception {
  final String message;
  const GuestFetchException(this.message);

  @override
  String toString() => message;
}
