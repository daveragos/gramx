// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Post _$PostFromJson(Map<String, dynamic> json) => _Post(
  id: json['id'] as String,
  chatId: (json['chatId'] as num).toInt(),
  channelId: json['channelId'] as String,
  messageId: (json['messageId'] as num).toInt(),
  mediaAlbumId: (json['mediaAlbumId'] as num?)?.toInt() ?? 0,
  channelTitle: json['channelTitle'] as String,
  channelUsername: json['channelUsername'] as String?,
  channelAvatarUrl: json['channelAvatarUrl'] as String?,
  channelAvatarFileId: (json['channelAvatarFileId'] as num?)?.toInt(),
  channelAvatarColor: json['channelAvatarColor'] as String?,
  isChannelVerified: json['isChannelVerified'] as bool? ?? false,
  text: json['text'] as String?,
  media:
      (json['media'] as List<dynamic>?)
          ?.map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  publishedAt: DateTime.parse(json['publishedAt'] as String),
  viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
  replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
  forwardCount: (json['forwardCount'] as num?)?.toInt() ?? 0,
  reactions:
      (json['reactions'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const {},
  isBookmarked: json['isBookmarked'] as bool? ?? false,
  isRead: json['isRead'] as bool? ?? false,
  linkPreviewUrl: json['linkPreviewUrl'] as String?,
  linkPreviewTitle: json['linkPreviewTitle'] as String?,
  linkPreviewDescription: json['linkPreviewDescription'] as String?,
  linkPreviewImageUrl: json['linkPreviewImageUrl'] as String?,
  forwardedFromTitle: json['forwardedFromTitle'] as String?,
  forwardedFromUsername: json['forwardedFromUsername'] as String?,
  forwardedFromChatId: json['forwardedFromChatId'] as String?,
  entities:
      (json['entities'] as List<dynamic>?)
          ?.map((e) => TextEntity.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  poll: json['poll'] == null
      ? null
      : Poll.fromJson(json['poll'] as Map<String, dynamic>),
);

Map<String, dynamic> _$PostToJson(_Post instance) => <String, dynamic>{
  'id': instance.id,
  'chatId': instance.chatId,
  'channelId': instance.channelId,
  'messageId': instance.messageId,
  'mediaAlbumId': instance.mediaAlbumId,
  'channelTitle': instance.channelTitle,
  'channelUsername': instance.channelUsername,
  'channelAvatarUrl': instance.channelAvatarUrl,
  'channelAvatarFileId': instance.channelAvatarFileId,
  'channelAvatarColor': instance.channelAvatarColor,
  'isChannelVerified': instance.isChannelVerified,
  'text': instance.text,
  'media': instance.media,
  'publishedAt': instance.publishedAt.toIso8601String(),
  'viewCount': instance.viewCount,
  'replyCount': instance.replyCount,
  'forwardCount': instance.forwardCount,
  'reactions': instance.reactions,
  'isBookmarked': instance.isBookmarked,
  'isRead': instance.isRead,
  'linkPreviewUrl': instance.linkPreviewUrl,
  'linkPreviewTitle': instance.linkPreviewTitle,
  'linkPreviewDescription': instance.linkPreviewDescription,
  'linkPreviewImageUrl': instance.linkPreviewImageUrl,
  'forwardedFromTitle': instance.forwardedFromTitle,
  'forwardedFromUsername': instance.forwardedFromUsername,
  'forwardedFromChatId': instance.forwardedFromChatId,
  'entities': instance.entities,
  'poll': instance.poll,
};
