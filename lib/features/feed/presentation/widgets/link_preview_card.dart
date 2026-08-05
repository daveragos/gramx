import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

class LinkPreviewCard extends ConsumerWidget {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;

  const LinkPreviewCard({
    super.key,
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
  });

  String get _domain {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  Future<void> _openUrl() async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[LinkPreview] Could not launch URL $url: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant;

    return InkWell(
      onTap: _openUrl,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview Image Banner if available
            if (imageUrl != null && imageUrl!.isNotEmpty)
              _buildPreviewImage(ref, isDark),
            // Content Box
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.link, size: 14, color: secondaryColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _domain,
                          style: AppTypography.actionCount(
                              color: secondaryColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (title != null && title!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      title!,
                      style: AppTypography.body(color: primaryColor)
                          .copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (description != null && description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description!,
                      style:
                          AppTypography.actionCount(color: secondaryColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewImage(WidgetRef ref, bool isDark) {
    final path = imageUrl!;

    // If it's a URL, use CachedNetworkImage
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: path,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, urlStr) => Container(
          height: 150,
          color: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade200,
          child: const Center(
            child: Icon(Icons.link, color: AppColors.accent, size: 28),
          ),
        ),
        errorWidget: (context, urlStr, error) => const SizedBox.shrink(),
      );
    }

    // For local files, use async existence check
    final fileExists = ref.watch(fileExistsProvider(path));
    return fileExists.when(
      data: (exists) {
        if (exists) {
          return Image.file(
            File(path),
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => Container(
        height: 150,
        color: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade200,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
