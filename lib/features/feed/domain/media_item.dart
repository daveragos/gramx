import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_item.freezed.dart';
part 'media_item.g.dart';

/// How an animated sticker is encoded.
///
/// Telegram ships three, and they need three different renderers — treating
/// them all as images (which this app used to do) leaves TGS and WebM broken.
enum StickerFormat {
  /// Still or animated WebP. Flutter's Image widget animates these natively.
  webp,

  /// Gzipped Lottie JSON. Decoded with the lottie package after gunzip.
  tgs,

  /// VP9 video with an alpha channel. Android's hardware decoder drops the
  /// alpha plane, so this falls back to the static thumbnail for now.
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

    /// Whether Telegram flagged this video as streamable.
    ///
    /// Set only for videos muxed so playback can begin before the file is
    /// complete (`faststart`: the moov atom at the front). A video without it
    /// cannot be played from a prefix at all — the player would read the whole
    /// thing looking for the index — so it must fall back to downloading in
    /// full. See `TdlibFileServer`.
    @Default(false) bool supportsStreaming,
    /// Base64-encoded JPEG minithumbnail from Telegram (tiny ~100 byte preview).
    String? minithumbnail,
    /// TDLib file ID for the main media file (for reactive download tracking).
    int? fileId,
    /// TDLib file ID for the thumbnail file.
    int? thumbnailFileId,
    /// How a sticker is encoded. Only meaningful for [MediaType.sticker].
    @Default(StickerFormat.unknown) StickerFormat stickerFormat,
    /// Telegram's "cover this until tapped" flag, set by the poster.
    @Default(false) bool hasSpoiler,
  }) = _MediaItem;

  factory MediaItem.fromJson(Map<String, dynamic> json) => _$MediaItemFromJson(json);
}
