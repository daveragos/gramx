import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/guest/data/guest_media_cache.dart';
import 'package:gramx/core/widgets/media_path.dart';
import 'package:gramx/core/widgets/minithumbnail.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/features/feed/presentation/inline_player_budget.dart';
import 'package:gramx/features/settings/data/settings_store.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/full_screen_image_viewer.dart';
import 'package:gramx/features/feed/presentation/widgets/full_screen_video_viewer.dart';
import 'package:gramx/features/feed/presentation/widgets/post_document_card.dart';
import 'package:gramx/features/feed/presentation/widgets/post_audio_player.dart';
import 'package:gramx/features/feed/presentation/widgets/spoiler_cover.dart';
import 'package:gramx/features/feed/presentation/widgets/sticker_tile.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

class PostMediaGrid extends StatelessWidget {
  final List<MediaItem> media;

  /// The post this media belongs to, passed to the full-screen viewer.
  final Post? post;

  /// A height limit for the photos and videos only. File and audio rows
  /// always get their full height; capping the whole grid let them overflow
  /// onto whatever came next.
  final double? maxVisualHeight;

  /// How far a row of several photos may run past the right edge. The card's
  /// padding, so the row reaches the screen's edge as on X.
  final double bleed;

  const PostMediaGrid({
    super.key,
    required this.media,
    this.post,
    this.maxVisualHeight,
    this.bleed = 0,
  });

  /// A row's height, as a share of the width it starts in.
  static const double rowHeightFactor = 0.62;

  /// The widest a photo in a row gets, as a share of that width, so the next
  /// one always shows.
  static const double rowItemMaxWidthFactor = 0.88;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    final docOrAudioItems = media
        .where(
          (m) =>
              m.type == MediaType.document ||
              m.type == MediaType.audio ||
              m.type == MediaType.voice,
        )
        .toList();

    final visualItems = media
        .where(
          (m) =>
              m.type == MediaType.photo ||
              m.type == MediaType.video ||
              m.type == MediaType.gif ||
              m.type == MediaType.sticker,
        )
        .toList();

    final children = <Widget>[];

    for (final item in docOrAudioItems) {
      if (item.type == MediaType.document) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PostDocumentCard(item: item),
          ),
        );
      } else if (item.type == MediaType.audio || item.type == MediaType.voice) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PostAudioPlayer(item: item),
          ),
        );
      }
    }

    if (visualItems.isNotEmpty) {
      final borderColor =
          Theme.of(context).dividerTheme.color ?? AppColors.darkBorder;
      children.add(
        visualItems.length == 1
            ? _single(visualItems.first, borderColor)
            : _row(visualItems, borderColor),
      );
    }

    if (children.length == 1) {
      return children.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  /// One photo or video at its own shape, within limits.
  Widget _single(MediaItem item, Color borderColor) {
    final tile = _framed(
      borderColor,
      AspectRatio(
        aspectRatio: item.width > 0 && item.height > 0
            ? (item.width / item.height).clamp(0.5, 2.0)
            : 16 / 9,
        child: _MediaTile(item: item, index: 0, allMedia: [item], post: post),
      ),
    );
    if (maxVisualHeight == null) return tile;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxVisualHeight!),
      child: tile,
    );
  }

  /// Several photos and videos side by side at one height, each at its own
  /// shape, scrolling sideways. X shows every one this way rather than four
  /// and a count of the rest.
  Widget _row(List<MediaItem> items, Color borderColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var height = width * rowHeightFactor;
        if (maxVisualHeight != null && maxVisualHeight! < height) {
          height = maxVisualHeight!;
        }
        return SizedBox(
          height: height,
          // Wider than its slot by the bleed, which it paints into.
          child: OverflowBox(
            alignment: AlignmentDirectional.centerStart,
            minWidth: width + bleed,
            maxWidth: width + bleed,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsetsDirectional.only(end: bleed),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                final item = items[index];
                return SizedBox(
                  width: rowItemWidth(
                    item,
                    height: height,
                    maxWidth: width * rowItemMaxWidthFactor,
                  ),
                  child: _framed(
                    borderColor,
                    _MediaTile(
                      item: item,
                      index: index,
                      allMedia: items,
                      post: post,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// A photo's width in a row of [height]: its own shape, from half as wide
  /// as tall up to [maxWidth].
  static double rowItemWidth(
    MediaItem item, {
    required double height,
    required double maxWidth,
  }) {
    final aspect = item.width > 0 && item.height > 0
        ? item.width / item.height
        : 1.0;
    final minWidth = height * 0.5;
    return (height * aspect).clamp(
      minWidth,
      maxWidth < minWidth ? minWidth : maxWidth,
    );
  }

  /// Rounded, with a hairline edge so a dark photo doesn't melt into the page.
  Widget _framed(Color borderColor, Widget child) {
    return Container(
      foregroundDecoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
          width: AppSpacing.mediaBorderWidth,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
        child: child,
      ),
    );
  }
}

/// Screen reader description for a media tile.
String describeMedia(MediaItem item, int index, int total) {
  final kind = switch (item.type) {
    MediaType.photo => AppStrings.mediaPhoto,
    MediaType.video => AppStrings.mediaVideo,
    MediaType.gif => AppStrings.mediaGif,
    MediaType.sticker => AppStrings.mediaSticker,
    MediaType.document => item.fileName ?? AppStrings.mediaDocument,
    MediaType.audio => item.fileName ?? AppStrings.mediaAudio,
    MediaType.voice => AppStrings.mediaVoice,
  };
  return total > 1 ? AppStrings.mediaPosition(kind, index + 1, total) : kind;
}

class _MediaTile extends ConsumerWidget {
  final MediaItem item;
  final int index;
  final List<MediaItem> allMedia;
  final Post? post;

  const _MediaTile({
    required this.item,
    required this.index,
    required this.allMedia,
    this.post,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurfaceVariant;
    final iconColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    // By file id: item.id turns from a remote id into a local path once the
    // file downloads, and the tag must not change under the image.
    final heroTag =
        'media_${item.fileId != null && item.fileId != 0 ? item.fileId : item.id}_$index';

    final int? trackFileId = item.type == MediaType.video
        ? (item.thumbnailFileId ?? item.fileId)
        : item.fileId;

    // The auto-download setting applies to photos only; video and GIF
    // thumbnails are small and always load.
    final autoDownload =
        item.type != MediaType.photo ||
        ref.watch(settingsProvider.select((s) => s.autoDownloadImagesEnabled));

    FileDownloadProgressState? downloadState;
    if (trackFileId != null && trackFileId != 0) {
      // The progress provider starts a download when watched; the status
      // provider only reflects one already started.
      downloadState = autoDownload
          ? ref.watch(fileDownloadProgressProvider(trackFileId)).value
          : ref.watch(fileDownloadStatusProvider(trackFileId)).value;
    }

    // Guest media is an https URL that resolveMediaPath caches to disk.
    final String? resolvedPath =
        downloadState?.localPath ??
        _tryResolvePath(item) ??
        (trackFileId == null || trackFileId == 0
            ? resolveMediaPath(ref, rawPath: item.thumbnailUrl ?? item.url)
            : null);
    final isDownloaded =
        resolvedPath != null &&
        resolvedPath.isNotEmpty &&
        File(resolvedPath).existsSync();

    // The blurred preview stays underneath until the real image has a frame,
    // so loading never passes through an empty tile.
    final minithumbnail = Minithumbnail.provider(item.minithumbnail);
    final underlay = minithumbnail != null
        ? Image(
            image: minithumbnail,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          )
        : Container(color: bgColor);

    Widget contentWidget;

    if (item.type == MediaType.sticker) {
      contentWidget = Center(child: StickerTile(item: item));
    } else if (item.type == MediaType.gif && isDownloaded) {
      final thumbnail = item.thumbnailUrl;
      contentWidget = _GifVideoPlayerTile(
        path: resolvedPath,
        poster: thumbnail != null && File(thumbnail).existsSync()
            ? FileImage(File(thumbnail))
            : minithumbnail,
      );
    } else if (isDownloaded) {
      contentWidget = Stack(
        fit: StackFit.expand,
        children: [
          underlay,
          Hero(
            tag: heroTag,
            child: Image.file(
              File(resolvedPath),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              frameBuilder: fadeInFrame,
              errorBuilder: (context, error, stackTrace) =>
                  _buildPlaceholder(bgColor, iconColor),
            ),
          ),
        ],
      );

      if (item.type == MediaType.video) {
        contentWidget = Stack(
          fit: StackFit.expand,
          children: [
            contentWidget,
            Center(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ],
        );
      }
    } else {
      final placeholderWidget = minithumbnail != null
          ? underlay
          : _buildPlaceholder(bgColor, iconColor);

      final progress = downloadState?.progress ?? 0.0;
      final isProgressing = downloadState != null && !downloadState.isCompleted;

      contentWidget = Stack(
        fit: StackFit.expand,
        children: [
          placeholderWidget,
          Container(color: Colors.black.withValues(alpha: 0.15)),
          if (isProgressing)
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    value: progress > 0 ? progress : null,
                    strokeWidth: 3,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
            )
          else if (item.type == MediaType.video || item.type == MediaType.gif)
            Center(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white70,
                  size: 30,
                ),
              ),
            )
          else if (!autoDownload)
            const Center(child: TapToLoadBadge()),
        ],
      );
    }

    // Covered until the user taps to reveal it.
    if (item.hasSpoiler) {
      return SpoilerCover(
        label: describeMedia(item, index, allMedia.length),
        child: GestureDetector(
          onTap: () => _handleTap(context, ref, resolvedPath, heroTag),
          child: contentWidget,
        ),
      );
    }

    return Semantics(
      button: true,
      label: describeMedia(item, index, allMedia.length),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _handleTap(context, ref, resolvedPath, heroTag),
        child: contentWidget,
      ),
    );
  }

  Widget _buildPlaceholder(Color bgColor, Color iconColor) {
    return Container(
      color: bgColor,
      child: Center(
        child: Icon(
          item.type == MediaType.video || item.type == MediaType.gif
              ? Icons.play_circle_outline_rounded
              : item.type == MediaType.document
              ? Icons.insert_drive_file_outlined
              : Icons.image_outlined,
          color: iconColor,
          size: 32,
        ),
      ),
    );
  }

  String? _tryResolvePath(MediaItem item) {
    if (item.localPath != null && item.localPath!.isNotEmpty) {
      return item.localPath;
    }
    return null;
  }

  void _handleTap(
    BuildContext context,
    WidgetRef ref,
    String? resolvedPath,
    String heroTag,
  ) {
    // With auto-download off, the first tap downloads the photo instead of
    // opening the viewer.
    final needsFetch =
        item.type == MediaType.photo &&
        (resolvedPath == null || resolvedPath.isEmpty) &&
        !ref.read(settingsProvider).autoDownloadImagesEnabled;
    if (needsFetch) {
      final fileId = item.fileId;
      if (fileId != null && fileId != 0) {
        ref.read(syncServiceProvider).downloadFileWithPriority(fileId);
      }
      return;
    }

    if (item.type == MediaType.video || item.type == MediaType.gif) {
      String? videoPath;
      if (item.fileId != null && item.fileId != 0) {
        final videoFileState = ref.read(fileDownloadProvider(item.fileId!));
        videoPath = videoFileState.value;
      }
      videoPath ??= item.localPath;
      // A cached guest video, if any; otherwise the viewer fetches remoteUrl.
      videoPath ??= ref.read(guestMediaPathProvider(item.url ?? '')).value;

      // Opens even before the file lands; the viewer shows its own progress.
      FullScreenVideoViewer.show(
        context,
        videoPath: videoPath,
        fileId: item.fileId,
        thumbnailPath: item.thumbnailUrl,
        remoteUrl: item.url,
        post: post,
        supportsStreaming: item.supportsStreaming,
      );
    } else {
      final imageItems = <ViewerImage>[];
      // Tracked while building, since the list is filtered and indices in
      // `allMedia` don't match.
      var initialIndex = 0;

      for (final m in allMedia) {
        if (m.type != MediaType.photo) continue;
        final downloadedPath = m.fileId != null && m.fileId != 0
            ? ref.read(fileDownloadProgressProvider(m.fileId!)).value?.localPath
            : null;
        // Carries the file id so the viewer can wait for a pending download.
        final image = ViewerImage.of(m, downloadedPath: downloadedPath);
        if (!image.hasSource) continue;
        if (identical(m, item)) initialIndex = imageItems.length;
        imageItems.add(image);
      }

      if (imageItems.isNotEmpty) {
        FullScreenImageViewer.show(
          context,
          items: imageItems,
          initialIndex: initialIndex,
          tag: heroTag,
          post: post,
        );
      }
    }
  }
}

class _GifVideoPlayerTile extends ConsumerStatefulWidget {
  final String path;

  /// Shown until the animation plays, and when it can't: off screen, with
  /// autoplay off, or while other players use the budget.
  final ImageProvider? poster;

  const _GifVideoPlayerTile({required this.path, this.poster});

  @override
  ConsumerState<_GifVideoPlayerTile> createState() =>
      _GifVideoPlayerTileState();
}

class _GifVideoPlayerTileState extends ConsumerState<_GifVideoPlayerTile> {
  /// Visible fraction needed before the tile starts playing.
  static const double _playThreshold = 0.5;

  VideoPlayerController? _controller;
  bool _holdsBudget = false;
  bool _starting = false;

  /// Read up front: dispose, which releases a held slot, may not use ref.
  late final InlinePlayerBudget _budget;

  @override
  void initState() {
    super.initState();
    _budget = ref.read(inlinePlayerBudgetProvider);
  }

  @override
  void dispose() {
    _releaseBudget();
    _controller?.dispose();
    super.dispose();
  }

  void _releaseBudget() {
    if (!_holdsBudget) return;
    _holdsBudget = false;
    _budget.release();
  }

  /// Starts playing only when the tile is on screen, auto-play is on, and the
  /// shared budget has room.
  Future<void> _start() async {
    if (_controller != null || _starting) return;
    if (!ref.read(autoPlayEnabledProvider)) return;

    if (!_budget.tryAcquire()) return;
    _holdsBudget = true;
    _starting = true;

    try {
      final controller = VideoPlayerController.file(File(widget.path));
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0.0);
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        _releaseBudget();
        return;
      }
      setState(() => _controller = controller);
    } catch (e) {
      debugPrint('[GifTile] Error initializing video player: $e');
      _releaseBudget();
    } finally {
      _starting = false;
    }
  }

  /// Disposes the player when the tile scrolls away, freeing its slot.
  Future<void> _stop() async {
    final controller = _controller;
    if (controller == null) {
      _releaseBudget();
      return;
    }
    if (mounted) setState(() => _controller = null);
    await controller.dispose();
    _releaseBudget();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('gif-${widget.path}'),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        if (info.visibleFraction >= _playThreshold) {
          _start();
        } else {
          _stop();
        }
      },
      child: _buildTile(context),
    );
  }

  Widget _buildTile(BuildContext context) {
    final controller = _controller;
    final playing = controller != null && controller.value.isInitialized;
    final poster = widget.poster;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (poster != null)
          Image(
            image: poster,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          )
        else
          Container(color: Colors.black26),
        if (playing)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'GIF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tap-to-load badge, shown when photo auto-download is off.
class TapToLoadBadge extends StatelessWidget {
  const TapToLoadBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.download_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            AppStrings.mediaTapToLoad,
            style: AppTypography.actionCount(
              color: Colors.white,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
