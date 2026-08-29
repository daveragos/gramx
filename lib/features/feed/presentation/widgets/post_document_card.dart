import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/navigation/open_with.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

class PostDocumentCard extends ConsumerWidget {
  final MediaItem item;

  const PostDocumentCard({super.key, required this.item});

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return AppStrings.mediaDocument;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Through the shared helper, so a document row, the image viewer and the
  /// video viewer all hand files out the same way and report the same two
  /// distinct failures.
  Future<void> _openFile(BuildContext context, String path) =>
      openWithSystemApp(context, path);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurfaceVariant;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final fileId = item.fileId;
    String? resolvedPath;
    FileDownloadProgressState? downloadState;

    if (fileId != null && fileId != 0) {
      downloadState = ref.watch(fileDownloadStatusProvider(fileId)).value;
    }
    resolvedPath = downloadState?.localPath ?? item.localPath;

    final isDownloaded =
        resolvedPath != null &&
        resolvedPath.isNotEmpty &&
        File(resolvedPath).existsSync();
    final isDownloading =
        downloadState != null &&
        !downloadState.isCompleted &&
        (downloadState.progress > 0 || downloadState.downloadedSize > 0);
    final fileName = item.fileName ?? AppStrings.documentFallbackName;
    final fileSizeText = _formatFileSize(item.fileSize);
    final progress = downloadState?.progress ?? 0.0;

    return InkWell(
      onTap: () {
        if (isDownloaded) {
          _openFile(context, resolvedPath!);
        } else if (fileId != null && fileId != 0) {
          // No snackbar. The ring on the left fills as the bytes arrive and
          // the subtitle counts up beside it, which is the same information
          // in the place the reader is already looking — and it does not cover
          // the row it is describing.
          ref
              .read(syncServiceProvider)
              .downloadFileWithPriority(fileId, priority: 32);
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: isDownloading
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(
                        value: progress > 0 ? progress : null,
                        strokeWidth: 3,
                        color: AppColors.accent,
                      ),
                    )
                  : Icon(
                      isDownloaded
                          ? Icons.insert_drive_file_rounded
                          : Icons.download_rounded,
                      color: AppColors.accent,
                      size: 22,
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: AppTypography.body(
                      color: primaryColor,
                    ).copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDownloaded
                        ? '$fileSizeText · ${AppStrings.documentDownloaded}'
                        : isDownloading
                        ? '$fileSizeText · '
                              '${AppStrings.downloadPercent((progress * 100).toInt())}'
                        : '$fileSizeText · ${AppStrings.documentTapToDownload}',
                    style: AppTypography.actionCount(color: secondaryColor),
                  ),
                ],
              ),
            ),
            // Only a *second* action gets a second icon. The leading circle
            // already says "download" (and turns into the progress ring), so a
            // trailing arrow beside it was the same word twice; "open" is a
            // different verb and keeps its own.
            if (isDownloaded)
              Icon(Icons.open_in_new_rounded, color: secondaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}
