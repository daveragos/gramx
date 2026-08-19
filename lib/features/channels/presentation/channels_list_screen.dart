import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';
import 'package:handy_tdlib/api.dart' as td;
class ChannelsListScreen extends ConsumerWidget {
  const ChannelsListScreen({super.key});

  Color _parseColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  Widget _buildAvatar(Channel channel) {
    if (channel.avatarUrl != null && channel.avatarUrl!.isNotEmpty) {
      final file = File(channel.avatarUrl!);
      if (file.existsSync()) {
        return CircleAvatar(
          radius: AppSpacing.avatarSizeLarge / 2,
          backgroundImage: FileImage(file),
        );
      }
    }
    return CircleAvatar(
      radius: AppSpacing.avatarSizeLarge / 2,
      backgroundColor: channel.avatarColor != null
          ? _parseColor(channel.avatarColor!)
          : AppColors.accent,
      child: Text(
        channel.title.isNotEmpty ? channel.title[0].toUpperCase() : '?',
        style: AppTypography.heading(color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final channelsAsync = ref.watch(channelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.channelsTitle,
          style: AppTypography.heading(color: primaryColor),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Channel',
            onPressed: () => _showAddChannelDialog(context, ref),
          ),
        ],
      ),
      body: channelsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(
          child: Text('Error loading channels: $err'),
        ),
        data: (channels) {
          if (channels.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.list_alt_outlined,
                      color: AppColors.accent,
                      size: 80,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      AppStrings.channelsEmptyTitle,
                      style: AppTypography.heading(color: primaryColor).copyWith(fontSize: 22),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      AppStrings.channelsEmptyBody,
                      style: AppTypography.body(color: secondaryColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: () => _showAddChannelDialog(context, ref),
                      child: const Text(AppStrings.channelsAddPublic,
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: channels.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final channel = channels[index];
              return InkWell(
                onTap: () => NavigationUtils.openChannel(context, channel.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.postPadding,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      _buildAvatar(channel),
                      const SizedBox(width: AppSpacing.avatarGap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    channel.title,
                                    style: AppTypography.displayName(color: primaryColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (channel.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified,
                                    color: AppColors.verified,
                                    size: 18,
                                  ),
                                ],
                              ],
                            ),
                            if (channel.username != null)
                              Text(
                                '@${channel.username}',
                                style: AppTypography.username(color: secondaryColor),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${TimeUtils.formatCount(channel.subscriberCount)} subscribers',
                        style: AppTypography.actionCount(color: secondaryColor),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () => _showAddChannelDialog(context, ref),
      ),
    );
  }

  void _showAddChannelDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    bool isLoading = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: theme.scaffoldBackgroundColor,
              title: Text(
                'Add Public Channel',
                style: AppTypography.heading(color: primaryColor),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter a public Telegram channel username (e.g. durov).',
                    style: AppTypography.body(color: secondaryColor),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Channel Username',
                      hintText: 'durov',
                      prefixText: '@',
                      errorText: errorMsg,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final text = controller.text.trim();
                          if (text.isEmpty) return;

                          setState(() {
                            isLoading = true;
                            errorMsg = null;
                          });

                          try {
                            final tdlibService = ref.read(tdlibServiceProvider);
                            await tdlibService.sendRequest(td.SearchPublicChat(username: text));
                            if (context.mounted) {
                              Navigator.pop(context); // close dialog
                            }

                            // Invalidate providers to refresh
                            ref.invalidate(feedPostsProvider);
                            ref.invalidate(channelsProvider);
                          } catch (e) {
                            setState(() {
                              isLoading = false;
                              errorMsg = e.toString().replaceFirst(
                                    'Exception: ',
                                    '',
                                  );
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
