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
            changed = true;
            return channel.copyWith(
              etag: etag,
              lastModified: lastModified,
              title: title,
              avatarUrl: avatarUrl,
            );
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

/// One channel's most recent posts, mapped into the app's own [Post].
///
/// Auto-disposed and per-channel so a channel the reader is not looking at is
/// not being refetched. The validators recorded on the channel make a refresh
/// of an unchanged channel a 304.
final guestChannelPostsProvider =
    FutureProvider.family<List<Post>, String>((ref, username) async {
  final channels = await ref.watch(guestChannelsProvider.future);
  final matches = channels.where((c) => c.username == username);
  if (matches.isEmpty) return [];
  final channel = matches.first;

  final result = await ref.read(tmePreviewClientProvider).fetchPage(
        username,
        etag: channel.etag,
        lastModified: channel.lastModified,
      );

  switch (result) {
    case TmeFetchSuccess(:final page, :final etag, :final lastModified):
      unawaited(ref.read(guestChannelsProvider.notifier).noteFetched(
            username,
            etag: etag,
            lastModified: lastModified,
            title: page.channel.title,
            avatarUrl: page.channel.avatarUrl,
          ));
      return GuestPostMapper.mapPage(page);

    // Nothing changed since last time. There is no body to parse, and no
    // cached posts to hand back either — this provider is auto-disposed, so a
    // 304 here means the page is unchanged from a copy we no longer hold.
    // Asking again without the validators is one request, and only on the
    // rare path where the reader refreshed something that had not moved.
    case TmeFetchNotModified():
      final fresh =
          await ref.read(tmePreviewClientProvider).fetchPage(username);
      if (fresh is TmeFetchSuccess) return GuestPostMapper.mapPage(fresh.page);
      return [];

    case TmeFetchUnavailable():
      return [];

    case TmeFetchFailure(:final message):
      throw GuestFetchException(message);
  }
});

/// Every added channel's posts, merged newest first.
///
/// The guest feed is plainly chronological. The signed-in feed weaves unread
/// backlog into it, and "unread" is a property of a Telegram account — a guest
/// has none, so there is nothing to weave.
final guestFeedProvider = FutureProvider<List<Post>>((ref) async {
  final channels = await ref.watch(guestChannelsProvider.future);
  if (channels.isEmpty) return [];

  final posts = <Post>[];
  for (final channel in channels) {
    try {
      posts.addAll(await ref.watch(
        guestChannelPostsProvider(channel.username).future,
      ));
    } catch (e) {
      // One unreachable channel costs that channel, not the whole feed.
      debugPrint('[Guest] ${channel.username} failed: $e');
    }
  }

  posts.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  return posts;
});

/// A failure worth showing the reader, as opposed to one worth swallowing.
class GuestFetchException implements Exception {
  final String message;
  const GuestFetchException(this.message);

  @override
  String toString() => message;
}
