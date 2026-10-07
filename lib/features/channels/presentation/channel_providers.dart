import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/core/diagnostics/startup_trace.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/channels/data/channel_media_repository.dart';
import 'package:gramx/features/channels/data/channel_repository.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/channels/presentation/channel_tab_providers.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/guest/data/tme_page_parser.dart';
import 'package:gramx/features/guest/data/guest_channel_store.dart';
import 'package:gramx/features/guest/data/guest_post_mapper.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/database/database_provider.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';

/// All subscribed channels, excluding hidden ones.
final channelsProvider = FutureProvider<List<Channel>>((ref) async {
  // Rebuild after sign-in, so an empty pre-auth result isn't kept.
  ref.watch(authControllerProvider.select((auth) => auth.step));
  // And once the chat cache, briefly empty after sign-in, has channels.
  ref.watch(channelsKnownProvider);

  final repo = ref.watch(channelRepositoryProvider);
  final channels = await repo.getSubscribedChannels();
  if (channels.isNotEmpty) {
    StartupTrace.mark('channels resolved (${channels.length})');
  }
  return channels;
});

/// One channel by chat id, username or other identifier.
final channelDetailProvider = FutureProvider.family<Channel?, String>((
  ref,
  channelId,
) async {
  // Guest channels are not in TDLib, so they are looked up locally first.
  final guest = await _guestChannel(ref, channelId);
  if (guest != null) return guest;

  final repo = ref.watch(channelRepositoryProvider);
  return repo.getChannelByIdentifier(channelId);
});

/// The guest channel behind a synthetic id, or null for any other id.
Future<Channel?> _guestChannel(Ref ref, String channelId) async {
  final chatId = int.tryParse(channelId);
  if (chatId == null || !GuestPostMapper.isSynthetic(chatId)) return null;

  final channels = await ref.watch(guestChannelsProvider.future);
  for (final channel in channels) {
    if (GuestPostMapper.syntheticChatId(channel.username) != chatId) continue;
    return guestChannelToChannel(channel);
  }
  return null;
}

/// A stored guest channel as a [Channel], for both detail lookup and search.
Channel guestChannelToChannel(GuestChannel channel) {
  final chatId = GuestPostMapper.syntheticChatId(channel.username);
  return Channel(
    id: chatId.toString(),
    chatId: chatId,
    title: channel.title,
    username: channel.username,
    avatarUrl: channel.avatarUrl,
    subscriberCount: TmePageParser.parseCount(channel.subscribers ?? '') ?? 0,
    isVerified: channel.isVerified,
    // A guest can't join; the Join button opens a sign-in sheet.
    isJoined: false,
  );
}

/// Older posts paged in per channel. Tracks in-flight and exhausted channels,
/// since the scroll listener asks on every frame near the bottom.
class OlderChannelPostsNotifier extends Notifier<Map<String, List<Post>>> {
  final Set<String> _loading = {};
  final Set<String> _exhausted = {};

  @override
  Map<String, List<Post>> build() => {};

  bool isLoading(String channelId) => _loading.contains(channelId);

  /// Whether the channel has run out of older posts.
  bool isExhausted(String channelId) => _exhausted.contains(channelId);

  /// Loads the next page. Returns true if anything new arrived.
  Future<bool> loadMore(String channelId) async {
    if (_loading.contains(channelId) || _exhausted.contains(channelId)) {
      return false;
    }

    // Read the sources directly: channelPostsProvider watches this notifier,
    // so reading it here would be a dependency cycle.
    final current = [
      ...?ref.read(initialChannelPostsProvider(channelId)).value,
      ...?state[channelId],
    ];
    if (current.isEmpty) return false;

    // By message id, since the merged list's order isn't guaranteed.
    final oldest = current.reduce((a, b) => a.messageId <= b.messageId ? a : b);

    _loading.add(channelId);
    try {
      final older = _isGuestChannel(oldest)
          ? await _guestOlderPosts(ref, oldest)
          : await ref
                .read(feedRepositoryProvider)
                .fetchChannelPosts(
                  oldest.chatId,
                  fromMessageId: oldest.messageId,
                );

      final known = current.map((p) => p.id).toSet();
      final additions = older.where((p) => !known.contains(p.id)).toList();
      if (additions.isEmpty) {
        _exhausted.add(channelId);
        return false;
      }

      state = {
        ...state,
        channelId: [...?state[channelId], ...additions],
      };
      return true;
    } catch (e) {
      debugPrint('[Channel] Loading more posts failed: $e');
      return false;
    } finally {
      _loading.remove(channelId);
    }
  }

  /// Drops a channel's paged posts, so a refresh doesn't duplicate them.
  void reset(String channelId) {
    _loading.remove(channelId);
    _exhausted.remove(channelId);
    if (!state.containsKey(channelId)) return;
    final next = Map<String, List<Post>>.from(state)..remove(channelId);
    state = next;
  }
}

final olderChannelPostsProvider =
    NotifierProvider<OlderChannelPostsNotifier, Map<String, List<Post>>>(
      OlderChannelPostsNotifier.new,
    );

/// Whether this post's channel pages through `t.me/s/` rather than TDLib,
/// which needs both a synthetic id and a username.
bool _isGuestChannel(Post post) =>
    post.channelUsername != null && GuestPostMapper.isSynthetic(post.chatId);

/// Older posts for a guest channel, paged through `t.me/s/<name>?before=`.
Future<List<Post>> _guestOlderPosts(Ref ref, Post oldest) async {
  final page = await fetchGuestOlderPage(
    ref,
    oldest.channelUsername!,
    before: oldest.messageId,
  );
  return page.posts;
}

/// The first page of a channel's posts.
final initialChannelPostsProvider = FutureProvider.family<List<Post>, String>((
  ref,
  channelId,
) async {
  final chatId = int.tryParse(channelId);
  if (chatId != null && GuestPostMapper.isSynthetic(chatId)) {
    final guest = await _guestChannel(ref, channelId);
    if (guest?.username == null) return [];
    return ref.watch(guestChannelPostsProvider(guest!.username!).future);
  }

  final feedRepo = ref.watch(feedRepositoryProvider);
  final channelRepo = ref.watch(channelRepositoryProvider);

  final channel = await channelRepo.getChannelByIdentifier(channelId);
  if (channel == null) return [];

  return feedRepo.fetchChannelPosts(channel.chatId);
});

/// A channel's posts, with paged history and optimistic updates merged in.
final channelPostsProvider = Provider.family<AsyncValue<List<Post>>, String>((
  ref,
  channelId,
) {
  final initialAsync = ref.watch(initialChannelPostsProvider(channelId));
  final olderPostsMap = ref.watch(olderChannelPostsProvider);
  final feedPosts = ref.watch(feedPostsProvider).value ?? [];
  final feedMap = {for (final p in feedPosts) p.id: p};
  final overrides = ref.watch(optimisticPostUpdatesProvider);

  return initialAsync.whenData((initialPosts) {
    final olderPosts = olderPostsMap[channelId] ?? [];
    final merged = [...initialPosts, ...olderPosts];
    final uniqueMap = <String, Post>{};
    for (final post in merged) {
      final base = feedMap[post.id] ?? post;
      uniqueMap[post.id] = applyPostOverrides(base, overrides);
    }
    final posts = uniqueMap.values.toList()
      // Newest first, whatever order the pages arrived in.
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return posts;
  });
});

/// The channel's newest pinned post, or null. Re-checked on each visit.
final channelPinnedPostProvider = FutureProvider.family<Post?, String>((
  ref,
  channelId,
) async {
  final channel = await ref.watch(channelDetailProvider(channelId).future);
  if (channel == null) return null;
  return ref
      .watch(channelMediaRepositoryProvider)
      .fetchPinnedPost(channel.chatId);
});

/// Reloads a channel's details, history and tabs from scratch.
Future<void> refreshChannel(WidgetRef ref, String channelId) async {
  ref.read(olderChannelPostsProvider.notifier).reset(channelId);
  // Tabs are cached per channel and would otherwise be duplicated.
  ref.read(channelTabNotifierProvider.notifier).reset(channelId);
  ref.invalidate(channelDetailProvider(channelId));
  ref.invalidate(channelPinnedPostProvider(channelId));
  ref.invalidate(initialChannelPostsProvider(channelId));
  await ref.read(initialChannelPostsProvider(channelId).future);
}

/// The signed-in account's database row.
final activeAccountProvider = StreamProvider<Account?>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.accounts,
  )..where((a) => a.isActive.equals(true))).watchSingleOrNull();
});

/// Channels Telegram suggests, for the Explore view. Kept alive so switching
/// back to the Search tab doesn't cost another request.
/// The channels Telegram finds like a channel, by chat id.
final similarChannelsProvider = FutureProvider.family<List<Channel>, int>((
  ref,
  chatId,
) {
  return ref.watch(channelRepositoryProvider).similarChannels(chatId);
}, isAutoDispose: true);

/// How many channels Telegram finds like a channel, by chat id.
final similarChannelCountProvider = FutureProvider.family<int, int>((
  ref,
  chatId,
) {
  return ref.watch(channelRepositoryProvider).similarChannelCount(chatId);
}, isAutoDispose: true);

final recommendedChannelsProvider = FutureProvider<List<Channel>>((ref) async {
  ref.keepAlive();
  return ref.watch(channelRepositoryProvider).recommendedChannels();
});
