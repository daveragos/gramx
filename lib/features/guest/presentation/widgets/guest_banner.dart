import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';

/// A persistent banner telling a guest they are in preview mode, with a
/// sign-in button. Not dismissible. Draws nothing when signed in.
class GuestBanner extends ConsumerWidget {
  const GuestBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isGuestModeProvider)) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: border, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.postPadding,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, size: 17, color: secondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.guestBannerTitle,
                  style: AppTypography.body(
                    color: theme.colorScheme.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  AppStrings.guestBannerBody,
                  style: AppTypography.actionCount(color: secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: () => context.push('/auth'),
            child: Text(
              AppStrings.guestBannerAction,
              style: AppTypography.button(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sheet a guest sees on tapping a control that needs an account.
abstract class GuestSignInSheet {
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      // The root navigator, so the sheet is not painted under the shell's
      // bottom bar.
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final secondary = isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.guestSignInSheetTitle,
                  style: AppTypography.heading(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.guestSignInSheetBody,
                  style: AppTypography.body(color: secondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/auth');
                    },
                    child: Text(
                      AppStrings.guestBannerAction,
                      style: AppTypography.button(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      AppStrings.guestSignInSheetDismiss,
                      style: AppTypography.button(color: secondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
