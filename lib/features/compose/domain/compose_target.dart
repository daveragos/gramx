import 'package:flutter/foundation.dart';

/// What kind of place a post is going to. Also sets the order in the picker,
/// with channels first.
enum ComposeTargetKind {
  /// A broadcast channel this account may post to.
  channel,

  /// A group this account may write in.
  group,

  /// The account's own cloud storage. Always available, so the compose button
  /// works for an account with no channel.
  savedMessages,

  /// A one-to-one chat.
  direct,
}

/// One destination in the compose picker, flattened from a `td.Chat`.
@immutable
class ComposeTarget {
  final int chatId;
  final String title;
  final ComposeTargetKind kind;

  /// Where the chat photo already sits on disk, if TDLib has fetched it.
  final String? avatarPath;

  /// TDLib's file id for that photo, so the avatar can fetch it if it hasn't.
  final int? avatarFileId;

  /// Position in TDLib's main chat list, used to sort within each [kind].
  final int mainListOrder;

  /// Whether Telegram accepts a poll here. Worked out when the list is built,
  /// since it needs the supergroup from the cache, which `build()` can't read.
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
