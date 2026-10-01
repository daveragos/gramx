import 'package:flutter/foundation.dart';

import 'package:gramx/features/chats/domain/chat_summary.dart';

/// Everything gramX knows about one person, assembled from TDLib's `User` and
/// `UserFullInfo`.
///
/// Lives in `chats` because it shares the presence enum, chat cache and
/// repository with conversations, and features don't import each other.
@immutable
class UserProfile {
  final int userId;

  /// The private chat with this person. Numerically equal to [userId] in
  /// TDLib, but routes take the chat id.
  final int chatId;

  final String displayName;
  final String? username;

  /// Local path or remote id of the profile photo. Null when they have none.
  final String? avatarPath;
  final int? avatarFileId;
  final String? avatarColorHex;

  final bool isVerified;
  final bool isPremium;

  /// The custom emoji a Premium account shows in place of the Premium star.
  /// See `ChatListBuilder.emojiStatusOf`.
  final int? emojiStatusId;
  final bool isBot;
  final bool isContact;

  /// A deleted account, shown as such instead of as an empty profile.
  final bool isDeleted;

  /// Telegram's blurred answer about when they were last around.
  final ChatPresence presence;

  /// The bio. Null when there is none, and for bots.
  final String? bio;

  /// The phone number. Telegram gives it only for contacts and people who
  /// have made it public.
  final String? phoneNumber;

  /// The channel this person pins to their profile (Telegram's "personal
  /// chat").
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
