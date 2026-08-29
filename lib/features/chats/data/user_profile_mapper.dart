import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chat_list_builder.dart';
import 'package:gramx/features/chats/domain/user_profile.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';

/// Turns TDLib's two user objects into one profile.
///
/// Pure and passed everything it needs, for the same reason `ChatListBuilder`
/// is: the interesting parts here are decisions, not I/O. What counts as a
/// deleted account, when a bio is worth showing, whether a phone number
/// Telegram returned as an empty string means "hidden" — each of those is a
/// rule that can be wrong quietly, and each is testable without a client.
abstract class UserProfileMapper {
  /// Builds a profile. [fullInfo] is optional: the screen draws what it has
  /// while the second request is still in flight, rather than holding the
  /// whole page back for a bio.
  ///
  /// [personalChannelTitle] is looked up by the caller from the chat cache —
  /// resolving it here would mean a `GetChat`, and a profile is already two
  /// requests.
  static UserProfile from(
    td.User user, {
    td.UserFullInfo? fullInfo,
    String? personalChannelTitle,
  }) {
    final photo = user.profilePhoto;
    final personalChatId = fullInfo?.personalChatId ?? 0;

    return UserProfile(
      userId: user.id,
      // TDLib uses the user id as the private chat's id. Carried as its own
      // field anyway: they are different things, and the one a route takes is
      // the chat.
      chatId: user.id,
      displayName: TdlibMappers.userDisplayName(user),
      username: user.usernames?.activeUsernames.firstOrNull,
      avatarPath: photoPath(photo),
      avatarFileId: photo?.small.id,
      avatarColorHex: TdlibMappers.avatarColorFor(user.id),
      isVerified: user.isVerified,
      isPremium: user.isPremium,
      isBot: user.type is td.UserTypeBot,
      isContact: user.isContact,
      isDeleted: user.type is td.UserTypeDeleted,
      presence: ChatListBuilder.presenceOf(user),
      bio: bioOf(fullInfo),
      // Telegram answers an empty string when the number is hidden by privacy
      // settings rather than omitting the field, so "" has to be read as "no",
      // not rendered as a blank row under a "Phone" label.
      phoneNumber: user.phoneNumber.isEmpty ? null : '+${user.phoneNumber}',
      personalChannelId: personalChatId == 0 ? null : personalChatId,
      personalChannelTitle: personalChatId == 0 ? null : personalChannelTitle,
      groupsInCommon: fullInfo?.groupInCommonCount ?? 0,
    );
  }

  /// The bio, or null when there is nothing to show.
  ///
  /// A bot's `UserFullInfo.bio` is documented as possibly null and its real
  /// description lives on `botInfo`, so a bot with no bio gets nothing here
  /// rather than an empty paragraph where a description ought to be.
  static String? bioOf(td.UserFullInfo? fullInfo) {
    final text = fullInfo?.bio?.text.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  /// A profile photo's local file if it has arrived, else something the loader
  /// can resolve later. Null when the person has no photo — never a fallback
  /// to somebody else's.
  static String? photoPath(td.ProfilePhoto? photo) {
    if (photo == null) return null;
    if (photo.small.local.path.isNotEmpty) return photo.small.local.path;
    if (photo.small.remote.id.isNotEmpty) return photo.small.remote.id;
    return null;
  }
}
