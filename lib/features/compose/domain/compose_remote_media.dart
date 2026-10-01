import 'package:flutter/foundation.dart';

/// The kinds of media from the account's collection that can be posted. A
/// sticker takes no caption (`inputMessageSticker` has none); a GIF does.
/// Neither can go in an album.
enum ComposeRemoteKind { sticker, animation }

/// A sticker or GIF chosen from the account's collection. Unlike a
/// `ComposeAttachment`, it is already on Telegram's servers and is sent by
/// file id, with no upload or size check.
@immutable
class ComposeRemoteMedia {
  /// TDLib's file id for the sticker or animation.
  final int fileId;

  final ComposeRemoteKind kind;

  final int width;
  final int height;

  /// Animation length in whole seconds. Always 0 for a sticker.
  final int durationSeconds;

  /// The sticker's emoji. Required by `inputMessageSticker`, and also used as
  /// the accessible name.
  final String emoji;

  /// File id of the still thumbnail, drawn until the sticker is fetched.
  final int? thumbnailFileId;

  const ComposeRemoteMedia({
    required this.fileId,
    required this.kind,
    required this.width,
    required this.height,
    this.durationSeconds = 0,
    this.emoji = '',
    this.thumbnailFileId,
  });

  bool get isSticker => kind == ComposeRemoteKind.sticker;
  bool get isAnimation => kind == ComposeRemoteKind.animation;

  /// Whether this can carry a caption. See [ComposeRemoteKind].
  bool get takesCaption => isAnimation;

  @override
  bool operator ==(Object other) =>
      other is ComposeRemoteMedia &&
      other.fileId == fileId &&
      other.kind == kind &&
      other.width == width &&
      other.height == height &&
      other.durationSeconds == durationSeconds &&
      other.emoji == emoji &&
      other.thumbnailFileId == thumbnailFileId;

  @override
  int get hashCode => Object.hash(
    fileId,
    kind,
    width,
    height,
    durationSeconds,
    emoji,
    thumbnailFileId,
  );

  @override
  String toString() => 'ComposeRemoteMedia(${kind.name}, $fileId)';
}
