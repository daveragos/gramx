import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/widgets/loading_skeleton.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/feed_onboarding_view.dart';
import 'package:gramx/features/feed/presentation/widgets/folder_feed.dart';


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showGoToTop = false;
  DateTime? _lastBackPressTime;

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

  void _onScroll() {
    if (_scrollController.hasClients) {
      final isScrolledDown = _scrollController.offset > 300;
      if (isScrolledDown != _showGoToTop) {
        setState(() => _showGoToTop = isScrolledDown);
      }
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = theme.colorScheme.onSurface;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final channelsAsync = ref.watch(channelsProvider);
    final accountAsync = ref.watch(activeAccountProvider);
    final isSyncing = ref.watch(feedPostsProvider).isLoading;
    final String displayName = accountAsync.value?.displayName ?? 'User';

    final foldersAsync = ref.watch(foldersProvider);
    final dynamicFolders = foldersAsync.value ?? [];

    String parseTitle(dynamic rawTitle) {
      if (rawTitle == null) return 'Folder';
      if (rawTitle is String) return rawTitle;
      if (rawTitle is td.FormattedText) return rawTitle.text;
      if (rawTitle is Map) {
        final textVal = rawTitle['text'];
        if (textVal is String) return textVal;
      }
      try {
        final text = (rawTitle as dynamic).text;
        if (text != null && text is String) return text;
      } catch (_) {}
      return rawTitle.toString();
    }

    final tabItems = [
      (title: 'All', id: 'All'),
      ...dynamicFolders.map((f) => (title: parseTitle(f.title), id: f.id.toString())),
    ];

    return channelsAsync.when(
      loading: () => const Scaffold(body: FeedSkeleton()),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (channels) {
        final isEmpty = channels.isEmpty;
        final isLoggedIn = accountAsync.value != null;

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
            body: FeedOnboardingView(),
          );
        }

        return DefaultTabController(
          length: tabItems.length,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              final now = DateTime.now();
              if (_lastBackPressTime == null ||
                  now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
                _lastBackPressTime = now;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Press back again to exit'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                SystemNavigator.pop();
              }
            },
            child: Scaffold(
              body: Stack(
                children: [
                  NestedScrollView(
                    controller: _scrollController,
                    headerSliverBuilder: (headerContext, innerBoxIsScrolled) {
                      return [
                        SliverAppBar(
                          floating: true,
                          snap: true,
                          pinned: false,
                          forceElevated: innerBoxIsScrolled,
                          leading: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: ChannelAvatar(
                              title: displayName,
                              avatarPath: accountAsync.value?.avatarPath,
                              radius: AppSpacing.avatarSizeSmall / 2,
                              onTap: () {
                                Scaffold.of(context).openDrawer();
                              },
                            ),
                          ),
                          title: Text(
                            'gramX',
                            style: AppTypography.heading(color: primaryTextColor),
                          ),
                          centerTitle: true,
                          actions: [
                            IconButton(
                              icon: const Icon(Icons.search_rounded),
                              color: primaryTextColor,
                              onPressed: () {
                                context.push('/search');
                              },
                            ),
                          ],
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
                    body: TabBarView(
                      children: tabItems.map((item) {
                        return FolderFeed(folderTitle: item.title, folderId: item.id);
                      }).toList(),
                    ),
                  ),

                  // Floating Top Center "Go to Top / New Posts" Pill
                  if (_showGoToTop)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 95,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _scrollToTop,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_upward_rounded,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Top',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
