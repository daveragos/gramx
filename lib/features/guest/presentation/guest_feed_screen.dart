import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/features/guest/presentation/widgets/guest_banner.dart';

/// The guest's feed: posts from every added public channel, newest first.
///
/// Purely chronological, with no unread state and no live updates, since
/// `t.me/s/` is a static page; pull to refresh fetches again. Posts stay on
/// screen during a refresh, failures are shown, and older pages load on
/// scroll (see [GuestFeedNotifier.loadMore]).
class GuestFeedScreen extends ConsumerWidget {
  /// Distance from the bottom at which the next page is requested.
  static const double _loadMoreThreshold = 300;

  const GuestFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(guestFeedProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    // Drawn from the value, which Riverpod keeps during a refresh, so the
    // scroll position survives. Without muted channels, which a guest can
    // mute from a post's menu but still saw.
    final feed = (feedAsync.value ?? GuestFeed.empty).withoutPosts(
      (post) => isPostMuted(post, ref.watch(mutedChannelsProvider)),
    );
    final isFirstLoad = feedAsync.isLoading && feedAsync.value == null;

    return ChromeScaffold(
      header: ChromeHeaderRow(
        title: AppStrings.appName,
        actions: [
          IconButton(
            tooltip: AppStrings.guestAddTooltip,
            icon: Icon(Icons.add_circle_outline, color: secondary),
            onPressed: () => context.push('/guest/channels'),
          ),
        ],
      ),
      body: (context, topPadding, bottomPadding) {
        return RefreshIndicator(
          color: AppColors.accent,
          // Keeps the spinner below the header.
          edgeOffset: topPadding,
          onRefresh: () async {
            ref.invalidate(guestFeedProvider);
            await ref.read(guestFeedProvider.future);
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.depth == 0 &&
                  notification.metrics.pixels >=
                      notification.metrics.maxScrollExtent -
                          _loadMoreThreshold) {
                // Fires every frame near the bottom; the notifier guards it,
                // since `t.me/s/` rate-limits the client.
                ref.read(guestFeedProvider.notifier).loadMore();
              }
              return false;
            },
            child: CustomScrollView(
              slivers: [
                SliverPadding(padding: EdgeInsets.only(top: topPadding)),
                const SliverToBoxAdapter(child: GuestBanner()),
                if (feed.posts.isNotEmpty && feed.failures.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _FailureStrip(
                      failures: feed.failures,
                      secondary: secondary,
                      onRetry: () =>
                          ref.read(guestFeedProvider.notifier).retryFailed(),
                    ),
                  ),
                ..._content(
                  context: context,
                  ref: ref,
                  feed: feed,
                  isFirstLoad: isFirstLoad,
                  error: feedAsync.value == null ? feedAsync.error : null,
                  secondary: secondary,
                ),
                SliverPadding(padding: EdgeInsets.only(bottom: bottomPadding)),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _content({
    required BuildContext context,
    required WidgetRef ref,
    required GuestFeed feed,
    required bool isFirstLoad,
    required Object? error,
    required Color secondary,
  }) {
    if (feed.posts.isNotEmpty) {
      return [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => PostCard(
              post: feed.posts[index],
              // No read tracking for guests.
              onTap: () => context.push('/post/${feed.posts[index].id}'),
            ),
            childCount: feed.posts.length,
          ),
        ),
        SliverToBoxAdapter(
          child: _Footer(feed: feed, secondary: secondary),
        ),
      ];
    }

    // First load: shows which channel is being fetched, since each request
    // can take up to 15 seconds.
    if (isFirstLoad || feed.isFilling) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.accent),
                if (feed.total > 0) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    AppStrings.guestFeedLoading(feed.answered + 1, feed.total),
                    style: AppTypography.body(color: secondary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ];
    }

    // Every channel failed, or the list couldn't be read: show the reason.
    if (feed.hasFailedEntirely || error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Empty(
            icon: Icons.cloud_off_rounded,
            title: AppStrings.guestFeedFailedTitle,
            body: feed.failures.isEmpty
                ? error.toString()
                : feed.failures.map((f) => f.message).toSet().join('\n\n'),
            secondary: secondary,
            action: (
              label: AppStrings.guestRetryAction,
              onPressed: () => feed.failures.isEmpty
                  ? ref.invalidate(guestFeedProvider)
                  : ref.read(guestFeedProvider.notifier).retryFailed(),
            ),
          ),
        ),
      ];
    }

    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: _Empty(
          icon: Icons.add_circle_outline,
          title: AppStrings.guestFeedEmptyTitle,
          body: AppStrings.guestFeedEmptyBody,
          secondary: secondary,
          action: (
            label: AppStrings.guestAddAction,
            onPressed: () => context.push('/guest/channels'),
          ),
        ),
      ),
    ];
  }
}

/// Shown under the last post: loading progress or the end of the feed.
class _Footer extends StatelessWidget {
  final GuestFeed feed;
  final Color secondary;

  const _Footer({required this.feed, required this.secondary});

  @override
  Widget build(BuildContext context) {
    final Widget child;

    if (feed.isFilling) {
      child = _Line(
        text: AppStrings.guestFeedLoading(feed.answered + 1, feed.total),
        secondary: secondary,
        spinner: true,
      );
    } else if (feed.isLoadingMore) {
      child = const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.accent,
        ),
      );
    } else if (feed.exhausted) {
      child = _Line(text: AppStrings.guestFeedEnd, secondary: secondary);
    } else {
      return const SizedBox(height: AppSpacing.xl);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(child: child),
    );
  }
}

class _Line extends StatelessWidget {
  final String text;
  final Color secondary;
  final bool spinner;

  const _Line({
    required this.text,
    required this.secondary,
    this.spinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (spinner) ...[
          const SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(text, style: AppTypography.actionCount(color: secondary)),
      ],
    );
  }
}

/// A line above the feed naming channels that failed while others loaded.
class _FailureStrip extends StatelessWidget {
  final List<GuestChannelFailure> failures;
  final Color secondary;
  final VoidCallback onRetry;

  const _FailureStrip({
    required this.failures,
    required this.secondary,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border, width: 0.5)),
      ),
      padding: const EdgeInsets.only(
        left: AppSpacing.postPadding,
        right: AppSpacing.sm,
        top: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 17, color: secondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.guestChannelsFailed(failures.length),
                  style: AppTypography.body(color: theme.colorScheme.onSurface),
                ),
                Text(
                  failures.map((f) => '@${f.username}').join(', '),
                  style: AppTypography.actionCount(color: secondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              AppStrings.guestRetryAction,
              style: AppTypography.button(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color secondary;
  final ({String label, VoidCallback onPressed})? action;

  const _Empty({
    required this.icon,
    required this.title,
    required this.body,
    required this.secondary,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: secondary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTypography.subheading(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              style: AppTypography.body(color: secondary),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                ),
                onPressed: action!.onPressed,
                child: Text(action!.label, style: AppTypography.button()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
