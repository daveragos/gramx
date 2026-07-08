import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_item.freezed.dart';
part 'media_item.g.dart';

enum MediaType {
  photo,
  video,
  gif,
  document,
  audio,
  voice,
  sticker,
}

@freezed
abstract class MediaItem with _$MediaItem {
  const factory MediaItem({
    required String id,
    required MediaType type,
    String? url,
    String? thumbnailUrl,
    @Default(0) int width,
    @Default(0) int height,
    @Default(0) int duration,
    @Default(0) int fileSize,
    String? fileName,
    String? mimeType,
    String? localPath,
  }) = _MediaItem;

  factory MediaItem.fromJson(Map<String, dynamic> json) => _$MediaItemFromJson(json);
}
