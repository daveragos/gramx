import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/app/app_shell.dart';
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
  /// App bar plus folder tabs. The feed reserves this much at its top so the
  /// header can slide away without reflowing the list.
  static const double _appBarHeight = 56;
  static const double _tabBarHeight = 46;

  int _currentTabIndex = 0;

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

    final chromeVisible = ref.watch(chromeVisibleProvider);
    final headerHeight = MediaQuery.of(context).padding.top +
        _appBarHeight +
        _tabBarHeight;

    final foldersAsync = ref.watch(foldersProvider);
    final dynamicFolders = foldersAsync.value ?? [];

    // A folder with no channels is a dead end, so it doesn't get a tab. While
    // a folder's contents are still loading we keep it — dropping a tab that
    // then reappears is worse than a brief empty one.
    // Hide a folder only when we positively know it holds no channels. While
    // it is loading, or if the lookup failed, the tab stays — a folder that
    // vanishes because of a race is much worse than a briefly empty tab.
    bool folderHasChannels(int folderId) {
      final ids = ref.watch(folderChannelIdsProvider(folderId));
      final known = ids.value;
      if (known == null) return true;
      return known.isNotEmpty;
    }

    final tabItems = [
      (title: 'All', id: 'All'),
      ...dynamicFolders.where((f) => folderHasChannels(f.id)).map(
            (f) => (title: parseFolderTitle(f.title), id: f.id.toString()),
          ),
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
                        AppStrings.feedSyncingTitle,
                        style: AppTypography.heading(color: primaryTextColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.feedSyncingBody,
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
          child: _FolderTabRequestHandler(
            folderIds: tabItems.map((t) => t.id).toList(),
            child: Scaffold(
              body: Stack(
                children: [
                  // The feed fills the screen and reserves room for the header
                  // rather than sitting under a collapsing box. Sliding the
                  // header away leaves the content where it is, so nothing
                  // jumps mid-scroll.
                  TabBarView(
                    children: tabItems.map((item) {
                      return FolderFeed(
                        folderTitle: item.title,
                        folderId: item.id,
                        topPadding: headerHeight,
                      );
                    }).toList(),
                  ),

                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedSlide(
                      offset: chromeVisible ? Offset.zero : const Offset(0, -1),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: _FeedHeader(
                        height: headerHeight,
                        displayName: displayName,
                        avatarPath: accountAsync.value?.avatarPath,
                        tabTitles: tabItems.map((t) => t.title).toList(),
                        onTabTap: (index) {
                          ref
                              .read(activeFolderProvider.notifier)
                              .set(tabItems[index].id);
                          if (index == _currentTabIndex) {
                            // Re-tap on the active tab returns to the top.
                            ref
                                .read(feedScrollToTopProvider.notifier)
                                .request(tabItems[index].id);
                          }
                          setState(() => _currentTabIndex = index);
                        },
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

/// Selects the folder tab another screen asked for.
///
/// Lives under [DefaultTabController] so it can reach the controller, and
/// consumes the request so it fires once rather than on every rebuild.
class _FolderTabRequestHandler extends ConsumerWidget {
  final List<String> folderIds;
  final Widget child;

  const _FolderTabRequestHandler({
    required this.folderIds,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(requestedFolderProvider, (_, next) {
      if (next == null) return;
      final index = folderIds.indexOf(next);
      if (index < 0) return;

      ref.read(requestedFolderProvider.notifier).consume();
      // The controller lives above this widget but below the listener's
      // callback, which runs outside build — safe to touch here.
      DefaultTabController.of(context).animateTo(index);
    });

    return child;
  }
}

/// The feed's app bar and folder tabs, as one sliding surface.
///
/// Painted opaque and sized explicitly: it overlays the list rather than
/// occupying layout space, so sliding it away doesn't reflow what's underneath.
class _FeedHeader extends ConsumerWidget {
  final double height;
  final String displayName;
  final String? avatarPath;
  final List<String> tabTitles;
  final ValueChanged<int> onTabTap;

  const _FeedHeader({
    required this.height,
    required this.displayName,
    required this.avatarPath,
    required this.tabTitles,
    required this.onTabTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: border, width: 0.5)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Semantics(
                      button: true,
                      label: AppStrings.a11yOpenMenu,
                      child: ChannelAvatar(
                        title: displayName,
                        avatarPath: avatarPath,
                        radius: AppSpacing.avatarSizeSmall / 2,
                        onTap: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        AppStrings.appName,
                        style: AppTypography.heading(color: primary),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search_rounded),
                    tooltip: AppStrings.a11ySearch,
                    color: primary,
                    // Switch tab rather than push: /search is a shell branch,
                    // and pushing it would stack a second copy above the bar.
                    onPressed: () => StatefulNavigationShell.of(context)
                        .goBranch(ShellTab.search.index),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 46,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.accent,
                labelColor: primary,
                unselectedLabelColor: secondary,
                dividerColor: Colors.transparent,
                onTap: onTabTap,
                tabs: [for (final title in tabTitles) Tab(text: title)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
