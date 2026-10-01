import 'package:flutter/foundation.dart';

import 'package:gramx/features/chats/domain/chat_summary.dart';

/// Everything gramX knows about one person.
///
/// Lives in the `chats` feature rather than in one of its own, and that is a
/// deliberate reading of the no-cross-feature-imports rule: a profile of a
/// person is the other half of a conversation with them. It shares the
/// presence enum, the display-name rule, the chat cache and the repository
/// with the messages list, and a separate feature folder would have had to
/// import all four across the boundary or duplicate them.
///
/// A plain immutable class rather than a Freezed model because nothing here is
/// ever persisted or serialised — a profile is fetched, looked at, and thrown
/// away. It is assembled from two TDLib objects: `User`, which the chat cache
/// usually already holds, and `UserFullInfo`, which carries the bio, the
/// number of groups in common, and the channel this person pins to their
/// profile.
@immutable
class UserProfile {
  final int userId;

  /// Where a conversation with this person lives. Same number as [userId] in
  /// TDLib's model for a private chat, but they are different things and one
  /// of them is what a route takes.
  final int chatId;

  final String displayName;
  final String? username;

  /// Local path or remote id of the profile photo. Null when they have none.
  final String? avatarPath;
  final int? avatarFileId;
  final String? avatarColorHex;

  final bool isVerified;
  final bool isPremium;

  /// The custom emoji a Premium account shows in place of the Premium star,
  /// while it has one in force. See `ChatListBuilder.emojiStatusOf`.
  final int? emojiStatusId;
  final bool isBot;
  final bool isContact;

  /// A deleted account. Rendered as such rather than as somebody with an empty
  /// profile, which is what it otherwise looks like.
  final bool isDeleted;

  /// Telegram's blurred answer about when they were last around.
  final ChatPresence presence;

  /// The bio, as they wrote it. Null when there is none, or for a bot, which
  /// puts its description somewhere else entirely.
  final String? bio;

  /// The phone number, when Telegram will give it — which is only for contacts
  /// and people who have chosen to publish it.
  final String? phoneNumber;

  /// The channel this person pins to their profile. Telegram calls it a
  final int? personalChannelId;
  final String? personalChannelTitle;

  /// Groups this account and that person are both in.
  final int groupsInCommon;

  const UserProfile({
    required this.userId,
    required this.chatId,
    required this.displayName,
    this.username,
    this.avatarPath,
    this.avatarFileId,
    this.avatarColorHex,
    this.isVerified = false,
    this.isPremium = false,
    this.emojiStatusId,
    this.isBot = false,
    this.isContact = false,
    this.isDeleted = false,
    this.presence = ChatPresence.unknown,
    this.bio,
    this.phoneNumber,
    this.personalChannelId,
    this.personalChannelTitle,
    this.groupsInCommon = 0,
  });

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.userId == userId &&
      other.chatId == chatId &&
      other.displayName == displayName &&
      other.username == username &&
      other.avatarPath == avatarPath &&
      other.avatarFileId == avatarFileId &&
      other.avatarColorHex == avatarColorHex &&
      other.isVerified == isVerified &&
      other.isPremium == isPremium &&
      other.emojiStatusId == emojiStatusId &&
      other.isBot == isBot &&
      other.isContact == isContact &&
      other.isDeleted == isDeleted &&
      other.presence == presence &&
      other.bio == bio &&
      other.phoneNumber == phoneNumber &&
      other.personalChannelId == personalChannelId &&
      other.personalChannelTitle == personalChannelTitle &&
      other.groupsInCommon == groupsInCommon;

  @override
  int get hashCode => Object.hash(
    userId,
    chatId,
    displayName,
    username,
    avatarPath,
    avatarFileId,
    avatarColorHex,
    isVerified,
    isPremium,
    emojiStatusId,
    isBot,
    isContact,
    isDeleted,
    presence,
    bio,
    phoneNumber,
    personalChannelId,
    personalChannelTitle,
    groupsInCommon,
  );

  @override
  String toString() => 'UserProfile($displayName, $userId)';
}
