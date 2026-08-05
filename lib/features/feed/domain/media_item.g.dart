// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MediaItem _$MediaItemFromJson(Map<String, dynamic> json) => _MediaItem(
  id: json['id'] as String,
  type: $enumDecode(_$MediaTypeEnumMap, json['type']),
  url: json['url'] as String?,
  thumbnailUrl: json['thumbnailUrl'] as String?,
  width: (json['width'] as num?)?.toInt() ?? 0,
  height: (json['height'] as num?)?.toInt() ?? 0,
  duration: (json['duration'] as num?)?.toInt() ?? 0,
  fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
  fileName: json['fileName'] as String?,
  mimeType: json['mimeType'] as String?,
  localPath: json['localPath'] as String?,
  minithumbnail: json['minithumbnail'] as String?,
  fileId: (json['fileId'] as num?)?.toInt(),
  thumbnailFileId: (json['thumbnailFileId'] as num?)?.toInt(),
);

Map<String, dynamic> _$MediaItemToJson(_MediaItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$MediaTypeEnumMap[instance.type]!,
      'url': instance.url,
      'thumbnailUrl': instance.thumbnailUrl,
      'width': instance.width,
      'height': instance.height,
      'duration': instance.duration,
      'fileSize': instance.fileSize,
      'fileName': instance.fileName,
      'mimeType': instance.mimeType,
      'localPath': instance.localPath,
      'minithumbnail': instance.minithumbnail,
      'fileId': instance.fileId,
      'thumbnailFileId': instance.thumbnailFileId,
    };

const _$MediaTypeEnumMap = {
  MediaType.photo: 'photo',
  MediaType.video: 'video',
  MediaType.gif: 'gif',
  MediaType.document: 'document',
  MediaType.audio: 'audio',
  MediaType.voice: 'voice',
  MediaType.sticker: 'sticker',
};
