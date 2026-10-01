import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/core/l10n/app_strings.dart';

/// What the Messages tab shows a guest, who has no account to message from.
///
/// The tab stays in place because `goBranch` addresses branches by index, and
/// removing one would shift every tab after it.
class GuestMessagesPlaceholder extends ConsumerWidget {
  const GuestMessagesPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return ChromeScaffold(
      header: const ChromeHeaderRow(title: AppStrings.messagesTitle),
      body: (context, topPadding, bottomPadding) => Padding(
        padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forum_outlined, size: 44, color: secondary),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  AppStrings.messagesGuestTitle,
                  style: AppTypography.subheading(
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.messagesGuestBody,
                  style: AppTypography.body(color: secondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                      vertical: AppSpacing.md,
                    ),
                  ),
                  onPressed: () => context.push('/auth'),
                  child: Text(
                    AppStrings.messagesGuestAction,
                    style: AppTypography.button(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
