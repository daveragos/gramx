import 'package:flutter/foundation.dart';

/// Who actually wrote a message, when that is not the chat it arrived in.
///
/// A channel post *is* its channel, so the feed needs nothing like this. A
/// comment does: it lives in the channel's linked discussion group, and the
/// person who left it has their own name, handle and picture. The mapper used
/// to take those as three loose optional strings and fall back to the chat for
/// each one independently — which is how a commenter with a name but no
/// profile photo ended up wearing the channel's avatar, a stranger apparently
/// posting as the channel itself.
///
/// Bundling them fixes that by construction: **a sender, once supplied, is the
/// whole answer.** A null field here means "this person has no picture", not
/// "ask the chat instead".
@immutable
class PostSender {
  /// The user behind the message, when a person sent it. Null for a message
  /// sent by a chat — a channel posting into its own discussion group, or an
  /// anonymous admin.
  final int? userId;

  /// The chat behind the message, when a chat sent it rather than a person.
  final int? senderChatId;

  final String title;
  final String? username;

  /// Local path or remote id of the sender's photo. Null when they have none,
  /// in which case the avatar falls back to their initial — never to the
  /// chat's picture.
  final String? avatarPath;
  final int? avatarFileId;

  const PostSender({
    required this.title,
    this.userId,
    this.senderChatId,
    this.username,
    this.avatarPath,
    this.avatarFileId,
  });

  /// What the avatar's fallback colour is derived from, so two comments by the
  /// same person are the same colour and two people are not.
  int get colorSeed => userId ?? senderChatId ?? title.hashCode;

  @override
  bool operator ==(Object other) =>
      other is PostSender &&
      other.userId == userId &&
      other.senderChatId == senderChatId &&
      other.title == title &&
      other.username == username &&
      other.avatarPath == avatarPath &&
      other.avatarFileId == avatarFileId;

  @override
  int get hashCode => Object.hash(
    userId,
    senderChatId,
    title,
    username,
    avatarPath,
    avatarFileId,
  );

  @override
  String toString() => 'PostSender($title, user: $userId)';
}
