import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/database/database_provider.dart';

/// Repository for feed/post operations backed by Drift.
class FeedRepository {
  final AppDatabase db;

  FeedRepository(this.db);

  /// Watch all posts sorted by publishedAt desc, joined with channel data.
  Stream<List<Post>> watchFeedPosts() {
    final query = (db.select(db.posts)
          ..where((p) => p.isDeleted.equals(false))
          ..orderBy([
            (p) => OrderingTerm.desc(p.publishedAt),
          ]))
        .join([
      innerJoin(
        db.channels,
        db.channels.id.equalsExp(db.posts.channelId),
      ),
    ]);

    return query.watch().asyncMap((rows) async {
      final posts = <Post>[];
      for (final row in rows) {
        final postEntry = row.readTable(db.posts);
        final channelEntry = row.readTable(db.channels);

        // Fetch media items for this post
        final mediaEntries = await (db.select(db.mediaItems)
              ..where((m) => m.postId.equals(postEntry.id))
              ..orderBy([(m) => OrderingTerm.asc(m.sortOrder)]))
            .get();

        posts.add(_mapToPost(postEntry, channelEntry, mediaEntries));
      }
      return posts;
    });
  }

  /// Watch posts for a specific channel.
  Stream<List<Post>> watchChannelPosts(int channelDbId) {
    final query = (db.select(db.posts)
          ..where((p) =>
              p.channelId.equals(channelDbId) & p.isDeleted.equals(false))
          ..orderBy([(p) => OrderingTerm.desc(p.publishedAt)]))
        .join([
      innerJoin(
        db.channels,
        db.channels.id.equalsExp(db.posts.channelId),
      ),
    ]);

    return query.watch().asyncMap((rows) async {
      final posts = <Post>[];
      for (final row in rows) {
        final postEntry = row.readTable(db.posts);
        final channelEntry = row.readTable(db.channels);

        final mediaEntries = await (db.select(db.mediaItems)
              ..where((m) => m.postId.equals(postEntry.id))
              ..orderBy([(m) => OrderingTerm.asc(m.sortOrder)]))
            .get();

        posts.add(_mapToPost(postEntry, channelEntry, mediaEntries));
      }
      return posts;
    });
  }

  /// Get a single post by its database ID.
  Future<Post?> getPostById(int postDbId) async {
    final query = (db.select(db.posts)
          ..where((p) => p.id.equals(postDbId)))
        .join([
      innerJoin(
        db.channels,
        db.channels.id.equalsExp(db.posts.channelId),
      ),
    ]);

    final rows = await query.get();
    if (rows.isEmpty) return null;

    final row = rows.first;
    final postEntry = row.readTable(db.posts);
    final channelEntry = row.readTable(db.channels);

    final mediaEntries = await (db.select(db.mediaItems)
          ..where((m) => m.postId.equals(postEntry.id))
          ..orderBy([(m) => OrderingTerm.asc(m.sortOrder)]))
        .get();

    return _mapToPost(postEntry, channelEntry, mediaEntries);
  }

  /// Toggle bookmark on a post.
  Future<void> toggleBookmark(int postDbId) async {
    final post = await (db.select(db.posts)
          ..where((p) => p.id.equals(postDbId)))
        .getSingleOrNull();
    if (post == null) return;

    await (db.update(db.posts)..where((p) => p.id.equals(postDbId)))
        .write(PostsCompanion(isBookmarked: Value(!post.isBookmarked)));
  }

  Post _mapToPost(
    PostEntry postEntry,
    ChannelEntry channelEntry,
    List<MediaItemEntry> mediaEntries,
  ) {
    Map<String, int> reactions = {};
    try {
      final decoded = jsonDecode(postEntry.reactionsJson);
      if (decoded is Map) {
        reactions = decoded.map((k, v) => MapEntry(k.toString(), v as int));
      }
    } catch (_) {}

    return Post(
      id: postEntry.id.toString(),
      channelId: channelEntry.id.toString(),
      messageId: postEntry.messageId,
      channelTitle: channelEntry.title,
      channelUsername: channelEntry.username,
      channelAvatarUrl: channelEntry.avatarUrl,
      channelAvatarColor: channelEntry.avatarColor,
      isChannelVerified: channelEntry.isVerified,
      text: postEntry.body,
      media: mediaEntries.map(_mapMediaItem).toList(),
      publishedAt: postEntry.publishedAt,
      viewCount: postEntry.viewCount,
      replyCount: postEntry.replyCount,
      forwardCount: postEntry.forwardCount,
      reactions: reactions,
      isBookmarked: postEntry.isBookmarked,
      isRead: postEntry.isRead,
      linkPreviewUrl: postEntry.linkPreviewUrl,
      linkPreviewTitle: postEntry.linkPreviewTitle,
      linkPreviewDescription: postEntry.linkPreviewDescription,
      linkPreviewImageUrl: postEntry.linkPreviewImageUrl,
      forwardedFromTitle: postEntry.forwardedFromTitle,
      forwardedFromUsername: postEntry.forwardedFromUsername,
    );
  }

  MediaItem _mapMediaItem(MediaItemEntry entry) {
    return MediaItem(
      id: entry.id.toString(),
      type: MediaType.values.firstWhere(
        (t) => t.name == entry.type,
        orElse: () => MediaType.photo,
      ),
      url: entry.url,
      thumbnailUrl: entry.thumbnailUrl,
      width: entry.width,
      height: entry.height,
      duration: entry.duration,
      fileSize: entry.fileSize,
      fileName: entry.fileName,
      mimeType: entry.mimeType,
      localPath: entry.localPath,
    );
  }
}

/// Riverpod provider for FeedRepository.
final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(ref.watch(databaseProvider));
});
