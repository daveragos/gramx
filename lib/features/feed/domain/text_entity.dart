import 'package:freezed_annotation/freezed_annotation.dart';

part 'text_entity.freezed.dart';
part 'text_entity.g.dart';

enum TextEntityType {
  bold,
  italic,
  underline,
  strikethrough,
  code,
  codeBlock,
  url,
  textUrl,
  mention,
  hashtag,
  spoiler,
  customEmoji,
  unknown,
}

@freezed
abstract class TextEntity with _$TextEntity {
  const factory TextEntity({
    required int offset,
    required int length,
    required TextEntityType type,
    String? url,            // for textUrl
    String? customEmojiId,  // for customEmoji
  }) = _TextEntity;

  factory TextEntity.fromJson(Map<String, dynamic> json) => _$TextEntityFromJson(json);
}
