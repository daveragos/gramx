import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/compose/presentation/post_progress_provider.dart';

///
/// Sits on the header's bottom edge, so it travels with the chrome and takes no
/// room in the layout — a bar that pushed the feed down and pulled it back up
/// again would move what somebody is reading, twice, for something that is not
/// about them.
///
/// Determinate while there are bytes to count and indeterminate otherwise,
/// which is the honest drawing of a text post: it is working, and there is
/// nothing to measure.
class PostProgressBar extends ConsumerWidget {
  /// Thin on purpose. This is a status line, not a dialog.
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
          // A failure has no fraction to show — it stopped, wherever it was.
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
