import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/widgets/loading_skeleton.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = theme.colorScheme.onSurface;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final channelsAsync = ref.watch(channelsProvider);
    final accountAsync = ref.watch(activeAccountProvider);
    final String displayName = accountAsync.value?.displayName ?? 'User';
    final folders = ['All', 'Tech', 'Crypto', 'News', 'Design'];

    return channelsAsync.when(
      loading: () => const Scaffold(body: FeedSkeleton()),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (channels) {
        final isEmpty = channels.isEmpty;

        if (isEmpty) {
          return const Scaffold(
            body: _OnboardingView(),
          );
        }

        return DefaultTabController(
          length: folders.length,
          child: Scaffold(
            body: NestedScrollView(
              headerSliverBuilder: (headerContext, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    floating: true,
                    snap: true,
                    pinned: false,
                    forceElevated: innerBoxIsScrolled,
                    leading: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: GestureDetector(
                        onTap: () {
                          Scaffold.of(context).openDrawer();
                        },
                        child: () {
                          final path = accountAsync.value?.avatarPath;
                          if (path != null && path.isNotEmpty) {
                            final file = File(path);
                            if (file.existsSync()) {
                              return CircleAvatar(
                                radius: AppSpacing.avatarSizeSmall / 2,
                                backgroundImage: FileImage(file),
                              );
                            }
                          }
                          return CircleAvatar(
                            radius: AppSpacing.avatarSizeSmall / 2,
                            backgroundColor: AppColors.accent,
                            child: Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'R',
                              style: AppTypography.actionCount(
                                color: Colors.white,
                              ),
                            ),
                          );
                        }(),
                      ),
                    ),
                    title: Text(
                      'gramX',
                      style: AppTypography.heading(color: primaryTextColor),
                    ),
                    centerTitle: true,
                    actions: [
                      IconButton(
                        icon: Icon(
                          Icons.settings_outlined,
                          color: primaryTextColor,
                        ),
                        onPressed: () => context.push('/settings'),
                      ),
                    ],
                    bottom: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: AppColors.accent,
                      labelColor: primaryTextColor,
                      unselectedLabelColor: secondaryTextColor,
                      dividerColor: Colors.transparent,
                      tabs: folders.map((folder) => Tab(text: folder)).toList(),
                    ),
                  ),
                ];
              },
              body: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification notification) {
                  if (notification is ScrollUpdateNotification) {
                    final delta = notification.scrollDelta ?? 0;
                    if (delta > 2.0) {
                      ref
                          .read(bottomNavVisibilityProvider.notifier)
                          .setVisible(false);
                    } else if (delta < -2.0) {
                      ref
                          .read(bottomNavVisibilityProvider.notifier)
                          .setVisible(true);
                    }
                  }
                  return false;
                },
                child: TabBarView(
                  children: folders.map((folder) {
                    return _FolderFeed(folder: folder);
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingView extends ConsumerWidget {
  const _OnboardingView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final accountAsync = ref.watch(activeAccountProvider);
    final isLoggedIn = accountAsync.value != null;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.feed_outlined,
                color: AppColors.accent,
                size: 80,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Welcome to gramX',
                style: AppTypography.heading(
                  color: primaryColor,
                ).copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                isLoggedIn
                    ? 'You haven\'t subscribed to any channels yet. Add public Telegram channels to build your custom feed.'
                    : 'One timeline for the Telegram channels you follow. Log in with your Telegram account to view your subscribed channels and feeds.',
                style: AppTypography.body(color: secondaryColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              if (!isLoggedIn) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () {
                    context.push('/auth');
                  },
                  child: const Text(
                    'Log in with Telegram',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ] else ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () => _showAddChannelDialog(context, ref),
                  child: const Text(
                    'Add Public Channel',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
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
                          final syncService = ref.read(syncServiceProvider);
                          await syncService.addPublicChannelByUsername(text);
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

class _FolderFeed extends ConsumerWidget {
  final String folder;

  const _FolderFeed({required this.folder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(filteredFeedPostsProvider(folder));
    final theme = Theme.of(context);

    return feedAsync.when(
      loading: () => const FeedSkeleton(),
      error: (err, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Something went wrong',
              style: AppTypography.subheading(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              err.toString(),
              style: AppTypography.body(color: theme.iconTheme.color),
            ),
          ],
        ),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.article_outlined,
                  color: theme.iconTheme.color,
                  size: 48,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No posts in $folder',
                  style: AppTypography.subheading(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async {
            ref.invalidate(feedPostsProvider);
          },
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return PostCard(
                post: post,
                onTap: () => context.push('/post/${post.id}'),
                onChannelTap: () => context.push('/channel/${post.channelId}'),
                onBookmarkTap: () {
                  ref.read(bookmarkToggleProvider(post.id));
                },
              );
            },
          ),
        );
      },
    );
  }
}
