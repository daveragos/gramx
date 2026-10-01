import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/channels/presentation/widgets/add_channel_dialog.dart';

class FeedOnboardingView extends ConsumerWidget {
  const FeedOnboardingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final accountAsync = ref.watch(activeAccountProvider);
    final isLoggedIn = accountAsync.value != null;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.feed_outlined,
                color: AppColors.accent,
                size: 80,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                AppStrings.onboardingWelcome,
                style: AppTypography.heading(
                  color: primaryColor,
                ).copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                isLoggedIn
                    ? AppStrings.onboardingLoggedInBody
                    : AppStrings.onboardingLoggedOutBody,
                style: AppTypography.body(color: secondaryColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              if (!isLoggedIn) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () {
                    // `go`, not `push`: no signed-in screen to return to.
                    context.go('/auth');
                  },
                  child: const Text(
                    AppStrings.onboardingLogIn,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ] else ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () => showAddChannelDialog(context),
                  child: const Text(
                    'Add Public Channel',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
