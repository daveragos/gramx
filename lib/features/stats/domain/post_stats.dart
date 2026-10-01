import 'package:gramx/features/stats/domain/stat_graph.dart';

/// One post's graphs from `getMessageStatistics`. The view and share counts
/// come from the message itself.
class PostStats {
  /// Views and shares over the days since the post went out.
  final StatGraphSource interactionGraph;

  /// Reactions over the same window.
  final StatGraphSource reactionGraph;

  const PostStats({
    required this.interactionGraph,
    required this.reactionGraph,
  });
}

/// A public channel that forwarded a post, with the forward's views.
///
/// Flat rather than holding a `Channel`, to avoid a cross-feature import.
class PublicShare {
  final int chatId;
  final int messageId;
  final String title;
  final String? username;
  final String? avatarPath;
  final int? avatarFileId;
  final bool isVerified;

  /// Views on the forwarded copy, not the original.
  final int viewCount;

  const PublicShare({
    required this.chatId,
    required this.messageId,
    required this.title,
    this.username,
    this.avatarPath,
    this.avatarFileId,
    this.isVerified = false,
    this.viewCount = 0,
  });
}
