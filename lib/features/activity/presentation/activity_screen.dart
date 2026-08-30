import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
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
/// **Reached from the drawer and from the bell in the feed header, not from
/// Channels there; that stays as it is.
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

    return ChromeScaffold(
      header: const ChromeHeaderRow(title: AppStrings.activityTitle),
      body: (context, topPadding, bottomPadding) => RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async => ref.invalidate(activityFeedProvider),
        child: activity.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (error, _) => _Message(
            topPadding: topPadding,
            title: AppStrings.activityErrorTitle,
            body: AppStrings.activityError(error),
            primary: primary,
            secondary: secondary,
          ),
          data: (items) {
            if (items.isEmpty) {
              return _Message(
                topPadding: topPadding,
                title: AppStrings.activityEmptyTitle,
                body: AppStrings.activityEmptyBody,
                primary: primary,
                secondary: secondary,
              );
            }

            return ListView.separated(
              padding: EdgeInsets.only(
                top: topPadding,
                bottom: bottomPadding + AppSpacing.xxl,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, thickness: 0.5, color: borderColor),
              itemBuilder: (context, index) => _ActivityRow(
                item: items[index],
                primary: primary,
                secondary: secondary,
              ),
            );
          },
        ),
      ),
    );
  }
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
  final double topPadding;
  final String title;
  final String body;
  final Color primary;
  final Color secondary;

  const _Message({
    required this.topPadding,
    required this.title,
    required this.body,
    required this.primary,
    required this.secondary,
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
