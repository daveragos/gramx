import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// The picture, video, file or sticker inside a message bubble.
///
/// Deliberately *not* the feed's `PostMediaGrid`. A post's media is a grid of
/// up to four tiles with a `+N` badge because a channel post is a broadcast
/// with an album; a message is one thing at a time, constrained by the bubble's
/// width, and it keeps its own aspect ratio. Sharing the grid would mean one
/// widget with two layout modes and a flag deciding which — and the audio,
/// document and sticker renderers, which *are* shared, take a bare [MediaItem]
/// already.
class BubbleMedia extends ConsumerWidget {
  final MediaItem item;

  /// The bubble's usable width. The media never exceeds it, and a portrait
  /// photo is capped by [maxHeight] so one picture cannot fill the screen.
  final double maxWidth;

  /// Whether the media is the whole message, with no text under it. Media-only
  /// bubbles round all four corners; a captioned one squares the bottom two so
  /// the picture and the words read as one object.
  final bool isAlone;

  const BubbleMedia({
    super.key,
    required this.item,
    required this.maxWidth,
    this.isAlone = true,
  });

  /// Tallest a picture may be drawn. A 9:16 photo at full bubble width is most
  /// of a phone screen, which pushes the conversation off it.
  static const double maxHeight = 320;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (item.type) {
      case MediaType.sticker:
        // A sticker is the message: no bubble, no crop, its own size.
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

/// A photo, video or GIF: something with a frame to show and a tap that opens
/// it full screen.
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

    // A video shows its poster frame; a photo shows itself. Both fall back to
    // the minithumbnail, which travels inside the message and is therefore
    // there before any download is.
    final path = resolveMediaPath(
      ref,
      fileId: isVideo ? item.thumbnailFileId : item.fileId,
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
                // Telegram's "cover this until tapped" flag, set by the sender.
                // Honouring it is the whole point of the flag existing.
                BackdropBlur(child: const SizedBox.expand()),
              if (isVideo) const _PlayBadge(),
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

  /// The drawn size: the media's own aspect ratio, capped by the bubble's width
  /// and by [BubbleMedia.maxHeight]. Falls back to 4:3 when Telegram gave no
  /// dimensions, which beats a zero-height box.
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

/// What is actually painted: the downloaded file if it has landed, otherwise
/// Telegram's inline blur, otherwise a plain placeholder.
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
        // A malformed minithumbnail is a bad byte from the server, not a
        // reason to lose the bubble.
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
