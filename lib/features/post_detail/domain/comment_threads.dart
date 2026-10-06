import 'package:gramx/features/feed/domain/post.dart';

/// A top-level comment and every reply beneath it, at any depth.
class CommentThread {
  final Post root;

  /// Oldest first, so a chain of replies reads top to bottom.
  final List<Post> replies;

  const CommentThread(this.root, this.replies);
}

/// Groups a post's comments into threads, the way X lays out a conversation.
///
/// Top-level comments come newest first, like X's "Recent". The replies under
/// each come oldest first, so they read as the conversation happened. A reply
/// whose parent isn't loaded counts as top-level.
List<CommentThread> threadComments(List<Post> comments) {
  final byId = {for (final c in comments) c.messageId: c};

  // The top-level comment [comment] descends from. A loop of replies has no
  // top, so its oldest member stands in, the same one from anywhere in it.
  int rootOf(Post comment) {
    var current = comment;
    final seen = {comment.messageId};
    while (true) {
      final parent = byId[current.replyToMessageId];
      if (parent == null) return current.messageId;
      if (!seen.add(parent.messageId)) {
        return seen.reduce((a, b) => a < b ? a : b);
      }
      current = parent;
    }
  }

  final replies = <int, List<Post>>{};
  final roots = <Post>[];
  for (final comment in comments) {
    final root = rootOf(comment);
    if (root == comment.messageId) {
      roots.add(comment);
    } else {
      replies.putIfAbsent(root, () => []).add(comment);
    }
  }

  // Ids rise with time within the discussion group.
  roots.sort((a, b) => b.messageId.compareTo(a.messageId));
  return [
    for (final root in roots)
      CommentThread(
        root,
        (replies[root.messageId] ?? [])
          ..sort((a, b) => a.messageId.compareTo(b.messageId)),
      ),
  ];
}

/// Whom [reply] should say it is replying to, or null when it follows its
/// parent directly, where the thread line already says so.
Post? replyingToLabel(Post reply, Post shownAbove, List<Post> comments) {
  final parentId = reply.replyToMessageId;
  if (parentId == null || parentId == shownAbove.messageId) return null;
  for (final c in comments) {
    if (c.messageId == parentId) return c;
  }
  return null;
}
