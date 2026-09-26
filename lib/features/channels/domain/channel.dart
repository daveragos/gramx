import 'package:freezed_annotation/freezed_annotation.dart';

part 'channel.freezed.dart';
part 'channel.g.dart';

@freezed
abstract class Channel with _$Channel {
  const factory Channel({
    required String id,
    required int chatId,
    required String title,
    String? username,
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

    /// Whether Telegram will produce statistics for this channel.
    ///
    /// `SupergroupFullInfo.canGetStatistics`, which is true only for somebody
    /// who administers the channel and only once it is past a member threshold
    /// Telegram sets. It decides whether the Analytics entry exists at all —
    /// the alternative was a menu item that opens onto an error, which is the
    /// inert control the hard rules forbid.
    ///
    /// False whenever full info was not fetched, and always false for a guest
    /// channel: it costs no request to answer "no".
    @Default(false) bool canViewStatistics,
    DateTime? lastPostAt,
  }) = _Channel;

  factory Channel.fromJson(Map<String, dynamic> json) =>
      _$ChannelFromJson(json);
}
