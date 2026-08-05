import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/presentation/widgets/full_screen_image_viewer.dart';
import 'package:gramx/features/feed/presentation/widgets/full_screen_video_viewer.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

class PostMediaGrid extends StatelessWidget {
  final List<MediaItem> media;

  const PostMediaGrid({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    final borderColor =
        Theme.of(context).dividerTheme.color ?? AppColors.darkBorder;
    final items = media.take(4).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
              color: borderColor, width: AppSpacing.mediaBorderWidth),
          borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.mediaRadius - 1),
          child: _buildGrid(context, items, borderColor),
        ),
      ),
    );
  }

  Widget _buildGrid(
      BuildContext context, List<MediaItem> items, Color borderColor) {
    switch (items.length) {
      case 1:
        return _buildSingleMedia(context, items[0]);
      case 2:
        return _buildTwoMedia(context, items);
      case 3:
        return _buildThreeMedia(context, items);
      default:
        return _buildFourMedia(context, items);
    }
  }

  Widget _buildSingleMedia(BuildContext context, MediaItem item) {
    return AspectRatio(
      aspectRatio: item.width > 0 && item.height > 0
          ? (item.width / item.height).clamp(0.5, 2.0)
          : 16 / 9,
      child: _MediaTile(item: item, index: 0),
    );
  }

  Widget _buildTwoMedia(BuildContext context, List<MediaItem> items) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Row(
        children: [
          Expanded(child: _MediaTile(item: items[0], index: 0)),
          const SizedBox(width: AppSpacing.mediaGap),
          Expanded(child: _MediaTile(item: items[1], index: 1)),
        ],
      ),
    );
  }

  Widget _buildThreeMedia(BuildContext context, List<MediaItem> items) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Row(
        children: [
          Expanded(child: _MediaTile(item: items[0], index: 0)),
          const SizedBox(width: AppSpacing.mediaGap),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _MediaTile(item: items[1], index: 1)),
                const SizedBox(height: AppSpacing.mediaGap),
                Expanded(child: _MediaTile(item: items[2], index: 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFourMedia(BuildContext context, List<MediaItem> items) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _MediaTile(item: items[0], index: 0)),
                const SizedBox(width: AppSpacing.mediaGap),
                Expanded(child: _MediaTile(item: items[1], index: 1)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.mediaGap),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _MediaTile(item: items[2], index: 2)),
                const SizedBox(width: AppSpacing.mediaGap),
                Expanded(child: _MediaTile(item: items[3], index: 3)),
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

  const _MediaTile({required this.item, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant;
    final iconColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final heroTag = 'media_${item.id}_$index';

    // Determine which fileId to track reactively
    final int? trackFileId = item.type == MediaType.video
        ? item.thumbnailFileId  // For videos, track the thumbnail
        : item.fileId;          // For photos/gifs, track the main file

    // Use reactive file download provider if we have a fileId
    String? resolvedPath;

    if (trackFileId != null && trackFileId != 0) {
      final fileState = ref.watch(fileDownloadProvider(trackFileId));
      resolvedPath = fileState.value;
    } else {
      // Fallback: try localPath or url directly
      resolvedPath = _tryResolvePath(item);
    }

    Widget contentWidget;

    if (resolvedPath != null && resolvedPath.isNotEmpty) {
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
    } else if (item.minithumbnail != null) {
      // Progressive loading: show blurred minithumbnail while downloading
      try {
        final bytes = base64Decode(item.minithumbnail!);
        contentWidget = Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            // Slight blur overlay to indicate loading
            Container(
              color: Colors.black.withValues(alpha: 0.1),
            ),
            if (item.type == MediaType.video)
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
      } catch (_) {
        contentWidget = _buildPlaceholder(bgColor, iconColor);
      }
    } else {
      contentWidget = _buildPlaceholder(bgColor, iconColor);
    }

    return GestureDetector(
      onTap: () => _handleTap(context, ref, resolvedPath, heroTag),
      child: contentWidget,
    );
  }

  Widget _buildPlaceholder(Color bgColor, Color iconColor) {
    return Container(
      color: bgColor,
      child: Center(
        child: Icon(
          item.type == MediaType.video
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

  /// Try to resolve a file path without reactive provider (fallback).
  String? _tryResolvePath(MediaItem item) {
    if (item.localPath != null && item.localPath!.isNotEmpty) {
      return item.localPath;
    }
    return null;
  }

  void _handleTap(
      BuildContext context, WidgetRef ref, String? resolvedPath, String heroTag) {
    if (item.type == MediaType.video) {
      // For video, check the main video file (not thumbnail)
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
            content: Text('Prioritizing video download... Please wait a moment.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (resolvedPath != null && resolvedPath.isNotEmpty) {
        FullScreenImageViewer.show(
          context,
          imagePath: resolvedPath,
          tag: heroTag,
        );
      }
    }
  }
}
