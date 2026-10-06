import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/feed/presentation/widgets/post_media_grid.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';
import 'package:gramx/features/settings/data/settings_store.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/media_path.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/presentation/widgets/full_screen_image_viewer.dart';
import 'package:gramx/features/feed/presentation/widgets/full_screen_video_viewer.dart';
import 'package:gramx/features/feed/presentation/widgets/post_audio_player.dart';
import 'package:gramx/features/feed/presentation/widgets/post_document_card.dart';
import 'package:gramx/features/feed/presentation/widgets/sticker_tile.dart';

/// The picture, video, file or sticker inside a message bubble. Unlike the
/// feed's grid, it shows one item at its own aspect ratio.
class BubbleMedia extends ConsumerWidget {
  final MediaItem item;

  /// The bubble's usable width. Media never exceeds it.
  final double maxWidth;

  /// Whether the message has no caption. Captioned media gets square bottom
  /// corners so it joins the text below.
  final bool isAlone;

  const BubbleMedia({
    super.key,
    required this.item,
    required this.maxWidth,
    this.isAlone = true,
  });

  /// Maximum drawn height, so a tall photo doesn't fill the screen.
  static const double maxHeight = 320;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (item.type) {
      case MediaType.sticker:
        // Stickers draw at their own size, uncropped.
        return StickerTile(item: item);
      case MediaType.voice:
      case MediaType.audio:
        return SizedBox(
          width: maxWidth,
          child: PostAudioPlayer(item: item),
        );
      case MediaType.document:
        return SizedBox(
          width: maxWidth,
          child: PostDocumentCard(item: item),
        );
      case MediaType.photo:
      case MediaType.video:
      case MediaType.gif:
        return _VisualMedia(item: item, maxWidth: maxWidth, isAlone: isAlone);
    }
  }
}

/// A photo, video or GIF that opens full screen on tap.
class _VisualMedia extends ConsumerWidget {
  final MediaItem item;
  final double maxWidth;
  final bool isAlone;

  const _VisualMedia({
    required this.item,
    required this.maxWidth,
    required this.isAlone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVideo = item.type != MediaType.photo;

    // With auto-download off a photo waits for a tap, like in the feed.
    // Video thumbnails are small and always load.
    final waitsForTap =
        !isVideo &&
        !ref.watch(settingsProvider.select((s) => s.autoDownloadImagesEnabled));
    final fileId = isVideo ? item.thumbnailFileId : item.fileId;

    // Videos show their thumbnail. Both fall back to the minithumbnail, which
    // arrives inside the message before any download.
    final path = waitsForTap
        ? item.localPath ??
              (fileId == null || fileId == 0
                  ? null
                  : ref
                        .watch(fileDownloadStatusProvider(fileId))
                        .value
                        ?.localPath)
        : resolveMediaPath(
            ref,
            fileId: fileId,
            rawPath: isVideo ? item.thumbnailUrl : (item.localPath ?? item.url),
          );

    final size = _fittedSize();
    final radius = BorderRadius.vertical(
      top: const Radius.circular(AppSpacing.mediaRadius),
      bottom: Radius.circular(isAlone ? AppSpacing.mediaRadius : AppSpacing.xs),
    );

    return GestureDetector(
      onTap: () => _open(context, ref),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Frame(path: path, minithumbnail: item.minithumbnail),
              if (item.hasSpoiler)
                // The sender marked this as a spoiler.
                BackdropBlur(child: const SizedBox.expand()),
              if (isVideo) const _PlayBadge(),
              if (waitsForTap && path == null)
                const Center(child: TapToLoadBadge()),
              if (isVideo && item.duration > 0)
                Positioned(
                  left: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: _DurationChip(seconds: item.duration),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The media's aspect ratio fitted within [maxWidth] and
  /// [BubbleMedia.maxHeight]. Assumes 4:3 when Telegram gives no dimensions.
  Size _fittedSize() {
    final width = item.width > 0 ? item.width.toDouble() : 4;
    final height = item.height > 0 ? item.height.toDouble() : 3;
    final drawnHeight = maxWidth * height / width;
    if (drawnHeight <= BubbleMedia.maxHeight) {
      return Size(maxWidth, drawnHeight);
    }
    return Size(BubbleMedia.maxHeight * width / height, BubbleMedia.maxHeight);
  }

  void _open(BuildContext context, WidgetRef ref) {
    if (item.type == MediaType.photo) {
      FullScreenImageViewer.show(
        context,
        items: [ViewerImage.of(item)],
        tag: 'chat_${item.id}',
      );
      return;
    }

    FullScreenVideoViewer.show(
      context,
      videoPath: item.localPath,
      fileId: item.fileId,
      thumbnailPath: resolveMediaPath(
        ref,
        fileId: item.thumbnailFileId,
        rawPath: item.thumbnailUrl,
      ),
      supportsStreaming: item.supportsStreaming,
    );
  }
}

/// The downloaded file if present, otherwise the minithumbnail, otherwise a
/// plain placeholder.
class _Frame extends StatelessWidget {
  final String? path;
  final String? minithumbnail;

  const _Frame({required this.path, required this.minithumbnail});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholder = ColoredBox(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant,
    );

    if (path != null && path!.isNotEmpty && File(path!).existsSync()) {
      return Image.file(
        File(path!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    }

    final blur = minithumbnail;
    if (blur != null && blur.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(blur),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder,
        );
      } on FormatException {
        return placeholder;
      }
    }

    return placeholder;
  }
}

/// The frosted cover over a spoiler.
class BackdropBlur extends StatelessWidget {
  final Widget child;
  const BackdropBlur({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: child,
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final int seconds;
  const _DurationChip({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        TimeUtils.formatDuration(seconds),
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}
