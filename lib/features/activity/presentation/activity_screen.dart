import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// What happened while you were away.
///
/// mentions, replies, reactions — as one reverse-chronological list. The
/// anatomy is the post card's: an avatar in a left gutter, everything else in
/// the right column, hairline separators, no rounding.
///
/// **A pushed page, with a back arrow.** It is reached from the bell in the
/// feed header and from the drawer, and it sits on top of whatever the reader
/// was doing — so it has a real `AppBar`, not the feed's sliding chrome. The
/// sliding chrome watched every scroll under it for the header to retire on,
/// and the tab strip's own horizontal swipe counted: switching to Mentions
/// slid the header and the tabs off the top of the screen and left the list
/// filling the page with no way back but the system gesture.
class ActivityScreen extends ConsumerStatefulWidget {
  static const route = '/activity';

  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    // A lit bell means something happened since the list was last built, so
    // the list is rebuilt. A dark one means the last list is still the right
    // answer — everything in it has been acknowledged, and asking again would
    // answer with nothing at all, which is not what somebody who just read it
    // came back to see.
    if (ref.read(activityBadgeProvider) > 0) {
      ref.invalidate(activityFeedProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
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

    // tab is a filter over it, so switching costs nothing.
    return DefaultTabController(
      length: _ActivityTab.values.length,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          // The way back. `AppBar` draws it because this route was pushed;
          // the tooltip is the framework's own, so a screen reader says "Back".
          leading: BackButton(color: primary, onPressed: () => context.pop()),
          title: Text(
            AppStrings.activityTitle,
            style: AppTypography.heading(color: primary),
          ),
          bottom: TabBar(
            indicatorColor: AppColors.accent,
            labelColor: primary,
            unselectedLabelColor: secondary,
            dividerColor: borderColor,
            dividerHeight: 0.5,
            tabs: [for (final tab in _ActivityTab.values) Tab(text: tab.label)],
          ),
        ),
        body: TabBarView(
          children: [
            for (final tab in _ActivityTab.values)
              RefreshIndicator(
                color: AppColors.accent,
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
                  ),
                  data: (all) {
                    final items = tab.filter(all);
                    if (items.isEmpty) {
                      return _Message(
                        title: AppStrings.activityEmptyTitle,
                        body: AppStrings.activityEmptyBody,
                        primary: primary,
                        secondary: secondary,
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
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

  /// Mentions and replies are both "somebody addressed you", which is what
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

/// One thing that happened.
///
/// The post card's anatomy: the avatar in the gutter, a mark saying which kind
/// of event this was, then who and where, then the words.
class _ActivityRow extends StatelessWidget {
  final ActivityItem item;
  final Color primary;
  final Color secondary;

  const _ActivityRow({
    required this.item,
    required this.primary,
    required this.secondary,
  });

  (IconData, Color) get _mark => switch (item.kind) {
    ActivityKind.reaction => (Icons.favorite, AppColors.like),
    ActivityKind.reply => (Icons.chat_bubble, AppColors.accent),
    ActivityKind.mention => (Icons.alternate_email, secondary),
  };

  void _open(BuildContext context) {
    // A mention inside a channel is a post; anywhere else it is a chat. Both
    // routes exist already, and both land on the message itself.
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
                            emoji: item.emoji,
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

  const _Message({
    required this.title,
    required this.body,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    // Scrollable so pull-to-refresh still works with nothing in the list.
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.xxxl),
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
