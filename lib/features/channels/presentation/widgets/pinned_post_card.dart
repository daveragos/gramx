import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';

/// The channel's pinned post, above the tab bar.
///
/// Above rather than inside a tab: it is the one post the channel itself is
/// pointing at, and burying it under a tab the reader has to find first would
/// same reason.
///
/// Not wrapped in a [PostVisibilityReporter]: the pinned post is usually old,
/// it sits on screen for as long as the profile is open, and marking it read
/// on a dwell would push that to every Telegram client the reader owns for a
/// post they only scrolled past on the way to the tabs.
class PinnedPostCard extends ConsumerWidget {
  final Post post;

  const PinnedPostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.postPadding,
            top: AppSpacing.sm,
          ),
          child: Semantics(
            label: AppStrings.a11yPinnedPost,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.push_pin_rounded, size: 13, color: secondary),
                const SizedBox(width: 5),
                Text(
                  AppStrings.channelPinnedLabel,
                  style: AppTypography.actionCount(color: secondary)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        PostCard(
          post: post,
          onTap: () {
            ref.read(markPostAsReadProvider(post.id));
            context.push('/post/${post.id}');
          },
        ),
      ],
    );
  }
}
