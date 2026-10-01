import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/media_path.dart';
import 'package:gramx/features/compose/domain/compose_remote_media.dart';

/// The sticker or GIF the post is carrying, with a way to remove it. Always
/// one tile, since Telegram can't put either in an album.
class ComposeRemotePreview extends ConsumerWidget {
  final ComposeRemoteMedia media;
  final VoidCallback onRemove;

  /// Roughly the size a sticker renders at in the feed.
  static const double _extent = 160;

  const ComposeRemotePreview({
    super.key,
    required this.media,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    // The thumbnail is always WEBP or JPEG, so it renders whatever format the
    // sticker is in (TGS and WebM would draw nothing). See StickerTile.
    final path = resolveMediaPath(
      ref,
      fileId: media.thumbnailFileId ?? media.fileId,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.postPadding),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: _extent,
          height: _extent,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: borderColor,
                      width: AppSpacing.mediaBorderWidth,
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: path == null || path.isEmpty
                        ? const SizedBox.shrink()
                        : Image.file(
                            File(path),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                  ),
                ),
              ),
              Positioned(
                top: AppSpacing.xs,
                right: AppSpacing.xs,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    onPressed: onRemove,
                    tooltip: media.isSticker
                        ? AppStrings.composeRemoveSticker
                        : AppStrings.composeRemoveGif,
                    iconSize: 18,
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
