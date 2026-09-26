import 'package:flutter/foundation.dart';

/// What kind of place a post is going to.
///
/// Ordering, not decoration: gramX is a channel reader, so the channels a
/// writer actually runs belong at the top of the picker, and the person they
/// last messaged does not. The icon each one wears follows from this too.
enum ComposeTargetKind {
  /// A broadcast channel this account may post to — creator or an admin with
  /// posting rights.
  channel,

  /// A group this account may write in.
  group,

  /// The account's own cloud storage. Always available, which is what keeps
  /// the compose button from being dead for a reader who runs no channel.
  savedMessages,

  /// A one-to-one chat.
  direct,
}

/// One destination in the compose picker.
///
/// A flattened view of a `td.Chat`, so the picker and the pill don't each
/// re-derive the same three facts from TDLib's object.
@immutable
class ComposeTarget {
  final int chatId;
  final String title;
  final ComposeTargetKind kind;

  /// Where the chat photo already sits on disk, if TDLib has fetched it.
  final String? avatarPath;

  /// TDLib's file id for that photo, so the avatar can fetch it if it hasn't.
  final int? avatarFileId;

  /// Sort order within TDLib's main chat list — the recency the picker keeps
  /// inside each [kind].
  final int mainListOrder;

  /// Whether Telegram will take a poll here.
  ///
  /// Carried on the target rather than asked for when the toolbar is drawn:
  /// the answer needs the chat *and* its supergroup, which is a cache lookup,
  /// and `build()` is not allowed to reach for one. Decided once, where the
  /// list is built. Narrower than "can post here" — polls are their own group
  /// permission, and a private chat with a person never takes one.
  final bool allowsPolls;

  const ComposeTarget({
    required this.chatId,
    required this.title,
    required this.kind,
    this.avatarPath,
    this.avatarFileId,
    this.mainListOrder = 0,
    this.allowsPolls = false,
  });

  @override
  bool operator ==(Object other) =>
      other is ComposeTarget &&
      other.chatId == chatId &&
      other.title == title &&
      other.kind == kind &&
      other.avatarPath == avatarPath &&
      other.avatarFileId == avatarFileId &&
      other.mainListOrder == mainListOrder &&
      other.allowsPolls == allowsPolls;

  @override
  int get hashCode => Object.hash(
    chatId,
    title,
    kind,
    avatarPath,
    avatarFileId,
    mainListOrder,
    allowsPolls,
  );

  @override
  String toString() => 'ComposeTarget($title, ${kind.name})';
}
