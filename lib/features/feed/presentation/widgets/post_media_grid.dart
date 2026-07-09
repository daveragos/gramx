import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/features/feed/domain/media_item.dart';

class PostMediaGrid extends StatelessWidget {
  final List<MediaItem> media;

  const PostMediaGrid({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    final borderColor = Theme.of(context).dividerTheme.color ?? AppColors.darkBorder;
    final items = media.take(4).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: AppSpacing.mediaBorderWidth),
          borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.mediaRadius - 1),
          child: _buildGrid(items, borderColor),
        ),
      ),
    );
  }

  Widget _buildGrid(List<MediaItem> items, Color borderColor) {
    switch (items.length) {
      case 1:
        return _buildSingleMedia(items[0]);
      case 2:
        return _buildTwoMedia(items);
      case 3:
        return _buildThreeMedia(items);
      default:
        return _buildFourMedia(items);
    }
  }

  Widget _buildSingleMedia(MediaItem item) {
    return AspectRatio(
      aspectRatio: item.width > 0 && item.height > 0
          ? (item.width / item.height).clamp(0.5, 2.0)
          : 16 / 9,
      child: _MediaPlaceholder(item: item),
    );
  }

  Widget _buildTwoMedia(List<MediaItem> items) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Row(
        children: [
          Expanded(child: _MediaPlaceholder(item: items[0])),
          const SizedBox(width: AppSpacing.mediaGap),
          Expanded(child: _MediaPlaceholder(item: items[1])),
        ],
      ),
    );
  }

  Widget _buildThreeMedia(List<MediaItem> items) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Row(
        children: [
          Expanded(child: _MediaPlaceholder(item: items[0])),
          const SizedBox(width: AppSpacing.mediaGap),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _MediaPlaceholder(item: items[1])),
                const SizedBox(height: AppSpacing.mediaGap),
                Expanded(child: _MediaPlaceholder(item: items[2])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFourMedia(List<MediaItem> items) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _MediaPlaceholder(item: items[0])),
                const SizedBox(width: AppSpacing.mediaGap),
                Expanded(child: _MediaPlaceholder(item: items[1])),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.mediaGap),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _MediaPlaceholder(item: items[2])),
                const SizedBox(width: AppSpacing.mediaGap),
                Expanded(child: _MediaPlaceholder(item: items[3])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  final MediaItem item;

  const _MediaPlaceholder({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant;
    final iconColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    Widget? mediaWidget;

    // 1. If it's a photo, try to load the local photo
    if (item.type == MediaType.photo) {
      if (item.localPath != null && item.localPath!.startsWith('/')) {
        final file = File(item.localPath!);
        if (file.existsSync()) {
          mediaWidget = Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        }
      }
    } 
    // 2. If it's a video or gif, try to load the local thumbnail
    else if (item.type == MediaType.video || item.type == MediaType.gif) {
      String? path;
      if (item.thumbnailUrl != null && item.thumbnailUrl!.startsWith('/')) {
        path = item.thumbnailUrl;
      } else if (item.localPath != null && item.localPath!.startsWith('/')) {
        path = item.localPath;
      }
      
      if (path != null) {
        final file = File(path);
        if (file.existsSync()) {
          mediaWidget = Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                file,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
              if (item.type == MediaType.video)
                Center(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
            ],
          );
        }
      }
    }

    if (mediaWidget != null) {
      return mediaWidget;
    }

    return Container(
      color: bgColor,
      child: Center(
        child: Icon(
          item.type == MediaType.video ? Icons.play_circle_outline
              : item.type == MediaType.document ? Icons.insert_drive_file_outlined
              : Icons.image_outlined,
          color: iconColor,
          size: 32,
        ),
      ),
    );
  }
}
