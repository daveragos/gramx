import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/features/feed/presentation/inline_player_budget.dart';
import 'package:gramx/features/settings/data/settings_store.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/presentation/widgets/full_screen_image_viewer.dart';
import 'package:gramx/features/feed/presentation/widgets/full_screen_video_viewer.dart';
import 'package:gramx/features/feed/presentation/widgets/post_document_card.dart';
import 'package:gramx/features/feed/presentation/widgets/post_audio_player.dart';
import 'package:gramx/features/feed/presentation/widgets/sticker_tile.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

class PostMediaGrid extends StatelessWidget {
  final List<MediaItem> media;

  const PostMediaGrid({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    final docOrAudioItems = media.where((m) =>
      m.type == MediaType.document ||
      m.type == MediaType.audio ||
      m.type == MediaType.voice
    ).toList();

    final visualItems = media.where((m) =>
      m.type == MediaType.photo ||
      m.type == MediaType.video ||
      m.type == MediaType.gif ||
      m.type == MediaType.sticker
    ).toList();

    final children = <Widget>[];

    // Build document or audio widgets
    for (final item in docOrAudioItems) {
      if (item.type == MediaType.document) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: PostDocumentCard(item: item),
        ));
      } else if (item.type == MediaType.audio || item.type == MediaType.voice) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: PostAudioPlayer(item: item),
        ));
      }
    }

    // Build visual media grid if present
    if (visualItems.isNotEmpty) {
      final borderColor = Theme.of(context).dividerTheme.color ?? AppColors.darkBorder;
      final items = visualItems.take(4).toList();

      children.add(
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: AppSpacing.mediaBorderWidth),
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
      BuildContext context, List<MediaItem> items, List<MediaItem> allVisual, Color borderColor) {
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

  Widget _buildSingleMedia(BuildContext context, MediaItem item, List<MediaItem> allVisual) {
    return AspectRatio(
      aspectRatio: item.width > 0 && item.height > 0
          ? (item.width / item.height).clamp(0.5, 2.0)
          : 16 / 9,
      child: _MediaTile(item: item, index: 0, allMedia: allVisual),
    );
  }

  Widget _buildTwoMedia(BuildContext context, List<MediaItem> items, List<MediaItem> allVisual) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Row(
        children: [
          Expanded(child: _MediaTile(item: items[0], index: 0, allMedia: allVisual)),
          const SizedBox(width: AppSpacing.mediaGap),
          Expanded(child: _MediaTile(item: items[1], index: 1, allMedia: allVisual)),
        ],
      ),
    );
  }

  Widget _buildThreeMedia(BuildContext context, List<MediaItem> items, List<MediaItem> allVisual) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Row(
        children: [
          Expanded(child: _MediaTile(item: items[0], index: 0, allMedia: allVisual)),
          const SizedBox(width: AppSpacing.mediaGap),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _MediaTile(item: items[1], index: 1, allMedia: allVisual)),
                const SizedBox(height: AppSpacing.mediaGap),
                Expanded(child: _MediaTile(item: items[2], index: 2, allMedia: allVisual)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFourMedia(BuildContext context, List<MediaItem> items, List<MediaItem> allVisual) {
    final hasMore = allVisual.length > 4;
    final extraCount = hasMore ? (allVisual.length - 3) : null;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _MediaTile(item: items[0], index: 0, allMedia: allVisual)),
                const SizedBox(width: AppSpacing.mediaGap),
                Expanded(child: _MediaTile(item: items[1], index: 1, allMedia: allVisual)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.mediaGap),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _MediaTile(item: items[2], index: 2, allMedia: allVisual)),
                const SizedBox(width: AppSpacing.mediaGap),
                Expanded(
                  child: _MediaTile(
                    item: items[3],
                    index: 3,
                    allMedia: allVisual,
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

class _MediaTile extends ConsumerWidget {
  final MediaItem item;
  final int index;
  final List<MediaItem> allMedia;
  final int? extraCount;

  const _MediaTile({
    required this.item,
    required this.index,
    required this.allMedia,
    this.extraCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant;
    final iconColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final heroTag = 'media_${item.id}_$index';

    final int? trackFileId = item.type == MediaType.video
        ? (item.thumbnailFileId ?? item.fileId)
        : item.fileId;

    FileDownloadProgressState? downloadState;
    if (trackFileId != null && trackFileId != 0) {
      downloadState = ref.watch(fileDownloadProgressProvider(trackFileId)).value;
    }

    final String? resolvedPath = downloadState?.localPath ?? _tryResolvePath(item);
    final isDownloaded = resolvedPath != null && resolvedPath.isNotEmpty && File(resolvedPath).existsSync();

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
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(bgColor, iconColor),
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
            ),
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

    return GestureDetector(
      onTap: () => _handleTap(context, ref, resolvedPath, heroTag),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: KeyedSubtree(
          key: ValueKey(isDownloaded ? 'downloaded_$resolvedPath' : 'loading_${item.id}'),
          child: contentWidget,
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

  void _handleTap(BuildContext context, WidgetRef ref, String? resolvedPath, String heroTag) {
    if (item.type == MediaType.video || item.type == MediaType.gif) {
      String? videoPath;
      if (item.fileId != null && item.fileId != 0) {
        final videoFileState = ref.read(fileDownloadProvider(item.fileId!));
        videoPath = videoFileState.value;
      }
      videoPath ??= item.localPath;

      if (videoPath != null && videoPath.isNotEmpty) {
        FullScreenVideoViewer.show(context, videoPath: videoPath);
      } else {
        if (item.fileId != null && item.fileId != 0) {
          ref.read(syncServiceProvider).downloadFileWithPriority(item.fileId!, priority: 32);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Downloading animation/video... Please wait.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      final imageItems = allMedia
          .where((m) => m.type == MediaType.photo)
          .map((m) {
            final downloadedPath = m.fileId != null && m.fileId != 0
                ? ref.read(fileDownloadProgressProvider(m.fileId!)).value?.localPath
                : null;
            return downloadedPath ?? m.localPath ?? m.url;
          })
          .where((p) => p != null && p.isNotEmpty)
          .cast<String>()
          .toList();

      final initialIndex = allMedia.indexOf(item);

      if (imageItems.isNotEmpty) {
        FullScreenImageViewer.show(
          context,
          items: imageItems,
          initialIndex: initialIndex >= 0 && initialIndex < imageItems.length ? initialIndex : 0,
          tag: heroTag,
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
  /// A tile must be at least this visible before it is worth a decoder.
  static const double _playThreshold = 0.5;

  VideoPlayerController? _controller;
  bool _holdsBudget = false;
  bool _starting = false;

  @override
  void dispose() {
    _releaseBudget();
    _controller?.dispose();
    super.dispose();
  }

  void _releaseBudget() {
    if (!_holdsBudget) return;
    _holdsBudget = false;
    ref.read(inlinePlayerBudgetProvider).release();
  }

  /// Starts playing only when the tile is genuinely on screen, auto-play is on,
  /// and the shared budget has room.
  Future<void> _start() async {
    if (_controller != null || _starting) return;
    if (!ref.read(autoPlayEnabledProvider)) return;

    final budget = ref.read(inlinePlayerBudgetProvider);
    if (!budget.tryAcquire()) return;
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

  /// Tears the player down when the tile scrolls away, freeing its slot for
  /// whatever the user is actually looking at.
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
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
        ),
      ),
    );
  }
}
