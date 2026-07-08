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
    String? avatarColor,
    @Default(0) int subscriberCount,
    @Default(false) bool isVerified,
    @Default(false) bool isFavorite,
    @Default(false) bool isMuted,
    @Default(false) bool isHidden,
    DateTime? lastPostAt,
  }) = _Channel;

  factory Channel.fromJson(Map<String, dynamic> json) => _$ChannelFromJson(json);
}
