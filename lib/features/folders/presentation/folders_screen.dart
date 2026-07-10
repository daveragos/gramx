import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';

class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final foldersAsync = ref.watch(foldersProvider);
    final folderChannelsMapAsync = ref.watch(folderChannelsMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Folders',
          style: AppTypography.heading(color: primaryColor),
        ),
      ),
      body: foldersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(
          child: Text('Error loading folders: $err'),
        ),
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
                      'No folders found',
                      style: AppTypography.heading(color: primaryColor).copyWith(fontSize: 22),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Your Telegram chat folders will sync and show up here once you subscribe to channels and group them.',
                      style: AppTypography.body(color: secondaryColor),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return folderChannelsMapAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (err, _) => Center(
              child: Text('Error: $err'),
            ),
            data: (folderChannelsMap) {
              return ListView.separated(
                itemCount: folders.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final folder = folders[index];
                  final channelIds = folderChannelsMap[folder.id] ?? [];
                  final channelCount = channelIds.length;

                  return ListTile(
                    leading: const Icon(
                      Icons.folder_outlined,
                      color: AppColors.accent,
                      size: 28,
                    ),
                    title: Text(
                      folder.title,
                      style: AppTypography.subheading(color: primaryColor),
                    ),
                    subtitle: Text(
                      '$channelCount ${channelCount == 1 ? 'channel' : 'channels'}',
                      style: AppTypography.actionCount(color: secondaryColor),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: secondaryColor,
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Viewing folder detail is coming in a future phase. Filter by folders on the home screen tabs!',
                            style: AppTypography.body(color: Colors.white),
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
