import 'package:freezed_annotation/freezed_annotation.dart';

part 'text_entity.freezed.dart';
part 'text_entity.g.dart';

/// Every formatting mark Telegram can put on a message.
///
/// Kept in step with TDLib's `TextEntityType` union: anything missing here maps
/// to [unknown] and renders as plain text, which is how quoted blocks and code
/// blocks used to lose their formatting entirely.
enum TextEntityType {
  bold,
  italic,
  underline,
  strikethrough,
  code,
  codeBlock,
  blockQuote,

  /// A quote Telegram collapses until tapped. Rendered as a quote here, since
  /// the post itself already collapses when it is long.
  expandableBlockQuote,
  url,
  textUrl,
  mention,

  /// A mention of a user with no username — the name is the link text and the
  /// id is all Telegram gives us, so it is styled but not tappable.
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
    String? url,            // for textUrl
    String? customEmojiId,  // for customEmoji
    String? language,       // for a fenced code block
  }) = _TextEntity;

  factory TextEntity.fromJson(Map<String, dynamic> json) => _$TextEntityFromJson(json);
}
