import 'package:freezed_annotation/freezed_annotation.dart';

part 'text_entity.freezed.dart';
part 'text_entity.g.dart';

/// Every formatting mark Telegram can put on a message. Mirrors TDLib's
/// `TextEntityType`; anything missing maps to [unknown] and renders plain.
enum TextEntityType {
  bold,
  italic,
  underline,
  strikethrough,
  code,
  codeBlock,
  blockQuote,

  /// A quote Telegram collapses until tapped. Drawn as a normal quote, since
  /// long posts already collapse.
  expandableBlockQuote,
  url,
  textUrl,
  mention,

  /// A mention of a user by id rather than username, as bots write them.
  /// Opens the person's profile from [TextEntity.userId].
  mentionName,
  hashtag,
  cashtag,
  botCommand,
  emailAddress,
  phoneNumber,
  bankCardNumber,
  mediaTimestamp,
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
    String? url, // for textUrl
    String? customEmojiId, // for customEmoji
    String? language, // for a fenced code block
    int? userId, // for mentionName
  }) = _TextEntity;

  factory TextEntity.fromJson(Map<String, dynamic> json) =>
      _$TextEntityFromJson(json);
}
