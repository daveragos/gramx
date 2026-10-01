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

    /// Whether Telegram flagged this video as streamable (`faststart`, index at
    /// the front). Without it the file must be downloaded in full before it
    /// plays. See `TdlibFileServer`.
    @Default(false) bool supportsStreaming,

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
  }) = _MediaItem;

  factory MediaItem.fromJson(Map<String, dynamic> json) =>
      _$MediaItemFromJson(json);
}
