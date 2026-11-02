import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_item.freezed.dart';
part 'media_item.g.dart';

/// How a sticker is encoded. Each format needs a different renderer.
enum StickerFormat {
  /// Still or animated WebP. Flutter's Image widget animates these natively.
  webp,

  /// Gzipped Lottie JSON. Decoded with the lottie package after gunzip.
  tgs,

  /// VP9 video with an alpha channel. Android's hardware decoder drops the
  /// alpha plane, so this falls back to the static thumbnail.
  webm,

  /// Not a sticker, or a format we don't recognise.
  unknown;

  static StickerFormat fromTdName(String? typeName) => switch (typeName) {
    'stickerFormatWebp' => StickerFormat.webp,
    'stickerFormatTgs' => StickerFormat.tgs,
    'stickerFormatWebm' => StickerFormat.webm,
    _ => StickerFormat.unknown,
  };

  /// Whether this app can currently animate the format.
  bool get isAnimatable =>
      this == StickerFormat.webp || this == StickerFormat.tgs;
}

enum MediaType { photo, video, gif, document, audio, voice, sticker }

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

    /// Base64 JPEG minithumbnail from Telegram, a preview of about 100 bytes.
    String? minithumbnail,

    /// TDLib file id for the main media file.
    int? fileId,

    /// TDLib file id for the thumbnail.
    int? thumbnailFileId,

    /// How a sticker is encoded. Only meaningful for [MediaType.sticker].
    @Default(StickerFormat.unknown) StickerFormat stickerFormat,

    /// Telegram's spoiler flag: covered until tapped.
    @Default(false) bool hasSpoiler,

    /// Behind a Telegram Stars paywall the reader hasn't unlocked. Its file
    /// isn't downloadable until bought; only a blurred preview and the price
    /// are known. See [starCount].
    @Default(false) bool isPaid,

    /// Telegram Stars that unlock the paid media in the message, 0 when free.
    /// A message unlocks as a whole, so every paid item in it shares the count.
    @Default(0) int starCount,
  }) = _MediaItem;

  factory MediaItem.fromJson(Map<String, dynamic> json) =>
      _$MediaItemFromJson(json);
}
