import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';

class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  /// Opens a folder as its feed tab. This screen sits above the shell, so it
  /// navigates to the feed route and requests the tab.
  void openFolderTab(BuildContext context, WidgetRef ref, int folderId) {
    ref.read(requestedFolderProvider.notifier).request(folderId.toString());
    context.go(ShellTab.home.path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final foldersAsync = ref.watch(foldersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.foldersTitle,
          style: AppTypography.heading(color: primaryColor),
        ),
      ),
      body: foldersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(child: Text(AppStrings.foldersError(err))),
        data: (folders) {
          if (folders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.folder_open_outlined,
                      color: AppColors.accent,
                      size: 80,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      AppStrings.foldersEmptyTitle,
                      style: AppTypography.heading(
                        color: primaryColor,
                      ).copyWith(fontSize: 22),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      AppStrings.foldersEmptyBody,
                      style: AppTypography.body(color: secondaryColor),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: folders.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final folder = folders[index];
              final countAsync = ref.watch(folderChannelIdsProvider(folder.id));

              return ListTile(
                leading: const Icon(
                  Icons.folder_outlined,
                  color: AppColors.accent,
                  size: 28,
                ),
                title: Text(
                  parseFolderTitle(folder.title),
                  style: AppTypography.subheading(color: primaryColor),
                ),
                subtitle: Text(
                  countAsync.when(
                    data: (ids) => AppStrings.folderChannelCount(ids.length),
                    loading: () => AppStrings.foldersCounting,
                    error: (_, _) => AppStrings.foldersCountUnavailable,
                  ),
                  style: AppTypography.actionCount(color: secondaryColor),
                ),
                trailing: Icon(Icons.chevron_right, color: secondaryColor),
                onTap: () => openFolderTab(context, ref, folder.id),
              );
            },
          );
        },
      ),
    );
  }
}
