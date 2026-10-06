import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/widgets/drawer_avatar_button.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/core/text/emoji_presentation.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/activity/domain/activity_item.dart';
import 'package:gramx/features/activity/presentation/activity_providers.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/features/guest/presentation/widgets/guest_bookmarks_placeholder.dart';

/// Mentions, replies and reactions as one newest-first list, on its own tab
/// like X's notifications. The shell reloads it when the tab opens with the
/// bell lit; otherwise everything shown has already been marked seen.
class ActivityScreen extends ConsumerWidget {
  static const route = '/activity';

  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A guest has no account, so nothing can mention or react to them.
    if (!ref.watch(readerCapabilitiesProvider).canBookmark) {
      return const GuestBookmarksPlaceholder();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final activity = ref.watch(activityFeedProvider);

    // Each tab filters the one loaded list, so switching costs nothing.
    return DefaultTabController(
      length: _ActivityTab.values.length,
      child: ChromeScaffold(
        // The tabs swipe sideways, so the header stays put.
        observeScroll: false,
        header: const ChromeHeaderRow(
          title: AppStrings.activityTitle,
          centerTitle: true,
          leading: DrawerAvatarButton(),
        ),
        headerBottomHeight: kTextTabBarHeight,
        headerBottom: TabBar(
          labelColor: primary,
          unselectedLabelColor: secondary,
          dividerColor: borderColor,
          dividerHeight: 0.5,
          tabs: [for (final tab in _ActivityTab.values) Tab(text: tab.label)],
        ),
        body: (context, topPadding, bottomPadding) => TabBarView(
          children: [
            for (final tab in _ActivityTab.values)
              RefreshIndicator(
                color: AppColors.accent,
                edgeOffset: topPadding,
                onRefresh: () async => ref.invalidate(activityFeedProvider),
                child: activity.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                  error: (error, _) => _Message(
                    title: AppStrings.activityErrorTitle,
                    body: AppStrings.activityError(error),
                    primary: primary,
                    secondary: secondary,
                    topPadding: topPadding,
                  ),
                  data: (all) {
                    final items = tab.filter(all);
                    if (items.isEmpty) {
                      return _Message(
                        title: AppStrings.activityEmptyTitle,
                        body: AppStrings.activityEmptyBody,
                        primary: primary,
                        secondary: secondary,
                        topPadding: topPadding,
                      );
                    }

                    return ListView.separated(
                      padding: EdgeInsets.only(
                        top: topPadding,
                        bottom: bottomPadding + AppSpacing.xxl,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        thickness: 0.5,
                        color: borderColor,
                      ),
                      itemBuilder: (context, index) => _ActivityRow(
                        item: items[index],
                        primary: primary,
                        secondary: secondary,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The three tabs, each a filter over the one loaded list.
enum _ActivityTab {
  all,
  mentions,
  reactions;

  String get label => switch (this) {
    _ActivityTab.all => AppStrings.activityTabAll,
    _ActivityTab.mentions => AppStrings.activityTabMentions,
    _ActivityTab.reactions => AppStrings.activityTabReactions,
  };

  /// The Mentions tab includes replies; reactions have their own tab.
  List<ActivityItem> filter(List<ActivityItem> items) => switch (this) {
    _ActivityTab.all => items,
    _ActivityTab.mentions => [
      for (final item in items)
        if (item.kind != ActivityKind.reaction) item,
    ],
    _ActivityTab.reactions => [
      for (final item in items)
        if (item.kind == ActivityKind.reaction) item,
    ],
  };
}

/// One activity row, laid out like a post card.
class _ActivityRow extends StatelessWidget {
  final ActivityItem item;
  final Color primary;
  final Color secondary;

  const _ActivityRow({
    required this.item,
    required this.primary,
    required this.secondary,
  });

  /// The icon and colour for the event kind.
  (IconData, Color) get _mark => switch (item.kind) {
    ActivityKind.reaction => (Icons.favorite, AppColors.like),
    ActivityKind.reply => (Icons.chat_bubble, AppColors.accent),
    ActivityKind.mention => (Icons.alternate_email, secondary),
  };

  void _open(BuildContext context) {
    if (item.isChannelPost) {
      context.push('/post/${item.chatId}_${item.messageId}');
      return;
    }
    context.push('/chat/${item.chatId}');
  }

  @override
  Widget build(BuildContext context) {
    final (icon, markColor) = _mark;
    final name = item.senderName ?? item.chatTitle;

    return InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.postPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChannelAvatar(
              title: name,
              avatarFileId: item.senderAvatarFileId,
              radius: AppSpacing.avatarSize / 2,
            ),
            const SizedBox(width: AppSpacing.avatarGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Semantics(
                        label: AppStrings.activityKindLabel(item.kind),
                        child: Icon(icon, size: 14, color: markColor),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          AppStrings.activityHeadline(
                            kind: item.kind,
                            who: name,
                            where: item.chatTitle,
                            emoji: item.emoji == null
                                ? null
                                : emojiForDisplay(item.emoji!),
                          ),
                          style: AppTypography.username(color: primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        TimeUtils.relativeTime(item.at),
                        style: AppTypography.timestamp(color: secondary),
                      ),
                    ],
                  ),
                  if (item.preview.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      item.preview,
                      style: AppTypography.body(color: secondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String title;
  final String body;
  final Color primary;
  final Color secondary;

  /// Room for the header that overlays the top.
  final double topPadding;

  const _Message({
    required this.title,
    required this.body,
    required this.primary,
    required this.secondary,
    required this.topPadding,
  });

  @override
  Widget build(BuildContext context) {
    // Scrollable so pull-to-refresh still works with nothing in the list.
    return ListView(
      padding: EdgeInsets.only(top: topPadding + AppSpacing.xxxl),
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              Text(
                title,
                style: AppTypography.subheading(color: primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                body,
                style: AppTypography.body(color: secondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
