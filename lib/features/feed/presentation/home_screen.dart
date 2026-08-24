import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/widgets/loading_skeleton.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/feed_onboarding_view.dart';
import 'package:gramx/features/feed/presentation/widgets/folder_feed.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// The folder tabs under the app bar. The feed reserves this much extra at
  /// its top so the header can slide away without reflowing the list.
  static const double _tabBarHeight = 46;

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

    // Hide a folder only when we positively know it holds no channels. While
    // it is loading, if the lookup failed, or if the chat cache has nothing to
    // resolve ids against yet, the tab stays — a folder that vanishes because
    // of a race is much worse than a briefly empty tab, and that race is
    // exactly what emptied the tab strip for a whole session after signing in.
    final channelsKnown = ref.watch(channelsKnownProvider);

    bool folderHasChannels(int folderId) {
      final ids = ref.watch(folderChannelIdsProvider(folderId));
      final known = ids.value;
      if (known == null) return true;
      if (known.isEmpty && !channelsKnown) return true;
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
          child: _FolderTabSync(
            folderIds: tabItems.map((t) => t.id).toList(),
            child: ChromeScaffold(
              // The feed owns four scrollables, one per tab, so each reports
              // its own scrolling rather than the scaffold guessing which is
              // on screen.
              observeScroll: false,
              headerBottomHeight: _tabBarHeight,
              header: ChromeHeaderRow(
                title: AppStrings.appName,
                centerTitle: true,
                leading: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Semantics(
                    button: true,
                    label: AppStrings.a11yOpenMenu,
                    child: ChannelAvatar(
                      title: displayName,
                      avatarPath: accountAsync.value?.avatarPath,
                      radius: AppSpacing.avatarSizeSmall / 2,
                      // The drawer belongs to the shell's scaffold, not to this
                      // screen's — `Scaffold.of` here finds the wrong one and
                      // the tap does nothing.
                      onTap: openAppDrawer,
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search_rounded),
                    tooltip: AppStrings.a11ySearch,
                    color: primaryTextColor,
                    // Switch tab rather than push: /search is a shell branch,
                    // and pushing it would stack a second copy above the bar.
                    onPressed: () => StatefulNavigationShell.of(context)
                        .goBranch(ShellTab.search.index),
                  ),
                ],
              ),
              headerBottom: _FolderTabBar(
                titles: tabItems.map((t) => t.title).toList(),
                onTabTap: (index) {
                  final folderId = tabItems[index].id;
                  // Compared against the folder actually on screen, not a
                  // remembered tap: swiping to a tab and then tapping it is a
                  // re-tap, and used to be treated as a switch.
                  final isRetap = ref.read(activeFolderProvider) == folderId;
                  ref.read(activeFolderProvider.notifier).set(folderId);
                  if (isRetap) {
                    ref
                        .read(feedScrollToTopProvider.notifier)
                        .request(folderId);
                  }
                },
              ),
              body: (context, topPadding, bottomPadding) => TabBarView(
                children: tabItems.map((item) {
                  return FolderFeed(
                    folderTitle: item.title,
                    folderId: item.id,
                    topPadding: topPadding,
                    bottomPadding: bottomPadding,
                    // Where the pill sits once the header is gone.
                    collapsedTopPadding: MediaQuery.of(context).padding.top,
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Keeps the folder tabs and the rest of the app in step.
///
/// Three jobs, all of which need the `TabController` that lives above the feed:
///
/// * selects the tab another screen asked for, consuming the request so it
///   fires once rather than on every rebuild;
/// * records which folder is on screen — a *swiped* tab never went through the
///   tab bar's onTap, so re-tapping Home scrolled whichever folder was last
///   tapped back to the top, not the one being read;
/// * brings the header back the moment a tab starts moving. Each tab reserves
///   the header's height at the top of its list, so arriving on one with the
///   header retired showed a band of empty space where it should have been —
///   and it only reappeared, unanimated, once the outgoing tab was disposed.
class _FolderTabSync extends ConsumerStatefulWidget {
  final List<String> folderIds;
  final Widget child;

  const _FolderTabSync({required this.folderIds, required this.child});

  @override
  ConsumerState<_FolderTabSync> createState() => _FolderTabSyncState();
}

class _FolderTabSyncState extends ConsumerState<_FolderTabSync> {
  TabController? _controller;
  int? _lastIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.of(context);
    if (identical(controller, _controller)) return;

    _controller?.removeListener(_onTabChanged);
    _controller = controller..addListener(_onTabChanged);
    _lastIndex = controller.index;
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    final controller = _controller;
    if (controller == null) return;

    // The listener fires continuously through a drag, so this catches the
    // start of a swipe rather than waiting for it to land.
    final moving = tabIsMoving(
      position: controller.animation?.value ?? controller.index.toDouble(),
      index: controller.index,
      indexIsChanging: controller.indexIsChanging,
    );
    if (moving) ref.read(chromeOffsetProvider.notifier).show();

    if (controller.index == _lastIndex) return;
    _lastIndex = controller.index;
    if (controller.index < widget.folderIds.length) {
      ref
          .read(activeFolderProvider.notifier)
          .set(widget.folderIds[controller.index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(requestedFolderProvider, (_, next) {
      if (next == null) return;
      final index = widget.folderIds.indexOf(next);
      if (index < 0) return;

      ref.read(requestedFolderProvider.notifier).consume();
      // The controller lives above this widget but below the listener's
      // callback, which runs outside build — safe to touch here.
      DefaultTabController.of(context).animateTo(index);
    });

    return widget.child;
  }
}

/// The folder tabs under the feed's app bar.
///
/// Part of the sliding header rather than the list, so switching folders never
/// costs a relayout of what is being read.
class _FolderTabBar extends StatelessWidget {
  final List<String> titles;
  final ValueChanged<int> onTabTap;

  const _FolderTabBar({required this.titles, required this.onTabTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      indicatorColor: AppColors.accent,
      labelColor: primary,
      unselectedLabelColor: secondary,
      dividerColor: Colors.transparent,
      onTap: onTabTap,
      tabs: [for (final title in titles) Tab(text: title)],
    );
  }
}
