import 'package:freezed_annotation/freezed_annotation.dart';

part 'channel.freezed.dart';
part 'channel.g.dart';

@freezed
abstract class Channel with _$Channel {
  const factory Channel({
    required String id,
    required int chatId,
    required String title,

    /// The first of the channel's usernames, as Telegram lists them.
    String? username,

    /// Usernames it also uses, after [username].
    @Default([]) List<String> otherUsernames,
    String? description,
    String? avatarUrl,
    int? avatarFileId,
    String? avatarColor,
    @Default(0) int subscriberCount,
    @Default(false) bool isVerified,
    @Default(false) bool isFavorite,
    @Default(false) bool isMuted,
    @Default(false) bool isHidden,
    @Default(true) bool isJoined,

    /// Whether Telegram offers statistics (`canGetStatistics`), which it does
    /// only for admins of large enough channels. Decides whether Analytics is
    /// shown. False when full info wasn't fetched, and always for a guest.
    @Default(false) bool canViewStatistics,
    DateTime? lastPostAt,
  }) = _Channel;

  factory Channel.fromJson(Map<String, dynamic> json) =>
      _$ChannelFromJson(json);
}
