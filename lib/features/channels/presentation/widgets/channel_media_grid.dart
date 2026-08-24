import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

/// The Media tab: a square grid of every photo and video in the channel.
///
/// A grid rather than a column of cards, because a column of cards is what the
/// Posts tab already is — the reason to have this tab at all is seeing a
/// channel's pictures at a glance.
///
/// Tapping a tile opens the post. Not the viewer directly: a picture pulled out
/// of a channel's history without its caption is often meaningless, and the
/// post's own grid opens the viewer from there.
class ChannelMediaGrid extends StatelessWidget {
  final List<Post> posts;

  const ChannelMediaGrid({super.key, required this.posts});

  /// Flattens posts to their visual media, keeping the post each tile came
  /// from so a tap knows where to go. An album is several tiles, as it should
  /// be — it is several pictures.
  static List<({Post post, MediaItem item})> tilesFor(List<Post> posts) {
    return [
      for (final post in posts)
        for (final item in post.media)
          if (item.type == MediaType.photo ||
              item.type == MediaType.video ||
              item.type == MediaType.gif)
            (post: post, item: item),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tiles = tilesFor(posts);

    return SliverPadding(
      padding: const EdgeInsets.all(AppSpacing.mediaGap),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppSpacing.mediaGap,
          crossAxisSpacing: AppSpacing.mediaGap,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _MediaTile(tile: tiles[index]),
          childCount: tiles.length,
        ),
      ),
    );
  }
}

class _MediaTile extends ConsumerWidget {
  final ({Post post, MediaItem item}) tile;

  const _MediaTile({required this.tile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = tile.item;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholder =
        isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade200;

    // Thumbnail first: a grid of full-resolution photos is a lot of decoding
    // for tiles this size, and the minithumbnail covers the gap before the
    // file lands.
    final fileId = item.thumbnailFileId ?? item.fileId;
    String? path;
    if (fileId != null && fileId != 0) {
      path = ref.watch(fileDownloadProvider(fileId)).value;
    } else if (item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty) {
      path = item.thumbnailUrl;
    }

    final exists = path != null && path.isNotEmpty
        ? ref.watch(fileExistsProvider(path)).value ?? false
        : false;

    Widget image;
    if (exists) {
      image = Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => ColoredBox(color: placeholder),
      );
    } else if (item.minithumbnail != null && item.minithumbnail!.isNotEmpty) {
      image = Image.memory(
        base64Decode(item.minithumbnail!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => ColoredBox(color: placeholder),
      );
    } else {
      image = ColoredBox(color: placeholder);
    }

    final isVideo = item.type == MediaType.video || item.type == MediaType.gif;

    return Semantics(
      button: true,
      label: isVideo
          ? AppStrings.a11yChannelVideoTile
          : AppStrings.a11yChannelPhotoTile,
      child: GestureDetector(
        onTap: () => context.push('/post/${tile.post.id}'),
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (isVideo)
              Positioned(
                right: 4,
                bottom: 4,
                child: _VideoBadge(duration: item.duration),
              ),
          ],
        ),
      ),
    );
  }
}

/// Duration on a scrim, so it stays readable over a bright frame.
class _VideoBadge extends StatelessWidget {
  final int duration;

  const _VideoBadge({required this.duration});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white),
          if (duration > 0) ...[
            const SizedBox(width: 2),
            Text(
              TimeUtils.formatDuration(duration),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
