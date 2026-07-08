import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/channels/data/channel_repository.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/database/database_provider.dart';

/// Provides the list of all channels (non-hidden).
final channelsProvider = StreamProvider<List<Channel>>((ref) {
  final repo = ref.watch(channelRepositoryProvider);
  return repo.watchChannels();
});

/// Provides a single channel by its database ID.
final channelDetailProvider =
    FutureProvider.family<Channel?, String>((ref, channelId) async {
  final repo = ref.watch(channelRepositoryProvider);
  final id = int.tryParse(channelId);
  if (id == null) return null;
  return repo.getChannelById(id);
});

/// Provides posts for a specific channel.
final channelPostsProvider =
    StreamProvider.family<List<Post>, String>((ref, channelId) {
  final repo = ref.watch(feedRepositoryProvider);
  final id = int.tryParse(channelId);
  if (id == null) return const Stream.empty();
  return repo.watchChannelPosts(id);
});

/// Provides the active authenticated account database record.
final activeAccountProvider = StreamProvider<Account?>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.accounts)..where((a) => a.isActive.equals(true)))
      .watchSingleOrNull();
});
