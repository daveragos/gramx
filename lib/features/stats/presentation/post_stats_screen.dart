import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/channels/presentation/channel_profile_screen.dart'
    show ChannelRetry;
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/stats/domain/channel_stats.dart';
import 'package:gramx/features/stats/domain/post_stats.dart';
import 'package:gramx/features/stats/presentation/stats_providers.dart';
import 'package:gramx/features/stats/presentation/widgets/stat_figure_tile.dart';
import 'package:gramx/features/stats/presentation/widgets/stat_section.dart';

///
/// The three counts across the top are the post's own and cost nothing: they
/// are already on the message. The two charts below are `getMessageStatistics`,
/// and "Shared by" is `getMessagePublicForwards` — Telegram's nearest thing to
/// chat is not the channel's business.
class PostStatsScreen extends ConsumerWidget {
  static const String route = '/post/:postId/stats';

  static String routeFor(int chatId, int messageId) =>
      '/post/${chatId}_$messageId/stats';

  /// `<chatId>_<messageId>`, the id every screen in this app addresses a post
  /// by. See `TdlibMappers`.
  final String postId;

  const PostStatsScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final parts = postId.split('_');
    final chatId = parts.length == 2 ? int.tryParse(parts[0]) : null;
    final messageId = parts.length == 2 ? int.tryParse(parts[1]) : null;

    final title = Text(
      AppStrings.statsPostTitle,
      style: AppTypography.heading(color: theme.colorScheme.onSurface),
    );

    if (chatId == null || messageId == null) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: const Center(child: _Unavailable()),
      );
    }

    final request = (
      chatId: chatId,
      messageId: messageId,
      isDark: theme.brightness == Brightness.dark,
    );
    final statsAsync = ref.watch(postStatsProvider(request));
    final post = ref.watch(postDetailProvider(postId)).value;

    return Scaffold(
      appBar: AppBar(title: title),
      body: statsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (error, _) => ChannelRetry(
          message: AppStrings.statsLoadFailed,
          detail: error.toString(),
          onRetry: () async => ref.invalidate(postStatsProvider(request)),
        ),
        data: (stats) {
          if (stats == null) return const Center(child: _Unavailable());
          return _Body(
            chatId: chatId,
            messageId: messageId,
            stats: stats,
            post: post,
          );
        },
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(
        AppStrings.statsPostUnavailable,
        textAlign: TextAlign.center,
        style: AppTypography.body(
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final int chatId;
  final int messageId;
  final PostStats stats;

  /// The post itself, when the screen that pushed here already had it. Null
  /// only while the single-post fetch is in flight, and the charts do not wait
  /// on it — the numbers are the point of this screen, not the words.
  final Post? post;

  const _Body({
    required this.chatId,
    required this.messageId,
    required this.stats,
    this.post,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final shares = ref
        .watch(publicSharesProvider((chatId: chatId, messageId: messageId)))
        .value;

    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      children: [
        if (post != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post!.text?.trim().isNotEmpty == true
                      ? post!.text!.trim()
                      : AppStrings.statsPostFallback,
                  style: AppTypography.body(color: theme.colorScheme.onSurface),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  TimeUtils.fullDateTime(post!.publishedAt),
                  style: AppTypography.timestamp(color: secondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _PostFigures(post: post!),
        ],
        StatSection(
          chatId: chatId,
          title: AppStrings.statsPostInteractions,
          source: stats.interactionGraph,
          slug: 'post-$messageId-interactions',
        ),
        StatSection(
          chatId: chatId,
          title: AppStrings.statsPostReactions,
          source: stats.reactionGraph,
          slug: 'post-$messageId-reactions',
        ),
        // The heading waits for the answer. A heading over a space that is
        // about to fill is the same fault as one over a space that never
        // will — see the Who-to-follow note in docs/ROADMAP.md T20-1.
        if (shares != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              AppStrings.statsPublicShares,
              style: AppTypography.subheading(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        if (shares != null && shares.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Text(
              AppStrings.statsPublicSharesEmpty,
              style: AppTypography.body(color: secondary),
            ),
          ),
        for (final share in shares ?? const [])
          _ShareRow(share: share, secondary: secondary),
      ],
    );
  }
}

/// The post's own counts, in the same tiles the channel overview uses.
///
/// They carry no growth arrow: a post has one lifetime and nothing to compare
/// it against, and [StatFigure.hasGrowth] is what keeps the arrow off rather
/// than a second widget.
class _PostFigures extends StatelessWidget {
  final Post post;

  const _PostFigures({required this.post});

  @override
  Widget build(BuildContext context) {
    final reactions = post.reactions.values.fold(0, (sum, count) => sum + count);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: StatFigureTile(
              label: AppStrings.statViews,
              figure: StatFigure(value: post.viewCount.toDouble()),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: StatFigureTile(
              label: AppStrings.statReposts,
              figure: StatFigure(value: post.forwardCount.toDouble()),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: StatFigureTile(
              label: AppStrings.statLikes,
              figure: StatFigure(value: reactions.toDouble()),
            ),
          ),
        ],
      ),
    );
  }
}

/// A channel that forwarded this post, and what the forward earned there.
class _ShareRow extends StatelessWidget {
  final PublicShare share;
  final Color secondary;

  const _ShareRow({required this.share, required this.secondary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return InkWell(
      // The forwarded copy, in the channel that made it — which is the post a
      // reader following this row is asking to see.
      onTap: () => context.push('/post/${share.chatId}_${share.messageId}'),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: border, width: 0.5)),
        ),
        child: Row(
          children: [
            ChannelAvatar(
              title: share.title,
              avatarPath: share.avatarPath,
              avatarFileId: share.avatarFileId,
              radius: AppSpacing.avatarSizeSmall / 2,
            ),
            const SizedBox(width: AppSpacing.avatarGap),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      share.title,
                      style: AppTypography.displayName(
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (share.isVerified) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Semantics(
                      label: AppStrings.a11yVerified,
                      child: const Icon(
                        Icons.verified,
                        size: 14,
                        color: AppColors.verified,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              AppStrings.statsSharedViews(
                TimeUtils.formatCount(share.viewCount),
              ),
              style: AppTypography.timestamp(color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}
