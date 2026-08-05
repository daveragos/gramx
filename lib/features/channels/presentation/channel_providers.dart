import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/channels/data/channel_repository.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/database/database_provider.dart';

/// Provides the list of all channels (non-hidden).
final channelsProvider = FutureProvider<List<Channel>>((ref) async {
  final repo = ref.watch(channelRepositoryProvider);
  return repo.getSubscribedChannels();
});

/// Provides a single channel by its chat ID.
final channelDetailProvider =
    FutureProvider.family<Channel?, String>((ref, channelId) async {
  final repo = ref.watch(channelRepositoryProvider);
  final id = int.tryParse(channelId);
  if (id == null) return null;
  return repo.getChannelByChatId(id);
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

/// Provides posts for a specific channel (with pagination support).
final channelPostsProvider =
    FutureProvider.family<List<Post>, String>((ref, channelId) async {
  final repo = ref.watch(feedRepositoryProvider);
  final id = int.tryParse(channelId);
  if (id == null) return [];
  final initialPosts = await repo.fetchChannelPosts(id);
  final olderPostsMap = ref.watch(olderChannelPostsProvider);
  final olderPosts = olderPostsMap[channelId] ?? [];

  final merged = [...initialPosts, ...olderPosts];
  final uniqueMap = <String, Post>{};
  for (final post in merged) {
    uniqueMap[post.id] = post;
  }
  return uniqueMap.values.toList();
});

/// Helper function to load more older channel posts on scroll.
Future<void> loadMoreChannelPosts(WidgetRef ref, String channelId) async {
  final current = ref.read(channelPostsProvider(channelId)).value ?? [];
  if (current.isEmpty) return;

  final oldestMessageId = current.last.messageId;
  final chatId = int.tryParse(channelId);
  if (chatId == null) return;

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
