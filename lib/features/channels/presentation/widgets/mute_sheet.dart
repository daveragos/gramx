import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/mute_registry.dart';

/// Asks how long to hide a channel for, the way Telegram does.
///
/// Muting used to be forever-or-nothing, which meant the useful case — "not
/// during this news cycle" — either didn't happen or was never undone. An
/// already-muted channel skips the menu: the only thing left to offer is
/// letting it back in.
abstract class MuteSheet {
  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required String channelId,
    int? chatId,
    String? username,
  }) async {
    final notifier = ref.read(mutedChannelsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    if (notifier.isMuted(channelId, chatId: chatId, username: username)) {
      notifier.unmute(channelId, chatId: chatId, username: username);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(AppStrings.channelVisibleInFeed),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final choice = await showModalBottomSheet<MuteDuration>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _MuteDurationSheet(),
    );
    if (choice == null) return;

    notifier.mute(
      channelId,
      chatId: chatId,
      username: username,
      duration: choice,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(AppStrings.channelMutedFor(muteDurationLabel(choice))),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

String muteDurationLabel(MuteDuration duration) => switch (duration) {
      MuteDuration.oneHour => AppStrings.muteOneHour,
      MuteDuration.eightHours => AppStrings.muteEightHours,
      MuteDuration.twoDays => AppStrings.muteTwoDays,
      MuteDuration.forever => AppStrings.muteForever,
    };

class _MuteDurationSheet extends StatelessWidget {
  const _MuteDurationSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text(
              AppStrings.muteSheetTitle,
              style: AppTypography.heading(color: primary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Text(
              AppStrings.muteSheetBody,
              style: AppTypography.body(color: secondary),
            ),
          ),
          for (final duration in MuteDuration.values)
            ListTile(
              leading: Icon(
                duration == MuteDuration.forever
                    ? Icons.notifications_off_rounded
                    : Icons.schedule_rounded,
                color: duration == MuteDuration.forever
                    ? AppColors.error
                    : primary,
              ),
              title: Text(
                muteDurationLabel(duration),
                style: AppTypography.body(color: primary),
              ),
              onTap: () => Navigator.pop(context, duration),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
