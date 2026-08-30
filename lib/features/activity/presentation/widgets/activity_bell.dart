import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/activity/presentation/activity_providers.dart';
import 'package:gramx/features/activity/presentation/activity_screen.dart';

/// The way into Activity from the feed header.
///
/// Channels and stays that way, so this is the header entry point instead —
///
/// The count costs nothing: it is summed from what the update stream has
/// already pushed into the chat cache, never from the Activity list itself,
/// which spends requests and is only built when the screen is opened.
class ActivityBell extends ConsumerWidget {
  const ActivityBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(activityBadgeProvider);
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: AppStrings.a11yActivity(count),
      child: IconButton(
        tooltip: AppStrings.activityTitle,
        onPressed: () => context.push(ActivityScreen.route),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              count > 0
                  ? Icons.notifications_rounded
                  : Icons.notifications_none_rounded,
              color: theme.colorScheme.onSurface,
            ),
            if (count > 0)
              Positioned(
                top: -3,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                    // A ring in the header's own colour, so the badge reads as
                    // sitting on the bell rather than behind it.
                    border: Border.all(
                      color: theme.scaffoldBackgroundColor,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    AppStrings.activityBadge(count),
                    textAlign: TextAlign.center,
                    style: AppTypography.timestamp(color: Colors.white).copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
