import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/features/guest/data/guest_channel_store.dart';
import 'package:gramx/features/guest/data/guest_post_mapper.dart';
import 'package:gramx/features/channels/data/channel_media_repository.dart';
import 'package:gramx/features/channels/data/channel_repository.dart';
import 'package:gramx/features/channels/presentation/channel_tab_providers.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/database/database_provider.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';

/// Provides the list of all channels (non-hidden).
final channelsProvider = FutureProvider<List<Channel>>((ref) async {
  // Same reasoning as FeedNotifier.build: a pre-auth build returns nothing and
  // must not become the permanent answer.
  ref.watch(authControllerProvider.select((auth) => auth.step));
  // And when the chat cache first has a channel to report: this list is drawn
  // from that cache, which is empty for a moment after signing in.
  ref.watch(channelsKnownProvider);

  final repo = ref.watch(channelRepositoryProvider);
  return repo.getSubscribedChannels();
});

/// Provides a single channel by its chat ID, username, or identifier.
final channelDetailProvider = FutureProvider.family<Channel?, String>((
  ref,
  channelId,
) async {
  // Guest channels are not in TDLib, so the repository could only ever answer
  // null for one — which the profile screen showed as "channel unavailable"
  // for a channel the reader had added themselves.
  final guest = await _guestChannel(ref, channelId);
  if (guest != null) return guest;

  final repo = ref.watch(channelRepositoryProvider);
  return repo.getChannelByIdentifier(channelId);
});

/// The guest row behind a synthetic channel id, mapped to the shared [Channel].
///
/// Returns null for anything that is not a guest channel, so the TDLib path
/// stays exactly as it was for a signed-in reader.
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

/// A stored guest row as the app's own [Channel].
///
/// Shared by the detail lookup and by search, so a guest channel presents
/// itself the same way wherever it is shown.
Channel guestChannelToChannel(GuestChannel channel) {
  final chatId = GuestPostMapper.syntheticChatId(channel.username);
  return Channel(
    id: chatId.toString(),
    chatId: chatId,
    title: channel.title,
    username: channel.username,
    avatarUrl: channel.avatarUrl,
    subscriberCount:
        int.tryParse(
          (channel.subscribers ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0,
    isVerified: channel.isVerified,
    // A guest cannot join anything, and a Join button that opens a sign-in
    // sheet is honest where a "Joined" badge would not be.
    isJoined: false,
  );
}

/// Older posts loaded by paging back through a channel, keyed by channel id.
///
/// Owns the in-flight and exhausted flags too: the profile screen asks for
/// another page from a scroll listener, which fires on every frame near the
/// bottom. Without a guard that is a request per frame, aimed at an account
/// with a rate limit.
class OlderChannelPostsNotifier extends Notifier<Map<String, List<Post>>> {
  final Set<String> _loading = {};
  final Set<String> _exhausted = {};

  @override
  Map<String, List<Post>> build() => {};

  bool isLoading(String channelId) => _loading.contains(channelId);

  /// True once the channel has answered a page request with nothing new, so
  /// the screen can stop asking and say it has reached the end.
  bool isExhausted(String channelId) => _exhausted.contains(channelId);

  /// Loads the next page. Returns true if anything new arrived.
  Future<bool> loadMore(String channelId) async {
    if (_loading.contains(channelId) || _exhausted.contains(channelId)) {
      return false;
    }

    // Read the sources, not the derived provider: channelPostsProvider watches
    // this notifier, so asking it here is a dependency cycle — Riverpod throws
    // on it, and the screen's paging died with the first scroll.
    final current = [
      ...?ref.read(initialChannelPostsProvider(channelId)).value,
      ...?state[channelId],
    ];
    if (current.isEmpty) return false;

    // The oldest post, not the last one in the list: the list is merged from
    // two sources and de-duplicated, so its order is not a promise.
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

  /// Drops everything paged in for a channel, so a refresh starts clean
  /// instead of stacking a second copy of the history under the first.
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

/// Whether paging this post's channel means asking `t.me/s/` rather than TDLib.
///
/// Both halves are required, not just the synthetic id: `isSynthetic` is a
/// range test, and the username is what the request is actually made of. A post
/// with no username cannot be paged from the web preview at all, so it belongs
/// on the TDLib path whatever its id looks like.
bool _isGuestChannel(Post post) =>
    post.channelUsername != null && GuestPostMapper.isSynthetic(post.chatId);

/// Older posts for a guest channel, paged through `t.me/s/<name>?before=`.
///
/// A guest channel has no TDLib chat behind it, so the repository call this
/// stands in for could only ever answer nothing — scrolling to the bottom of a
/// guest channel just stopped, with the rest of its history one request away.
Future<List<Post>> _guestOlderPosts(Ref ref, Post oldest) async {
  final page = await fetchGuestOlderPage(
    ref,
    oldest.channelUsername!,
    before: oldest.messageId,
  );
  return page.posts;
}

/// Fetches initial posts for a specific channel.
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

/// Provides posts for a specific channel (with pagination and optimistic update support).
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

/// The channel's newest pinned post, or null if it has none.
///
/// One `GetChatPinnedMessage` per channel opened. Auto-disposed like every
/// other family member here, so backing out and returning re-asks — which is
/// correct: a pin can change, and one request on a deliberate navigation is
/// well inside the budget.
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

/// Reloads a channel from scratch — its details, its history and every tab.
Future<void> refreshChannel(WidgetRef ref, String channelId) async {
  ref.read(olderChannelPostsProvider.notifier).reset(channelId);
  // Tabs are cached per (channel, tab) and would otherwise stack a second copy
  // of each one under the first.
  ref.read(channelTabNotifierProvider.notifier).reset(channelId);
  ref.invalidate(channelDetailProvider(channelId));
  ref.invalidate(channelPinnedPostProvider(channelId));
  ref.invalidate(initialChannelPostsProvider(channelId));
  await ref.read(initialChannelPostsProvider(channelId).future);
}

/// Provides the active authenticated account database record.
final activeAccountProvider = StreamProvider<Account?>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.accounts,
  )..where((a) => a.isActive.equals(true))).watchSingleOrNull();
});
