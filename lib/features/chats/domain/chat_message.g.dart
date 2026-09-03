// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => _ChatMessage(
  id: json['id'] as String,
  chatId: (json['chatId'] as num).toInt(),
  messageId: (json['messageId'] as num).toInt(),
  mediaAlbumId: (json['mediaAlbumId'] as num?)?.toInt() ?? 0,
  isOutgoing: json['isOutgoing'] as bool,
  senderId: (json['senderId'] as num?)?.toInt(),
  senderName: json['senderName'] as String?,
  senderAvatarPath: json['senderAvatarPath'] as String?,
  senderAvatarFileId: (json['senderAvatarFileId'] as num?)?.toInt(),
  senderAvatarColorHex: json['senderAvatarColorHex'] as String?,
  text: json['text'] as String?,
  entities:
      (json['entities'] as List<dynamic>?)
          ?.map((e) => TextEntity.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  media:
      (json['media'] as List<dynamic>?)
          ?.map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  poll: _pollFromJson(json['poll']),
  place: _placeFromJson(json['place']),
  contact: _contactFromJson(json['contact']),
  isSecretMedia: json['isSecretMedia'] as bool? ?? false,
  isViewOnce: json['isViewOnce'] as bool? ?? false,
  selfDestructSeconds: (json['selfDestructSeconds'] as num?)?.toInt() ?? 0,
  sentAt: DateTime.parse(json['sentAt'] as String),
  editedAt: json['editedAt'] == null
      ? null
      : DateTime.parse(json['editedAt'] as String),
  sendState:
      $enumDecodeNullable(_$MessageSendStateEnumMap, json['sendState']) ??
      MessageSendState.sent,
  reactions:
      (json['reactions'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const {},
  chosenReactions:
      (json['chosenReactions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      const {},
  replyToMessageId: (json['replyToMessageId'] as num?)?.toInt(),
  replyToText: json['replyToText'] as String?,
  replyToAuthorName: json['replyToAuthorName'] as String?,
  replyToChatId: (json['replyToChatId'] as num?)?.toInt(),
  replyToThumbnailFileId: (json['replyToThumbnailFileId'] as num?)?.toInt(),
  forwardedFromTitle: json['forwardedFromTitle'] as String?,
  linkPreviewUrl: json['linkPreviewUrl'] as String?,
  linkPreviewTitle: json['linkPreviewTitle'] as String?,
  linkPreviewDescription: json['linkPreviewDescription'] as String?,
  linkPreviewFileId: (json['linkPreviewFileId'] as num?)?.toInt(),
  isPinned: json['isPinned'] as bool? ?? false,
  isService: json['isService'] as bool? ?? false,
  unsupportedKind: json['unsupportedKind'] as String?,
);

Map<String, dynamic> _$ChatMessageToJson(_ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'chatId': instance.chatId,
      'messageId': instance.messageId,
      'mediaAlbumId': instance.mediaAlbumId,
      'isOutgoing': instance.isOutgoing,
      'senderId': instance.senderId,
      'senderName': instance.senderName,
      'senderAvatarPath': instance.senderAvatarPath,
      'senderAvatarFileId': instance.senderAvatarFileId,
      'senderAvatarColorHex': instance.senderAvatarColorHex,
      'text': instance.text,
      'entities': instance.entities,
      'media': instance.media,
      'poll': _pollToJson(instance.poll),
      'place': _placeToJson(instance.place),
      'contact': _contactToJson(instance.contact),
      'isSecretMedia': instance.isSecretMedia,
      'isViewOnce': instance.isViewOnce,
      'selfDestructSeconds': instance.selfDestructSeconds,
      'sentAt': instance.sentAt.toIso8601String(),
      'editedAt': instance.editedAt?.toIso8601String(),
      'sendState': _$MessageSendStateEnumMap[instance.sendState]!,
      'reactions': instance.reactions,
      'chosenReactions': instance.chosenReactions.toList(),
      'replyToMessageId': instance.replyToMessageId,
      'replyToText': instance.replyToText,
      'replyToAuthorName': instance.replyToAuthorName,
      'replyToChatId': instance.replyToChatId,
      'replyToThumbnailFileId': instance.replyToThumbnailFileId,
      'forwardedFromTitle': instance.forwardedFromTitle,
      'linkPreviewUrl': instance.linkPreviewUrl,
      'linkPreviewTitle': instance.linkPreviewTitle,
      'linkPreviewDescription': instance.linkPreviewDescription,
      'linkPreviewFileId': instance.linkPreviewFileId,
      'isPinned': instance.isPinned,
      'isService': instance.isService,
      'unsupportedKind': instance.unsupportedKind,
    };

const _$MessageSendStateEnumMap = {
  MessageSendState.sending: 'sending',
  MessageSendState.sent: 'sent',
  MessageSendState.read: 'read',
  MessageSendState.failed: 'failed',
};
