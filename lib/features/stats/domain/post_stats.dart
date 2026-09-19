import 'package:gramx/features/stats/domain/stat_graph.dart';

/// What `getMessageStatistics` says about one post.
///
/// Two graphs and nothing else — Telegram does not repeat the post's own view
/// and share counts here, because the message already carries them. The screen
/// draws those from the post it was opened on.
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

/// A public channel that forwarded this post, and what the forward earned.
///
/// repost list, and it counts only *public* forwards, because a forward into a
/// private chat is nobody's business but theirs.
///
/// Deliberately flat rather than holding a `Channel`: a stats model importing
/// another feature's domain is the cross-feature import the conventions rule
/// out, and only these fields are ever drawn.
class PublicShare {
  final int chatId;
  final int messageId;
  final String title;
  final String? username;
  final String? avatarPath;
  final int? avatarFileId;
  final bool isVerified;

  /// Views the *forwarded copy* collected, not the original's.
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
