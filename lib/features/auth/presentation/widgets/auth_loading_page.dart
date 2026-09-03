import 'package:flutter/material.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/brand_mark.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';

class AuthLoadingPage extends StatelessWidget {
  final AuthState authState;
  final AuthController controller;

  const AuthLoadingPage({
    super.key,
    required this.authState,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The same mark the splash screen draws, still animating. A blue
            // circle with a paper plane was a different-looking screen for the
            // moment before connecting finished, which read as the app flashing
            // an older design at you; a mark that stops moving between the two
            // screens reads as the app having hung.
            const BrandMark(size: 112),
            const SizedBox(height: 24),
            Text(
              AppStrings.authConnecting,
              style: AppTypography.heading(color: theme.colorScheme.onSurface).copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                authState.statusMessage,
                key: ValueKey(authState.statusMessage),
                style: AppTypography.body(color: secondaryColor),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 48),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: secondaryColor,
                side: BorderSide(
                  color: secondaryColor.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () => controller.resetSession(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                AppStrings.authResetConnection,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
