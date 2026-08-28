import 'package:flutter/foundation.dart';

/// The two things in a Telegram account's own collection that can be posted.
///
/// They are not two flavours of the same thing, and the difference decides how
/// the composer behaves:
///
/// * `inputMessageSticker` has **no caption field at all**, so a sticker is the
///   whole post — there is nowhere for writing to go.
/// * `inputMessageAnimation` has one, so a GIF takes a caption like a photo.
///
/// Neither can go in an album: `sendMessageAlbum` groups only audio, document,
/// photo and video. So either of these is exactly one message, alone.
enum ComposeRemoteKind { sticker, animation }

/// A sticker or GIF chosen from the account's own collection.
///
/// Distinct from [ComposeAttachment] because nothing here is uploaded. These
/// files already live on Telegram's servers; the post references one by the
/// file id TDLib already holds, so posting a sticker moves no bytes and costs
/// no upload. That is also why there is no size or rejection check — the
/// account is re-sending something Telegram already accepted.
@immutable
class ComposeRemoteMedia {
  /// TDLib's file id for the sticker or animation itself.
  final int fileId;

  final ComposeRemoteKind kind;

  final int width;
  final int height;

  /// Animation length in whole seconds. Always 0 for a sticker.
  final int durationSeconds;

  /// The emoji this sticker stands for. `inputMessageSticker` requires it, and
  /// it doubles as the accessible name — a sticker is a picture of a feeling,
  /// and the emoji is the only text Telegram has for it.
  final String emoji;

  /// File id of the still thumbnail, for drawing the tile before the sticker
  /// itself has been fetched.
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

  /// Whether a caption can ride along with this. See [ComposeRemoteKind].
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
