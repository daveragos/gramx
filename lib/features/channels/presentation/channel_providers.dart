import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/channels/data/channel_repository.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/database/database_provider.dart';

/// Provides the list of all channels (non-hidden).
final channelsProvider = FutureProvider<List<Channel>>((ref) async {
  // Same reasoning as FeedNotifier.build: a pre-auth build returns nothing and
  // must not become the permanent answer.
  ref.watch(authControllerProvider.select((auth) => auth.step));

  final repo = ref.watch(channelRepositoryProvider);
  return repo.getSubscribedChannels();
});

/// Provides a single channel by its chat ID, username, or identifier.
final channelDetailProvider =
    FutureProvider.family<Channel?, String>((ref, channelId) async {
  final repo = ref.watch(channelRepositoryProvider);
  return repo.getChannelByIdentifier(channelId);
});

/// Older posts loaded via pagination for channels (map of channelId to list of posts).
class OlderChannelPostsNotifier extends Notifier<Map<String, List<Post>>> {
  @override
  Map<String, List<Post>> build() => {};

  void addPosts(String channelId, List<Post> older) {
    final current = state[channelId] ?? [];
    state = {...state, channelId: [...current, ...older]};
  }
}

final olderChannelPostsProvider =
    NotifierProvider<OlderChannelPostsNotifier, Map<String, List<Post>>>(
  OlderChannelPostsNotifier.new,
);

/// Fetches initial posts for a specific channel.
final initialChannelPostsProvider =
    FutureProvider.family<List<Post>, String>((ref, channelId) async {
  final feedRepo = ref.watch(feedRepositoryProvider);
  final channelRepo = ref.watch(channelRepositoryProvider);

  final channel = await channelRepo.getChannelByIdentifier(channelId);
  if (channel == null) return [];

  return feedRepo.fetchChannelPosts(channel.chatId);
});

/// Provides posts for a specific channel (with pagination and optimistic update support).
final channelPostsProvider =
    Provider.family<AsyncValue<List<Post>>, String>((ref, channelId) {
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
    return uniqueMap.values.toList();
  });
});

/// Helper function to load more older channel posts on scroll.
Future<void> loadMoreChannelPosts(WidgetRef ref, String channelId) async {
  final current = ref.read(channelPostsProvider(channelId)).value ?? [];
  if (current.isEmpty) return;

  final oldestMessageId = current.last.messageId;
  final chatId = current.first.chatId;

  final repo = ref.read(feedRepositoryProvider);
  final older =
      await repo.fetchChannelPosts(chatId, fromMessageId: oldestMessageId);
  if (older.isNotEmpty) {
    ref
        .read(olderChannelPostsProvider.notifier)
        .addPosts(channelId, older);
  }
}

/// Provides the active authenticated account database record.
final activeAccountProvider = StreamProvider<Account?>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.accounts)..where((a) => a.isActive.equals(true)))
      .watchSingleOrNull();
});
