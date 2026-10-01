import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/compose/presentation/post_progress_provider.dart';

/// The progress bar over the timeline while a post is going out. Sits on the
/// header's bottom edge so it takes no room and doesn't shift the feed.
/// Indeterminate when there are no bytes to count.
class PostProgressBar extends ConsumerWidget {
  static const double height = 3;

  const PostProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(postSendTrackerProvider);
    if (progress == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final track = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final color = switch (progress.status) {
      PostSendStatus.uploading => AppColors.accent,
      PostSendStatus.sent => AppColors.repost,
      PostSendStatus.failed => AppColors.error,
    };

    return Semantics(
      liveRegion: true,
      label: AppStrings.composeProgressLabel(
        progress.status,
        progress.targetLabel,
      ),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          // A failure has no fraction to show.
          value: progress.status == PostSendStatus.failed
              ? 1
              : progress.fraction,
          minHeight: height,
          backgroundColor: track,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}
