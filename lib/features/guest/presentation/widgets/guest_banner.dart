import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';

/// The standing reminder that this is a preview, with the way out of it.
///
/// Not a dismissible toast: a guest is missing reactions, comments, bookmarks
/// and read state, and the honest thing is to say so wherever they are rather
/// than once at the start. Draws nothing at all when signed in.
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

/// What a guest gets instead of a control that would need an account.
///
/// Shown from the tap, rather than leaving the control inert. A button that
/// responds to touch and changes nothing is the bug the hard rules in
/// docs/CONVENTIONS.md name; a button that explains itself is a control that
/// works.
abstract class GuestSignInSheet {
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      // The root navigator, so the sheet is not painted under the shell's
      // bottom bar — the same fix as `0b3ba3d`.
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
