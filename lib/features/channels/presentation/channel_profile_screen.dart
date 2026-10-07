import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/guest/data/guest_post_mapper.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/channels/data/channel_repository.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/channels/domain/channel_tab.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/channels/presentation/channel_tab_providers.dart';
import 'package:gramx/features/channels/presentation/similar_channels_screen.dart';
import 'package:gramx/features/channels/presentation/widgets/channel_file_list.dart';
import 'package:gramx/features/channels/presentation/widgets/channel_header.dart';
import 'package:gramx/features/channels/presentation/widgets/channel_media_grid.dart';
import 'package:gramx/features/channels/presentation/widgets/mute_sheet.dart';
import 'package:gramx/features/channels/presentation/widgets/pinned_post_card.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_focus_controller.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';
import 'package:gramx/features/stats/presentation/channel_stats_screen.dart';
import 'package:gramx/app/widgets/app_dialog.dart';

/// A channel profile: cover, avatar, identity, pinned post and content tabs.
/// A tab fetches only when first selected (see `ChannelTabNotifier`).
class ChannelProfileScreen extends ConsumerStatefulWidget {
  final String channelId;
  final int? highlightMessageId;

  const ChannelProfileScreen({
    super.key,
    required this.channelId,
    this.highlightMessageId,
  });

  @override
  ConsumerState<ChannelProfileScreen> createState() =>
      _ChannelProfileScreenState();
}

class _ChannelProfileScreenState extends ConsumerState<ChannelProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final FeedRepository _feedRepository;

  /// The page's outer scroll, which the bar and cover follow.
  final ScrollController _scroll = ScrollController();

  bool _isActionLoading = false;
  int? _openedChatId;

  /// Bounds [_fillViewport] so short pages can't cause a request loop.
  static const int _maxAutoFills = 3;
  int _autoFills = 0;
  late final bool _isGuestChannel;

  /// The tabs this channel has: only Posts for a guest channel, since the
  /// others need TDLib search. Fixed in initState, as it sets the tab count.
  late final List<ChannelTab> _tabs;

  @override
  void initState() {
    super.initState();
    _feedRepository = ref.read(feedRepositoryProvider);

    final chatId = int.tryParse(widget.channelId);
    _isGuestChannel = chatId != null && GuestPostMapper.isSynthetic(chatId);
    _tabs = _isGuestChannel ? const [ChannelTab.posts] : ChannelTab.values;

    _tabController = TabController(length: _tabs.length, vsync: this)
      ..addListener(_onTabChanged);

    // Opening a chat is a TDLib request, so it can't happen during build.
    // fireImmediately covers a channel that is already cached.
    ref.listenManual<AsyncValue<Channel?>>(
      channelDetailProvider(widget.channelId),
      (_, next) {
        _syncOpenChat(next.value?.chatId);
        // Retries a tab selected before the channel resolved.
        _loadSelectedTab();
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scroll.dispose();

    if (_openedChatId != null) {
      _feedRepository.closeChat(_openedChatId!);
    }

    super.dispose();
  }

  ChannelTab get _selectedTab => _tabs[_tabController.index];

  /// Keeps this screen's open chat in step with the channel it is showing.
  void _syncOpenChat(int? chatId) {
    // A guest channel's id is synthetic, so there is no chat to open.
    if (_isGuestChannel) return;
    if (chatId == null || chatId == _openedChatId) return;
    final previous = _openedChatId;
    if (previous != null) _feedRepository.closeChat(previous);
    _openedChatId = chatId;
    _feedRepository.openChat(chatId);
  }

  void _onTabChanged() {
    // Fires when the animation starts and again when it settles; only the
    // settled index fetches.
    if (_tabController.indexIsChanging) return;
    setState(() {});
    _loadSelectedTab();
  }

  /// The only place a tab's first page is asked for.
  void _loadSelectedTab() {
    final tab = _selectedTab;
    if (tab.isHistory) return;

    final chatId = ref
        .read(channelDetailProvider(widget.channelId))
        .value
        ?.chatId;
    if (chatId == null) return;

    ref
        .read(channelTabNotifierProvider.notifier)
        .ensureLoaded(ChannelTabKey(widget.channelId, tab), chatId);
  }

  /// Pagination for the tab that is scrolling. Uses notifications because
  /// `NestedScrollView` gives each tab its own scroll controller; [tab] is
  /// passed in so a tab still settling can't page its neighbour.
  bool _onTabScroll(ChannelTab tab, ScrollNotification notification) {
    if (notification.depth != 0) return false;

    final metrics = notification.metrics;
    if (metrics.maxScrollExtent <= 0) return false;
    if (metrics.pixels < metrics.maxScrollExtent * 0.85) return false;

    if (tab.isHistory) {
      ref.read(olderChannelPostsProvider.notifier).loadMore(widget.channelId);
      return false;
    }

    final chatId = ref
        .read(channelDetailProvider(widget.channelId))
        .value
        ?.chatId;
    if (chatId == null) return false;
    ref
        .read(channelTabNotifierProvider.notifier)
        .loadMore(ChannelTabKey(widget.channelId, tab), chatId);
    return false;
  }

  /// Loads another page when the first doesn't fill the screen, since a list
  /// too short to scroll never triggers pagination. History tab only.
  void _fillViewport({ScrollMetrics? metrics}) {
    if (!_selectedTab.isHistory) return;
    if (_autoFills >= _maxAutoFills) return;
    // No metrics means nothing is laid out yet, which is not a short list.
    if (metrics == null || metrics.maxScrollExtent > 0) return;

    final older = ref.read(olderChannelPostsProvider.notifier);
    if (older.isLoading(widget.channelId) ||
        older.isExhausted(widget.channelId)) {
      return;
    }

    // The new page's layout calls this again if the list is still short;
    // _maxAutoFills ends the loop.
    _autoFills++;
    unawaited(older.loadMore(widget.channelId));
  }

  Future<void> _refresh() async {
    _autoFills = 0;
    await refreshChannel(ref, widget.channelId);
    if (mounted) _loadSelectedTab();
  }

  /// Confirms before leaving. Only leaving asks, since rejoining a private
  /// channel needs a fresh invite.
  Future<bool> _confirmLeave(Channel channel) async {
    final confirmed = await showAppDialog<bool>(
      context,
      title: AppStrings.channelLeaveConfirmTitle,
      body: AppStrings.channelLeaveConfirmBody(channel.title),
      actions: const [
        AppDialogAction(
          label: AppStrings.channelLeaveConfirmAction,
          value: true,
          isPrimary: true,
          isDestructive: true,
        ),
        AppDialogAction.cancel(AppStrings.channelLeaveCancelAction),
      ],
    );
    return confirmed ?? false;
  }

  Future<void> _toggleMembership(Channel channel) async {
    if (channel.isJoined && !await _confirmLeave(channel)) return;
    if (!mounted) return;

    setState(() => _isActionLoading = true);
    final channelRepo = ref.read(channelRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    final success = channel.isJoined
        ? await channelRepo.leaveChannel(channel.chatId)
        : await channelRepo.joinChannel(channel.chatId);

    if (success && mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            channel.isJoined
                ? AppStrings.channelLeft(channel.title)
                : AppStrings.channelJoined(channel.title),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    ref.invalidate(channelDetailProvider(widget.channelId));
    ref.invalidate(channelsProvider);
    ref.invalidate(feedPostsProvider);
    if (mounted) setState(() => _isActionLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final channelAsync = ref.watch(channelDetailProvider(widget.channelId));
    final channel = channelAsync.value;

    // Keeps the focus controller alive while this screen is open; it owns the
    // dwell timers behind read tracking.
    ref.listen(feedFocusControllerProvider, (_, _) {});

    ref.watch(mutedChannelsProvider);
    final mutes = ref.read(mutedChannelsProvider.notifier);
    final isMuted = mutes.isMuted(
      widget.channelId,
      chatId: channel?.chatId,
      username: channel?.username,
    );
    final mutedUntil = mutes.mutedUntil(
      widget.channelId,
      chatId: channel?.chatId,
      username: channel?.username,
    );

    final muteTooltip = isMuted
        ? (mutedUntil != null
              ? AppStrings.channelsMutedUntil(TimeUtils.untilWhen(mutedUntil))
              : AppStrings.channelsUnmuteAction)
        : AppStrings.channelsMuteAction;

    if (channel == null) {
      final theme = Theme.of(context);
      return Scaffold(
        appBar: AppBar(
          title: Text(
            AppStrings.channelFallbackTitle,
            style: AppTypography.heading(color: theme.colorScheme.onSurface),
          ),
        ),
        body: channelAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (err, _) => ChannelRetry(
            message: AppStrings.channelLoadFailed,
            detail: err.toString(),
            onRetry: _refresh,
          ),
          data: (_) => ChannelRetry(
            message: AppStrings.channelUnavailable,
            onRetry: _refresh,
          ),
        ),
      );
    }

    final geometry = ChannelProfileGeometry(MediaQuery.paddingOf(context).top);

    return Scaffold(
      // The cover runs under the status bar, which is always over a photo
      // or the dark bar.
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            // Starts under the bar, so the tabs pin below it.
            Positioned.fill(
              top: geometry.barExtent,
              child: _buildBody(
                channel,
                geometry: geometry,
                isMuted: isMuted,
                muteTooltip: muteTooltip,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ChannelProfileBar(
                channel: channel,
                geometry: geometry,
                scroll: _scroll,
                // Shown only when Telegram offers statistics for it.
                onAnalyticsPressed: channel.canViewStatistics
                    ? () => context.push(
                        ChannelStatsScreen.routeFor(channel.chatId),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyLink(Channel channel) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(text: 'https://t.me/${channel.username}'),
    );
    messenger.showSnackBar(
      const SnackBar(
        content: Text(AppStrings.channelLinkCopied),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildBody(
    Channel channel, {
    required ChannelProfileGeometry geometry,
    required bool isMuted,
    required String muteTooltip,
  }) {
    final pinnedAsync = ref.watch(channelPinnedPostProvider(widget.channelId));

    return RefreshIndicator(
      color: AppColors.accent,
      // Refreshes the underlying fetch; channelPostsProvider is derived, so
      // invalidating it alone would do nothing.
      onRefresh: _refresh,
      // A `NestedScrollView` so tabs can be swiped. The header collapses with
      // whichever body is on screen, and each body paginates through its own
      // `NotificationListener` (see `_onTabScroll`).
      child: NestedScrollView(
        controller: _scroll,
        // The cover paints up under the bar, above this view's top.
        clipBehavior: Clip.none,
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: ChannelCover(
              channel: channel,
              geometry: geometry,
              scroll: _scroll,
              isMuted: isMuted,
              muteTooltip: muteTooltip,
              onMutePressed: () => MuteSheet.show(
                context,
                ref,
                channelId: widget.channelId,
                chatId: channel.chatId,
                username: channel.username,
              ),
              onSharePressed: channel.username == null
                  ? null
                  : () => _copyLink(channel),
              isActionBusy: _isActionLoading,
              onJoinPressed: () => _toggleMembership(channel),
            ),
          ),
          SliverToBoxAdapter(
            child: ChannelIdentity(
              channel: channel,
              // A guest channel isn't in TDLib to ask about.
              similarCount: _isGuestChannel
                  ? null
                  : ref
                        .watch(similarChannelCountProvider(channel.chatId))
                        .value,
              onSimilarTap: () =>
                  context.push(SimilarChannelsScreen.routeFor(channel.chatId)),
            ),
          ),
          if (pinnedAsync.value != null)
            SliverToBoxAdapter(child: PinnedPostCard(post: pinnedAsync.value!)),
          // Absorbed so each tab's list starts below the pinned tabs.
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarHeader(
                tabs: _tabs,
                controller: _tabController,
                background: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [for (final tab in _tabs) _tabBody(channel, tab)],
        ),
      ),
    );
  }

  /// One tab's scrollable. `ScrollNotification` drives pagination and
  /// `ScrollMetricsNotification` catches a first page too short to scroll.
  /// No `ScrollController`, so the shared header can still collapse.
  Widget _tabBody(Channel channel, ChannelTab tab) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (tab == _selectedTab) _fillViewport(metrics: notification.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) => _onTabScroll(tab, notification),
        child: Builder(
          builder: (context) => CustomScrollView(
            key: PageStorageKey<ChannelTab>(tab),
            slivers: [
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
              ),
              ..._tabSlivers(channel, tab),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _tabSlivers(Channel channel, ChannelTab tab) {
    if (tab.isHistory) return _historySlivers();

    final state = ref.watch(
      channelTabPostsProvider(ChannelTabKey(widget.channelId, tab)),
    );

    if (state.error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ChannelRetry(
            message: AppStrings.channelTabFailed,
            detail: state.error.toString(),
            onRetry: _refresh,
          ),
        ),
      ];
    }

    if (!state.hasFetched || (state.isLoading && state.posts.isEmpty)) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xxxl),
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          ),
        ),
      ];
    }

    if (state.posts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyTab(message: _emptyMessageFor(tab)),
        ),
      ];
    }

    return [
      switch (tab.layout) {
        ChannelTabLayout.grid => ChannelMediaGrid(posts: state.posts),
        ChannelTabLayout.fileRows => ChannelFileList(posts: state.posts),
        ChannelTabLayout.cards => _postCardSliver(state.posts),
      },
      if (state.isLoading) const _LoadingFooter(),
    ];
  }

  List<Widget> _historySlivers() {
    final postsAsync = ref.watch(channelPostsProvider(widget.channelId));

    return postsAsync.when(
      loading: () => const [
        SliverFillRemaining(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        ),
      ],
      error: (err, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ChannelRetry(
            message: AppStrings.channelPostsFailed,
            detail: err.toString(),
            onRetry: _refresh,
          ),
        ),
      ],
      data: (posts) {
        if (posts.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: ChannelRetry(
                message: AppStrings.channelNoPosts,
                onRetry: _refresh,
              ),
            ),
          ];
        }
        return [_postCardSliver(posts, trackReads: true)];
      },
    );
  }

  Widget _postCardSliver(List<Post> posts, {bool trackReads = false}) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final post = posts[index];
        final isHighlighted =
            widget.highlightMessageId != null &&
            post.messageId == widget.highlightMessageId;

        final card = PostCard(
          post: post,
          isHighlighted: isHighlighted,
          onTap: () {
            if (!_isGuestChannel) ref.read(markPostAsReadProvider(post.id));
            context.push('/post/${post.id}');
          },
        );

        // Read tracking on the history tab only, so scrolling a filtered list
        // doesn't mark posts read on every device.
        return trackReads
            ? PostVisibilityReporter(postId: post.id, child: card)
            : card;
      }, childCount: posts.length),
    );
  }

  static String _emptyMessageFor(ChannelTab tab) => switch (tab) {
    ChannelTab.posts => AppStrings.channelNoPosts,
    ChannelTab.media => AppStrings.channelTabNoMedia,
    ChannelTab.files => AppStrings.channelTabNoFiles,
    ChannelTab.links => AppStrings.channelTabNoLinks,
    ChannelTab.voice => AppStrings.channelTabNoVoice,
  };
}

/// The tab strip, pinned under the app bar while the profile scrolls away.
class _TabBarHeader extends SliverPersistentHeaderDelegate {
  final TabController controller;
  final Color background;

  /// Which tabs to draw (only Posts for a guest channel).
  final List<ChannelTab> tabs;

  static const double _height = 46;

  _TabBarHeader({
    required this.controller,
    required this.background,
    required this.tabs,
  });

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      height: _height,
      color: background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: TabBar(
              controller: controller,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: theme.colorScheme.onSurface,
              unselectedLabelColor: secondary,
              dividerColor: Colors.transparent,
              tabs: [for (final tab in tabs) Tab(text: _labelFor(tab))],
            ),
          ),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ],
      ),
    );
  }

  static String _labelFor(ChannelTab tab) => switch (tab) {
    ChannelTab.posts => AppStrings.channelTabPosts,
    ChannelTab.media => AppStrings.channelTabMedia,
    ChannelTab.files => AppStrings.channelTabFiles,
    ChannelTab.links => AppStrings.channelTabLinks,
    ChannelTab.voice => AppStrings.channelTabVoice,
  };

  @override
  bool shouldRebuild(_TabBarHeader oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.background != background ||
      !listEquals(oldDelegate.tabs, tabs);
}

class _EmptyTab extends StatelessWidget {
  final String message;

  const _EmptyTab({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Text(
          message,
          style: AppTypography.body(color: secondary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _LoadingFooter extends StatelessWidget {
  const _LoadingFooter();

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

/// An error message with a retry button.
class ChannelRetry extends StatelessWidget {
  final String message;
  final String? detail;
  final Future<void> Function() onRetry;

  const ChannelRetry({
    super.key,
    required this.message,
    this.detail,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: secondary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              style: AppTypography.subheading(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (detail != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                detail!,
                style: AppTypography.actionCount(color: secondary),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}
