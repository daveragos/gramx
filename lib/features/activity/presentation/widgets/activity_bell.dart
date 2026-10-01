import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/activity/presentation/activity_providers.dart';
import 'package:gramx/features/activity/presentation/activity_screen.dart';

/// The feed header's entry point to Activity, with a badge from
/// [activityBadgeProvider].
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                    // A ring to separate the badge from the bell.
                    border: Border.all(
                      color: theme.scaffoldBackgroundColor,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    AppStrings.activityBadge(count),
                    textAlign: TextAlign.center,
                    style: AppTypography.timestamp(color: Colors.white)
                        .copyWith(
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
