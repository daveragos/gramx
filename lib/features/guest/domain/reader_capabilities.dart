import 'package:flutter/foundation.dart';

/// What the reader is allowed to do, given how they got in.
///
/// One object, watched wherever a control could write to Telegram. The
/// alternative — `if (isGuest)` at each of twenty call sites — is how a guest
/// ends up with one button that quietly does nothing, which is exactly the
/// class of bug the "every control does something" rule in
/// docs/CONVENTIONS.md exists to prevent.
///
/// A guest has no Telegram account. Not "an account with fewer permissions":
/// there is nothing to write to, nothing to read state against, and no identity
/// to react as. So every capability is off, and the controls that depend on
/// them either disappear or offer to sign in.
@immutable
class ReaderCapabilities {
  /// Can add or remove a reaction on a post.
  final bool canReact;

  /// Can acknowledge posts as read. Off for a guest: read state lives on a
  /// Telegram account and is pushed to every client that account owns.
  final bool canMarkRead;

  /// Can open a discussion thread and post a comment. The preview page does not
  /// carry comments at all, so a guest cannot even see them.
  final bool canComment;

  /// Can bookmark a post.
  final bool canBookmark;

  /// Can join or leave a channel.
  final bool canJoin;

  /// Can forward a post into another chat.
  final bool canForward;

  /// Can search Telegram's servers, as opposed to filtering what is loaded.
  final bool canSearchServerSide;

  /// Can write a post into a channel, group or chat. Off for a guest: there is
  /// no account to post as, and `t.me/s/` is a read-only page.
  final bool canPost;

  /// Can hold a conversation — read a chat list, open a chat, send a message.
  /// Off for a guest for the plainest reason of all: a message needs somebody
  /// to be from, and there is nobody. The Messages tab is hidden rather than
  /// disabled, because a tab that opens onto a refusal is furniture.
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

  /// Guest: reading, and nothing that touches an account.
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

  /// True when the reader has no account behind them at all.
  bool get isGuest => !canReact && !canMarkRead && !canBookmark;
}
