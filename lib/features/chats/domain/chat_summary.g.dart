// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChatSummary _$ChatSummaryFromJson(Map<String, dynamic> json) => _ChatSummary(
  chatId: (json['chatId'] as num).toInt(),
  title: json['title'] as String,
  kind: $enumDecode(_$ChatKindEnumMap, json['kind']),
  username: json['username'] as String?,
  avatarPath: json['avatarPath'] as String?,
  avatarFileId: (json['avatarFileId'] as num?)?.toInt(),
  avatarColorHex: json['avatarColorHex'] as String?,
  preview: json['preview'] as String?,
  previewSender: json['previewSender'] as String?,
  previewIsDraft: json['previewIsDraft'] as bool? ?? false,
  previewSendState: $enumDecodeNullable(
    _$MessageSendStateEnumMap,
    json['previewSendState'],
  ),
  affiliatedChannelId: (json['affiliatedChannelId'] as num?)?.toInt(),
  affiliatedChannelTitle: json['affiliatedChannelTitle'] as String?,
  affiliatedChannelAvatarPath: json['affiliatedChannelAvatarPath'] as String?,
  affiliatedChannelAvatarFileId: (json['affiliatedChannelAvatarFileId'] as num?)
      ?.toInt(),
  affiliatedChannelAvatarColorHex:
      json['affiliatedChannelAvatarColorHex'] as String?,
  lastMessageAt: json['lastMessageAt'] == null
      ? null
      : DateTime.parse(json['lastMessageAt'] as String),
  unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
  isMarkedAsUnread: json['isMarkedAsUnread'] as bool? ?? false,
  unreadMentionCount: (json['unreadMentionCount'] as num?)?.toInt() ?? 0,
  isMuted: json['isMuted'] as bool? ?? false,
  isVerified: json['isVerified'] as bool? ?? false,
  isRequest: json['isRequest'] as bool? ?? false,
  presence:
      $enumDecodeNullable(_$ChatPresenceEnumMap, json['presence']) ??
      ChatPresence.unknown,
  mainListOrder: (json['mainListOrder'] as num?)?.toInt() ?? 0,
  isPinned: json['isPinned'] as bool? ?? false,
);

Map<String, dynamic> _$ChatSummaryToJson(
  _ChatSummary instance,
) => <String, dynamic>{
  'chatId': instance.chatId,
  'title': instance.title,
  'kind': _$ChatKindEnumMap[instance.kind]!,
  'username': instance.username,
  'avatarPath': instance.avatarPath,
  'avatarFileId': instance.avatarFileId,
  'avatarColorHex': instance.avatarColorHex,
  'preview': instance.preview,
  'previewSender': instance.previewSender,
  'previewIsDraft': instance.previewIsDraft,
  'previewSendState': _$MessageSendStateEnumMap[instance.previewSendState],
  'affiliatedChannelId': instance.affiliatedChannelId,
  'affiliatedChannelTitle': instance.affiliatedChannelTitle,
  'affiliatedChannelAvatarPath': instance.affiliatedChannelAvatarPath,
  'affiliatedChannelAvatarFileId': instance.affiliatedChannelAvatarFileId,
  'affiliatedChannelAvatarColorHex': instance.affiliatedChannelAvatarColorHex,
  'lastMessageAt': instance.lastMessageAt?.toIso8601String(),
  'unreadCount': instance.unreadCount,
  'isMarkedAsUnread': instance.isMarkedAsUnread,
  'unreadMentionCount': instance.unreadMentionCount,
  'isMuted': instance.isMuted,
  'isVerified': instance.isVerified,
  'isRequest': instance.isRequest,
  'presence': _$ChatPresenceEnumMap[instance.presence]!,
  'mainListOrder': instance.mainListOrder,
  'isPinned': instance.isPinned,
};

const _$ChatKindEnumMap = {
  ChatKind.savedMessages: 'savedMessages',
  ChatKind.direct: 'direct',
  ChatKind.bot: 'bot',
  ChatKind.group: 'group',
};

const _$MessageSendStateEnumMap = {
  MessageSendState.sending: 'sending',
  MessageSendState.sent: 'sent',
  MessageSendState.read: 'read',
  MessageSendState.failed: 'failed',
};

const _$ChatPresenceEnumMap = {
  ChatPresence.online: 'online',
  ChatPresence.offline: 'offline',
  ChatPresence.recently: 'recently',
  ChatPresence.lastWeek: 'lastWeek',
  ChatPresence.lastMonth: 'lastMonth',
  ChatPresence.unknown: 'unknown',
};
