import 'package:flutter/foundation.dart';

/// Who wrote a message, when that is not the chat it arrived in. A null
/// field means the sender has none, not that the chat's value applies.
@immutable
class PostSender {
  /// The user behind the message, or null when a chat sent it (a channel in
  /// its discussion group, or an anonymous admin).
  final int? userId;

  /// The chat behind the message, when a chat sent it.
  final int? senderChatId;

  final String title;
  final String? username;

  /// Local path of the sender's photo. Null when they have none; the avatar
  /// then shows their initial, never the chat's picture.
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

  /// Seeds the avatar's fallback colour, so each person keeps one colour.
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
