import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/settings/data/settings_store.dart';
import 'package:gramx/core/widgets/minithumbnail.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/media_path.dart';
import 'package:gramx/core/navigation/url_launcher_utils.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';
import 'package:gramx/core/text/text_direction.dart';

class LinkPreviewCard extends ConsumerWidget {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final int? imageFileId;

  const LinkPreviewCard({
    super.key,
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.imageFileId,
  });

  String get _domain {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  /// Opens the previewed link. Doesn't check `canLaunchUrl`, which returns
  /// false on Android 11+ unless the intent is declared in the manifest.
  Future<void> _openUrl(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await openExternalUrl(normalizeUrl(url));
    if (opened) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(AppStrings.linkCouldNotOpen(url)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurfaceVariant;

    final hasImage =
        (imageUrl != null && imageUrl!.isNotEmpty) ||
        (imageFileId != null && imageFileId! > 0);
    final hasTitle = title != null && title!.isNotEmpty;

    // With a picture, as X draws a link: the picture alone with its title
    // over a corner, and the site named under it.
    if (hasImage) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openUrl(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(
                  color: borderColor,
                  width: AppSpacing.mediaBorderWidth,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_radius),
                child: AspectRatio(
                  aspectRatio: 1.91,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // A page mark until the picture loads, if it does.
                      ColoredBox(
                        color: surfaceColor,
                        child: Center(
                          child: Icon(
                            Icons.article_outlined,
                            size: 40,
                            color: secondaryColor,
                          ),
                        ),
                      ),
                      _buildPreviewImage(ref, isDark),
                      if (hasTitle)
                        Positioned(
                          left: AppSpacing.sm,
                          right: AppSpacing.sm,
                          bottom: 5.7,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.pillRadius,
                                ),
                              ),
                              child: Text(
                                title!,
                                textDirection: firstStrongDirection(title!),
                                style: AppTypography.username(
                                  color: Colors.white,
                                ).copyWith(fontSize: 13.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4.6),
            Text(
              AppStrings.linkFrom(_domain),
              style: AppTypography.username(
                color: secondaryColor,
              ).copyWith(fontSize: 14.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => _openUrl(context),
      borderRadius: BorderRadius.circular(_radius),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.link, size: 14, color: secondaryColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _domain,
                      style: AppTypography.actionCount(color: secondaryColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (hasTitle) ...[
                const SizedBox(height: 4),
                Text(
                  title!,
                  textDirection: firstStrongDirection(title!),
                  style: AppTypography.body(
                    color: primaryColor,
                  ).copyWith(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (description != null && description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description!,
                  textDirection: firstStrongDirection(description!),
                  style: AppTypography.actionCount(color: secondaryColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The card's corners, rounder than a photo's.
  static const double _radius = 12;

  Widget _buildPreviewImage(WidgetRef ref, bool isDark) {
    // A TDLib file when signed in; in guest mode an https URL that the guest
    // media cache fetches, only from Telegram's own hosts.
    final path = resolveMediaPath(ref, rawPath: imageUrl);

    if (path != null && path.isNotEmpty) {
      final fileExists = ref.watch(fileExistsProvider(path));
      final exists = fileExists.value ?? false;
      if (exists) {
        return Image.file(
          File(path),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        );
      }
    }

    if (imageFileId != null && imageFileId! > 0) {
      // With auto-download off the card goes without its picture unless it
      // is already on the device.
      if (!ref.watch(
        settingsProvider.select((s) => s.autoDownloadImagesEnabled),
      )) {
        final downloaded = ref
            .watch(fileDownloadStatusProvider(imageFileId!))
            .value
            ?.localPath;
        if (downloaded == null || downloaded.isEmpty) {
          return const SizedBox.shrink();
        }
        return Image.file(
          File(downloaded),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        );
      }

      // Holds the image's height until it arrives, rather than collapsing
      // and growing again on each progress update.
      final loading = Container(
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
      );

      // Watching starts the download.
      final fileAsync = ref.watch(fileDownloadProvider(imageFileId!));
      return fileAsync.when(
        skipLoadingOnReload: true,
        data: (localPath) {
          if (localPath == null || localPath.isEmpty) return loading;
          return Image.file(
            File(localPath),
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            frameBuilder: fadeInFrame,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          );
        },
        loading: () => loading,
        error: (err, stack) => const SizedBox.shrink(),
      );
    }

    return const SizedBox.shrink();
  }
}
