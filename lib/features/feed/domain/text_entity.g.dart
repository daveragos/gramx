// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'text_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TextEntity _$TextEntityFromJson(Map<String, dynamic> json) => _TextEntity(
  offset: (json['offset'] as num).toInt(),
  length: (json['length'] as num).toInt(),
  type: $enumDecode(_$TextEntityTypeEnumMap, json['type']),
  url: json['url'] as String?,
  customEmojiId: json['customEmojiId'] as String?,
  language: json['language'] as String?,
);

Map<String, dynamic> _$TextEntityToJson(_TextEntity instance) =>
    <String, dynamic>{
      'offset': instance.offset,
      'length': instance.length,
      'type': _$TextEntityTypeEnumMap[instance.type]!,
      'url': instance.url,
      'customEmojiId': instance.customEmojiId,
      'language': instance.language,
    };

const _$TextEntityTypeEnumMap = {
  TextEntityType.bold: 'bold',
  TextEntityType.italic: 'italic',
  TextEntityType.underline: 'underline',
  TextEntityType.strikethrough: 'strikethrough',
  TextEntityType.code: 'code',
  TextEntityType.codeBlock: 'codeBlock',
  TextEntityType.blockQuote: 'blockQuote',
  TextEntityType.expandableBlockQuote: 'expandableBlockQuote',
  TextEntityType.url: 'url',
  TextEntityType.textUrl: 'textUrl',
  TextEntityType.mention: 'mention',
  TextEntityType.mentionName: 'mentionName',
  TextEntityType.hashtag: 'hashtag',
  TextEntityType.cashtag: 'cashtag',
  TextEntityType.botCommand: 'botCommand',
  TextEntityType.emailAddress: 'emailAddress',
  TextEntityType.phoneNumber: 'phoneNumber',
  TextEntityType.bankCardNumber: 'bankCardNumber',
  TextEntityType.mediaTimestamp: 'mediaTimestamp',
  TextEntityType.spoiler: 'spoiler',
  TextEntityType.customEmoji: 'customEmoji',
  TextEntityType.unknown: 'unknown',
};
