import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chat_list_builder.dart';
import 'package:gramx/features/chats/domain/user_profile.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';

/// Turns TDLib's `User` and `UserFullInfo` into one profile. Pure, so it can be
/// tested without a client.
abstract class UserProfileMapper {
  /// Builds a profile. [fullInfo] is optional so the screen can draw before
  /// that request returns. [personalChannelTitle] comes from the caller's chat
  /// cache, to avoid an extra `GetChat`.
  static UserProfile from(
    td.User user, {
    td.UserFullInfo? fullInfo,
    String? personalChannelTitle,
  }) {
    final photo = user.profilePhoto;
    final personalChatId = fullInfo?.personalChatId ?? 0;

    return UserProfile(
      userId: user.id,
      // TDLib uses the user id as the private chat's id.
      chatId: user.id,
      displayName: TdlibMappers.userDisplayName(user),
      username: user.usernames?.activeUsernames.firstOrNull,
      avatarPath: photoPath(photo),
      avatarFileId: photo?.small.id,
      avatarColorHex: TdlibMappers.avatarColorFor(user.id),
      isVerified: user.isVerified,
      isPremium: user.isPremium,
      emojiStatusId: ChatListBuilder.emojiStatusOf(user),
      isBot: user.type is td.UserTypeBot,
      isContact: user.isContact,
      isDeleted: user.type is td.UserTypeDeleted,
      presence: ChatListBuilder.presenceOf(user),
      bio: bioOf(fullInfo),
      // Telegram sends an empty string when privacy settings hide the number.
      phoneNumber: user.phoneNumber.isEmpty ? null : '+${user.phoneNumber}',
      personalChannelId: personalChatId == 0 ? null : personalChatId,
      personalChannelTitle: personalChatId == 0 ? null : personalChannelTitle,
      groupsInCommon: fullInfo?.groupInCommonCount ?? 0,
    );
  }

  /// The bio, or null when there is nothing to show. A bot's bio may be null;
  /// its description lives on `botInfo`.
  static String? bioOf(td.UserFullInfo? fullInfo) {
    final text = fullInfo?.bio?.text.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  /// A profile photo's local path if downloaded, else its remote id. Null when
  /// there is no photo.
  static String? photoPath(td.ProfilePhoto? photo) {
    if (photo == null) return null;
    if (photo.small.local.path.isNotEmpty) return photo.small.local.path;
    if (photo.small.remote.id.isNotEmpty) return photo.small.remote.id;
    return null;
  }
}
