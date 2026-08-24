import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

class PostDocumentCard extends ConsumerWidget {
  final MediaItem item;

  const PostDocumentCard({super.key, required this.item});

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return 'Document';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _openFile(BuildContext context, String path) async {
    final result = await OpenFilex.open(path);
    if (result.type == ResultType.done || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.type == ResultType.noAppToOpen
              ? AppStrings.documentNoAppFound
              : AppStrings.documentOpenFailed,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final fileId = item.fileId;
    String? resolvedPath;
    FileDownloadProgressState? downloadState;

    if (fileId != null && fileId != 0) {
      downloadState = ref.watch(fileDownloadStatusProvider(fileId)).value;
    }
    resolvedPath = downloadState?.localPath ?? item.localPath;

    final isDownloaded = resolvedPath != null && resolvedPath.isNotEmpty && File(resolvedPath).existsSync();
    final isDownloading = downloadState != null && !downloadState.isCompleted && (downloadState.progress > 0 || downloadState.downloadedSize > 0);
    final fileName = item.fileName ?? 'Document file';
    final fileSizeText = _formatFileSize(item.fileSize);
    final progress = downloadState?.progress ?? 0.0;

    return InkWell(
      onTap: () {
        if (isDownloaded) {
          _openFile(context, resolvedPath!);
        } else if (fileId != null && fileId != 0) {
          ref.read(syncServiceProvider).downloadFileWithPriority(fileId, priority: 32);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(AppStrings.documentDownloading),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
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
                      isDownloaded ? Icons.insert_drive_file_rounded : Icons.download_rounded,
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
                    style: AppTypography.body(color: primaryColor).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDownloaded
                        ? '$fileSizeText · Downloaded'
                        : isDownloading
                            ? '$fileSizeText · ${(progress * 100).toInt()}%'
                            : '$fileSizeText · Tap to download',
                    style: AppTypography.actionCount(color: secondaryColor),
                  ),
                ],
              ),
            ),
            Icon(
              isDownloaded ? Icons.open_in_new_rounded : Icons.arrow_downward_rounded,
              color: secondaryColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
