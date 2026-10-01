import 'package:flutter/foundation.dart';

/// What the user can do, given how they signed in. Watched by every control
/// that writes to Telegram. A guest has no account, so every capability is
/// off and those controls are hidden or prompt to sign in.
@immutable
class ReaderCapabilities {
  /// Can add or remove a reaction on a post.
  final bool canReact;

  /// Can acknowledge posts as read.
  final bool canMarkRead;

  /// Can open a discussion thread and post a comment. The guest preview page
  /// has no comments.
  final bool canComment;

  /// Can bookmark a post.
  final bool canBookmark;

  /// Can join or leave a channel.
  final bool canJoin;

  /// Can forward a post into another chat.
  final bool canForward;

  /// Can search Telegram's servers, as opposed to filtering what is loaded.
  final bool canSearchServerSide;

  /// Can write a post into a channel, group or chat.
  final bool canPost;

  /// Can use chats: read the chat list, open a chat, send a message. When
  /// off, the Messages tab is hidden.
  final bool canMessage;

  const ReaderCapabilities({
    required this.canReact,
    required this.canMarkRead,
    required this.canComment,
    required this.canBookmark,
    required this.canJoin,
    required this.canForward,
    required this.canSearchServerSide,
    required this.canPost,
    required this.canMessage,
  });

  /// Signed in: everything.
  static const signedIn = ReaderCapabilities(
    canReact: true,
    canMarkRead: true,
    canComment: true,
    canBookmark: true,
    canJoin: true,
    canForward: true,
    canSearchServerSide: true,
    canPost: true,
    canMessage: true,
  );

  /// Guest: reading only.
  static const guest = ReaderCapabilities(
    canReact: false,
    canMarkRead: false,
    canComment: false,
    canBookmark: false,
    canJoin: false,
    canForward: false,
    canSearchServerSide: false,
    canPost: false,
    canMessage: false,
  );

  /// True when there is no signed-in account.
  bool get isGuest => !canReact && !canMarkRead && !canBookmark;
}
