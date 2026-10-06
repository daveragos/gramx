import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/features/guest/presentation/guest_feed_screen.dart';
import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/widgets/loading_skeleton.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
import 'package:gramx/features/compose/presentation/widgets/compose_fab.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/feed_onboarding_view.dart';
import 'package:gramx/features/feed/presentation/widgets/folder_feed.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/app/widgets/brand_mark.dart';

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
    // A guest has no folders, chat cache or unread state.
    if (ref.watch(isGuestModeProvider)) return const GuestFeedScreen();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = theme.colorScheme.onSurface;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final channelsAsync = ref.watch(channelsProvider);
    final accountAsync = ref.watch(activeAccountProvider);
    final feedAsync = ref.watch(feedPostsProvider);
    final isSyncing = feedAsync.isLoading;
    // The feed can paint from the chat cache before the channel list loads.
    final feedHasPosts = feedAsync.value?.isNotEmpty ?? false;
    final String displayName = accountAsync.value?.displayName ?? 'User';

    final foldersAsync = ref.watch(foldersProvider);
    final dynamicFolders = foldersAsync.value ?? [];

    // Hide a folder only when known to be empty, so a pending or failed
    // lookup at sign-in can't empty the tab strip.
    final channelsKnown = ref.watch(channelsKnownProvider);

    bool folderHasChannels(int folderId) {
      // An unread-only folder empties whenever everything is read. Keep its
      // tab so the strip doesn't reshuffle on every read.
      if (ref.watch(folderExcludesReadProvider(folderId)).value == true) {
        return true;
      }

      final ids = ref.watch(folderChannelIdsProvider(folderId));
      final known = ids.value;
      if (known == null) return true;
      if (known.isEmpty && !channelsKnown) return true;
      return known.isNotEmpty;
    }

    final tabItems = [
      (title: 'All', id: 'All'),
      ...dynamicFolders
          .where((f) => folderHasChannels(f.id))
          .map((f) => (title: parseFolderTitle(f.title), id: f.id.toString())),
    ];

    // Shared by both branches so the header stays put on a cold start.
    final header = ChromeHeaderRow(
      titleWidget: const BrandGlyph(),
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
            // The drawer is on the shell's scaffold, not this screen's.
            onTap: openAppDrawer,
          ),
        ),
      ),
    );

    // Used before and after the channel list loads.
    Widget feedScaffold() => DefaultTabController(
      length: tabItems.length,
      child: _FolderTabSync(
        folderIds: tabItems.map((t) => t.id).toList(),
        child: ChromeScaffold(
          // Each tab's list reports its own scrolling.
          observeScroll: false,
          // No button when there is nowhere to post.
          floatingActionButton: ref.watch(canComposeProvider)
              ? const ComposeFab()
              : null,
          headerBottomHeight: _tabBarHeight,
          header: header,
          headerBottom: _FolderTabBar(
            titles: tabItems.map((t) => t.title).toList(),
            onTabTap: (index) {
              final folderId = tabItems[index].id;
              // Compared with the folder on screen, so tapping a tab that
              // was swiped to counts as a re-tap.
              final isRetap = ref.read(activeFolderProvider) == folderId;
              ref.read(activeFolderProvider.notifier).set(folderId);
              if (isRetap) {
                ref.read(feedScrollToTopProvider.notifier).request(folderId);
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

    return channelsAsync.when(
      // The header shows at once; the tabs and feed shimmer.
      loading: () => feedHasPosts
          ? feedScaffold()
          : ChromeScaffold(
              observeScroll: false,
              headerBottomHeight: _tabBarHeight,
              header: header,
              headerBottom: const FolderTabsSkeleton(),
              body: (context, topPadding, bottomPadding) => FeedSkeleton(
                padding: EdgeInsets.only(
                  top: topPadding,
                  bottom: bottomPadding,
                ),
              ),
            ),
      error: (err, _) =>
          Scaffold(body: Center(child: Text(AppStrings.feedError(err)))),
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
                      // Same animated mark as the splash screen.
                      const BrandMark(size: 96),
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
          return const Scaffold(body: FeedOnboardingView());
        }

        return feedScaffold();
      },
    );
  }
}

/// Keeps the folder tabs in step with the app: selects requested tabs,
/// records the folder on screen (swiped tabs included), and shows the header
/// as soon as a tab starts moving.
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

    // Fires throughout a drag, so this catches the start of a swipe.
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
      DefaultTabController.of(context).animateTo(index);
    });

    return widget.child;
  }
}

/// The folder tabs under the feed's app bar, part of the sliding header so
/// switching folders doesn't relayout the list.
class _FolderTabBar extends StatelessWidget {
  final List<String> titles;
  final ValueChanged<int> onTabTap;

  const _FolderTabBar({required this.titles, required this.onTabTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

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
