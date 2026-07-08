import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/database/database_provider.dart';

/// Repository for channel operations backed by Drift.
class ChannelRepository {
  final AppDatabase db;

  ChannelRepository(this.db);

  /// Watch all non-hidden channels sorted by lastPostAt desc.
  Stream<List<Channel>> watchChannels() {
    final query = db.select(db.channels)
      ..where((c) => c.isHidden.equals(false))
      ..orderBy([(c) => OrderingTerm.desc(c.lastPostAt)]);

    return query.watch().map((rows) => rows.map(_mapToChannel).toList());
  }

  /// Get a channel by its database ID.
  Future<Channel?> getChannelById(int channelDbId) async {
    final entry = await (db.select(db.channels)
          ..where((c) => c.id.equals(channelDbId)))
        .getSingleOrNull();
    if (entry == null) return null;
    return _mapToChannel(entry);
  }

  /// Toggle favorite status.
  Future<void> toggleFavorite(int channelDbId) async {
    final channel = await (db.select(db.channels)
          ..where((c) => c.id.equals(channelDbId)))
        .getSingleOrNull();
    if (channel == null) return;

    await (db.update(db.channels)..where((c) => c.id.equals(channelDbId)))
        .write(ChannelsCompanion(isFavorite: Value(!channel.isFavorite)));
  }

  /// Toggle muted status.
  Future<void> toggleMuted(int channelDbId) async {
    final channel = await (db.select(db.channels)
          ..where((c) => c.id.equals(channelDbId)))
        .getSingleOrNull();
    if (channel == null) return;

    await (db.update(db.channels)..where((c) => c.id.equals(channelDbId)))
        .write(ChannelsCompanion(isMuted: Value(!channel.isMuted)));
  }

  Channel _mapToChannel(ChannelEntry entry) {
    return Channel(
      id: entry.id.toString(),
      chatId: entry.chatId,
      title: entry.title,
      username: entry.username,
      description: entry.description,
      avatarUrl: entry.avatarUrl,
      avatarColor: entry.avatarColor,
      subscriberCount: entry.subscriberCount,
      isVerified: entry.isVerified,
      isFavorite: entry.isFavorite,
      isMuted: entry.isMuted,
      isHidden: entry.isHidden,
      lastPostAt: entry.lastPostAt,
    );
  }
}

/// Riverpod provider for ChannelRepository.
final channelRepositoryProvider = Provider<ChannelRepository>((ref) {
  return ChannelRepository(ref.watch(databaseProvider));
});
