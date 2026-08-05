// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Channel _$ChannelFromJson(Map<String, dynamic> json) => _Channel(
  id: json['id'] as String,
  chatId: (json['chatId'] as num).toInt(),
  title: json['title'] as String,
  username: json['username'] as String?,
  description: json['description'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  avatarFileId: (json['avatarFileId'] as num?)?.toInt(),
  avatarColor: json['avatarColor'] as String?,
  subscriberCount: (json['subscriberCount'] as num?)?.toInt() ?? 0,
  isVerified: json['isVerified'] as bool? ?? false,
  isFavorite: json['isFavorite'] as bool? ?? false,
  isMuted: json['isMuted'] as bool? ?? false,
  isHidden: json['isHidden'] as bool? ?? false,
  lastPostAt: json['lastPostAt'] == null
      ? null
      : DateTime.parse(json['lastPostAt'] as String),
);

Map<String, dynamic> _$ChannelToJson(_Channel instance) => <String, dynamic>{
  'id': instance.id,
  'chatId': instance.chatId,
  'title': instance.title,
  'username': instance.username,
  'description': instance.description,
  'avatarUrl': instance.avatarUrl,
  'avatarFileId': instance.avatarFileId,
  'avatarColor': instance.avatarColor,
  'subscriberCount': instance.subscriberCount,
  'isVerified': instance.isVerified,
  'isFavorite': instance.isFavorite,
  'isMuted': instance.isMuted,
  'isHidden': instance.isHidden,
  'lastPostAt': instance.lastPostAt?.toIso8601String(),
};
