import 'dart:convert';
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

  const PostMediaGrid({super.key, required this.media, this.post});

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
      final items = visualItems.take(4).toList();

      children.add(
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: borderColor,
                width: AppSpacing.mediaBorderWidth,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.mediaRadius - 1),
              child: _buildGrid(context, items, visualItems, borderColor),
            ),
          ),
        ),
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

  Widget _buildGrid(
    BuildContext context,
    List<MediaItem> items,
    List<MediaItem> allVisual,
    Color borderColor,
  ) {
    switch (items.length) {
      case 1:
        return _buildSingleMedia(context, items[0], allVisual);
      case 2:
        return _buildTwoMedia(context, items, allVisual);
      case 3:
        return _buildThreeMedia(context, items, allVisual);
      default:
        return _buildFourMedia(context, items, allVisual);
    }
  }

  Widget _buildSingleMedia(
    BuildContext context,
    MediaItem item,
    List<MediaItem> allVisual,
  ) {
    return AspectRatio(
      aspectRatio: item.width > 0 && item.height > 0
          ? (item.width / item.height).clamp(0.5, 2.0)
          : 16 / 9,
      child: _MediaTile(item: item, index: 0, allMedia: allVisual, post: post),
    );
  }

  Widget _buildTwoMedia(
    BuildContext context,
    List<MediaItem> items,
    List<MediaItem> allVisual,
  ) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Row(
        children: [
          Expanded(
            child: _MediaTile(
              item: items[0],
              index: 0,
              allMedia: allVisual,
              post: post,
            ),
          ),
          const SizedBox(width: AppSpacing.mediaGap),
          Expanded(
            child: _MediaTile(
              item: items[1],
              index: 1,
              allMedia: allVisual,
              post: post,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeMedia(
    BuildContext context,
    List<MediaItem> items,
    List<MediaItem> allVisual,
  ) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Row(
        children: [
          Expanded(
            child: _MediaTile(
              item: items[0],
              index: 0,
              allMedia: allVisual,
              post: post,
            ),
          ),
          const SizedBox(width: AppSpacing.mediaGap),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _MediaTile(
                    item: items[1],
                    index: 1,
                    allMedia: allVisual,
                    post: post,
                  ),
                ),
                const SizedBox(height: AppSpacing.mediaGap),
                Expanded(
                  child: _MediaTile(
                    item: items[2],
                    index: 2,
                    allMedia: allVisual,
                    post: post,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFourMedia(
    BuildContext context,
    List<MediaItem> items,
    List<MediaItem> allVisual,
  ) {
    final hasMore = allVisual.length > 4;
    final extraCount = hasMore ? (allVisual.length - 3) : null;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MediaTile(
                    item: items[0],
                    index: 0,
                    allMedia: allVisual,
                    post: post,
                  ),
                ),
                const SizedBox(width: AppSpacing.mediaGap),
                Expanded(
                  child: _MediaTile(
                    item: items[1],
                    index: 1,
                    allMedia: allVisual,
                    post: post,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.mediaGap),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MediaTile(
                    item: items[2],
                    index: 2,
                    allMedia: allVisual,
                    post: post,
                  ),
                ),
                const SizedBox(width: AppSpacing.mediaGap),
                Expanded(
                  child: _MediaTile(
                    item: items[3],
                    index: 3,
                    allMedia: allVisual,
                    post: post,
                    extraCount: extraCount,
                  ),
                ),
              ],
            ),
          ),
        ],
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
  final int? extraCount;

  const _MediaTile({
    required this.item,
    required this.index,
    required this.allMedia,
    this.post,
    this.extraCount,
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
    final heroTag = 'media_${item.id}_$index';

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

    Widget contentWidget;

    if (item.type == MediaType.sticker) {
      contentWidget = Center(child: StickerTile(item: item));
    } else if (item.type == MediaType.gif && isDownloaded) {
      contentWidget = _GifVideoPlayerTile(path: resolvedPath);
    } else if (isDownloaded) {
      contentWidget = Hero(
        tag: heroTag,
        child: Image.file(
          File(resolvedPath),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholder(bgColor, iconColor),
        ),
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
      Widget placeholderWidget;
      if (item.minithumbnail != null) {
        try {
          final bytes = base64Decode(item.minithumbnail!);
          placeholderWidget = Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        } catch (_) {
          placeholderWidget = _buildPlaceholder(bgColor, iconColor);
        }
      } else {
        placeholderWidget = _buildPlaceholder(bgColor, iconColor);
      }

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
            const Center(child: _TapToLoadBadge()),
        ],
      );
    }

    if (extraCount != null && extraCount! > 0) {
      contentWidget = Stack(
        fit: StackFit.expand,
        children: [
          contentWidget,
          Container(
            color: Colors.black.withValues(alpha: 0.55),
            child: Center(
              child: Text(
                '+$extraCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          child: KeyedSubtree(
            key: ValueKey(
              isDownloaded ? 'downloaded_$resolvedPath' : 'loading_${item.id}',
            ),
            child: contentWidget,
          ),
        ),
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
  const _GifVideoPlayerTile({required this.path});

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
    if (_controller != null && _controller!.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
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
    return Container(
      color: Colors.black26,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }
}

/// Tap-to-load badge, shown when photo auto-download is off.
class _TapToLoadBadge extends StatelessWidget {
  const _TapToLoadBadge();

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
