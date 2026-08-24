import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    authControllerProvider.select((auth) => auth.step == AuthStep.authenticated),
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
    if (username == null) return 'That is not a Telegram channel username.';

    final existing = state.value ?? [];
    if (existing.any((c) => c.username.toLowerCase() == username.toLowerCase())) {
      return 'You have already added @$username.';
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
      TmeFetchUnavailable() =>
        '@$username is private, or does not exist. Guest mode can only read '
            'public channels.',
      TmeFetchFailure(:final message) => message,
      // Nothing was sent, so nothing can have been unchanged.
      TmeFetchNotModified() => 'Could not read @$username.',
    };
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
final guestChannelKeysProvider = FutureProvider<String>((ref) async {
  final channels = await ref.watch(guestChannelsProvider.future);
  return channels.map((c) => c.username).join(',');
});

/// Fetches and maps one channel's page, recording its validators.
///
/// Shared by the per-channel provider and the merged feed so the 304 handling
/// exists once. Throws [GuestFetchException] for a failure worth showing.
Future<List<Post>> fetchGuestChannelPosts(Ref ref, GuestChannel channel) async {
  final client = ref.read(tmePreviewClientProvider);
  final result = await client.fetchPage(
    channel.username,
    etag: channel.etag,
    lastModified: channel.lastModified,
  );

  switch (result) {
    case TmeFetchSuccess(:final page, :final etag, :final lastModified):
      unawaited(ref.read(guestChannelsProvider.notifier).noteFetched(
            channel.username,
            etag: etag,
            lastModified: lastModified,
            title: page.channel.title,
            avatarUrl: page.channel.avatarUrl,
          ));
      return GuestPostMapper.mapPage(page);

    // Nothing changed since last time. There is no body to parse, and no
    // cached posts to hand back either — so ask once more without the
    // validators. One extra request, only when a refresh found nothing new.
    case TmeFetchNotModified():
      final fresh = await client.fetchPage(channel.username);
      if (fresh is TmeFetchSuccess) return GuestPostMapper.mapPage(fresh.page);
      return [];

    case TmeFetchUnavailable():
      return [];

    case TmeFetchFailure(:final message):
      throw GuestFetchException(message);
  }
}

/// One channel's most recent posts, for the channel screen.
final guestChannelPostsProvider =
    FutureProvider.family<List<Post>, String>((ref, username) async {
  await ref.watch(guestChannelKeysProvider.future);
  final channels = ref.read(guestChannelsProvider).value ?? const [];
  final matches = channels.where((c) => c.username == username);
  if (matches.isEmpty) return [];
  return fetchGuestChannelPosts(ref, matches.first);
});

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
class GuestFeedNotifier extends AsyncNotifier<List<Post>> {
  /// How many channels are fetched at once.
  ///
  /// Bounded rather than unlimited: `t.me/s/` is one rate-limit bucket for the
  /// whole client (see [TmePreviewClient]), and firing twenty requests at it
  /// earns a 429 that costs more than the parallelism saved.
  static const int maxConcurrent = 4;

  bool _disposed = false;
  final List<Post> _collected = [];

  @override
  Future<List<Post>> build() async {
    ref.onDispose(() => _disposed = true);

    // Membership only — see guestChannelKeysProvider. The rows themselves are
    // read, not watched, so recording an ETag onto one does not restart this.
    await ref.watch(guestChannelKeysProvider.future);
    final channels = ref.read(guestChannelsProvider).value ?? const [];

    _collected.clear();
    if (channels.isEmpty) return [];

    // The first channel is awaited so the feed opens with real posts rather
    // than an empty state it would have to take back a second later.
    await _fetchInto(channels.first);

    final rest = channels.skip(1).toList();
    if (rest.isNotEmpty) _fillRemaining(rest);

    return _snapshot();
  }

  /// Fetches the rest in bounded parallel, publishing after each one.
  ///
  /// Not awaited by [build]: every one of these starts with a real request, so
  /// by the time any of them writes `state` the build has long returned — a
  /// provider must not be modified while it is building.
  void _fillRemaining(List<GuestChannel> channels) {
    final queue = List<GuestChannel>.from(channels);

    Future<void> worker() async {
      while (queue.isNotEmpty && !_disposed) {
        await _fetchInto(queue.removeAt(0));
        if (_disposed) return;
        state = AsyncData(_snapshot());
      }
    }

    for (var i = 0; i < maxConcurrent && i < queue.length; i++) {
      worker();
    }
  }

  Future<void> _fetchInto(GuestChannel channel) async {
    try {
      _collected.addAll(await fetchGuestChannelPosts(ref, channel));
    } catch (e) {
      // One unreachable channel costs that channel, not the whole feed.
      debugPrint('[Guest] ${channel.username} failed: $e');
    }
  }

  List<Post> _snapshot() {
    final posts = List<Post>.from(_collected)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return posts;
  }
}

final guestFeedProvider =
    AsyncNotifierProvider<GuestFeedNotifier, List<Post>>(GuestFeedNotifier.new);

/// A failure worth showing the reader, as opposed to one worth swallowing.
class GuestFetchException implements Exception {
  final String message;
  const GuestFetchException(this.message);

  @override
  String toString() => message;
}
