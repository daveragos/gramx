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
    final isSyncing = ref.watch(isSyncingProvider).value;
    final String displayName = accountAsync.value?.displayName ?? 'User';

    final foldersAsync = ref.watch(foldersProvider);
    final dynamicFolders = foldersAsync.value ?? [];

    final tabItems = [
      (title: 'All', id: 'All'),
      ...dynamicFolders.map((f) => (title: f.title, id: f.id.toString())),
    ];

    return channelsAsync.when(
      loading: () => const Scaffold(body: FeedSkeleton()),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (channels) {
        final isEmpty = channels.isEmpty;
        final isLoggedIn = accountAsync.value != null;

        // If logged in and channels are syncing or empty initially, show sync view
        if (isEmpty) {
          if (isLoggedIn || isSyncing) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.accent),
                      const SizedBox(height: 24),
                      Text(
                        'Syncing Telegram Feed',
                        style: AppTypography.heading(color: primaryTextColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fetching your subscribed channels and history from Telegram...',
                        style: AppTypography.body(color: secondaryTextColor),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return const Scaffold(
            body: _OnboardingView(),
          );
        }

        return DefaultTabController(
          length: tabItems.length,
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
                    bottom: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: AppColors.accent,
                      labelColor: primaryTextColor,
                      unselectedLabelColor: secondaryTextColor,
                      dividerColor: Colors.transparent,
                      tabs: tabItems.map((item) => Tab(text: item.title)).toList(),
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
                  children: tabItems.map((item) {
                    return _FolderFeed(folderTitle: item.title, folderId: item.id);
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
                            Navigator.pop(context);
                          }

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

class _FolderFeed extends ConsumerStatefulWidget {
  final String folderTitle;
  final String folderId;

  const _FolderFeed({required this.folderTitle, required this.folderId});

  @override
  ConsumerState<_FolderFeed> createState() => _FolderFeedState();
}

class _FolderFeedState extends ConsumerState<_FolderFeed> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() async {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoadingMore) {
        setState(() => _isLoadingMore = true);
        try {
          final channels = ref.read(channelsProvider).value ?? [];
          for (final channel in channels) {
            final channelDbId = int.tryParse(channel.id);
            if (channelDbId != null) {
              await ref.read(
                loadMoreChannelHistoryProvider((
                  channelDbId: channelDbId,
                  chatId: channel.chatId,
                )).future,
              );
            }
          }
        } catch (_) {
        } finally {
          if (mounted) setState(() => _isLoadingMore = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(filteredFeedPostsProvider(widget.folderId));
    final isSyncing = ref.watch(isSyncingProvider).value;
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
          if (isSyncing) {
            return const FeedSkeleton();
          }
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
                  'No posts in ${widget.folderTitle}',
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
            final syncService = ref.read(syncServiceProvider);
            await syncService.syncSubscribedChannels();
            await syncService.syncFeedHistory();
            ref.invalidate(feedPostsProvider);
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            itemCount: posts.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == posts.length) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                      strokeWidth: 2.5,
                    ),
                  ),
                );
              }

              final post = posts[index];
              return PostCard(
                post: post,
                onTap: () {
                  final id = int.tryParse(post.id);
                  if (id != null) {
                    ref.read(markPostAsReadProvider(id));
                  }
                  context.push('/post/${post.id}');
                },
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
