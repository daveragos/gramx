import 'dart:io';

import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';

/// What is attached to the post being written, with a way to remove each.
/// A row, since order matters: the first item carries an album's caption.
class ComposeAttachmentStrip extends StatelessWidget {
  final List<ComposeAttachment> attachments;
  final ValueChanged<int> onRemove;

  static const double tileHeight = 180;

  const ComposeAttachmentStrip({
    super.key,
    required this.attachments,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: tileHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.postPadding),
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) => _AttachmentTile(
          attachment: attachments[index],
          index: index,
          total: attachments.length,
          onRemove: () => onRemove(index),
        ),
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final ComposeAttachment attachment;
  final int index;
  final int total;
  final VoidCallback onRemove;

  const _AttachmentTile({
    required this.attachment,
    required this.index,
    required this.total,
    required this.onRemove,
  });

  /// Tile width from the file's aspect ratio, clamped so panoramas and tall
  /// photos stay usable. Unmeasured files are square; see
  /// [ComposeAttachment.hasUnknownSize].
  double get _width {
    if (attachment.hasUnknownSize) return ComposeAttachmentStrip.tileHeight;
    final ratio = attachment.width / attachment.height;
    return (ComposeAttachmentStrip.tileHeight * ratio).clamp(
      ComposeAttachmentStrip.tileHeight * 0.55,
      ComposeAttachmentStrip.tileHeight * 1.8,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final kindLabel = attachment.isPhoto
        ? AppStrings.mediaPhoto
        : AppStrings.mediaVideo;

    return Semantics(
      label: AppStrings.mediaPosition(kindLabel, index + 1, total),
      child: SizedBox(
        width: _width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(
                    color: borderColor,
                    width: AppSpacing.mediaBorderWidth,
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
                ),
                child: attachment.isPhoto
                    ? Image.file(
                        File(attachment.path),
                        fit: BoxFit.cover,
                        // An unreadable file still uploads; only the preview
                        // is missing.
                        errorBuilder: (_, _, _) => const _VideoFace(),
                      )
                    : const _VideoFace(),
              ),
            ),
            if (attachment.isVideo && attachment.durationSeconds > 0)
              Positioned(
                left: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: _MediaChip(
                  child: Text(
                    TimeUtils.formatDuration(attachment.durationSeconds),
                    style: AppTypography.actionCount(color: Colors.white),
                  ),
                ),
              ),
            Positioned(
              top: AppSpacing.xs,
              right: AppSpacing.xs,
              child: _MediaButton(
                onTap: onRemove,
                tooltip: AppStrings.composeRemoveAttachment,
                child: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The play badge on a video preview, shown instead of a rendered frame.
class _VideoFace extends StatelessWidget {
  const _VideoFace();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.play_circle_outline_rounded,
        size: 44,
        color: Colors.white70,
      ),
    );
  }
}

/// A dark rounded chip over media, used for the duration.
class _MediaChip extends StatelessWidget {
  final Widget child;

  const _MediaChip({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: child,
      ),
    );
  }
}

/// The round button over media that removes an attachment.
class _MediaButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final String tooltip;

  const _MediaButton({
    required this.child,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        iconSize: 18,
        padding: const EdgeInsets.all(AppSpacing.xs),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        icon: child,
      ),
    );
  }
}
