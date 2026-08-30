import 'package:flutter/material.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/auth/presentation/widgets/auth_inline_error_banner.dart';

class AuthPasswordPage extends StatelessWidget {
  final AuthState authState;
  final AuthController controller;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;

  const AuthPasswordPage({
    super.key,
    required this.authState,
    required this.controller,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.accent,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Enter your 2FA password',
            style: AppTypography.heading(color: primaryColor).copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your account is protected with a cloud password.',
            style: AppTypography.body(color: secondaryColor),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            autofocus: true,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: primaryColor,
            ),
            decoration: InputDecoration(
              hintText: AppStrings.authPasswordHint,
              hintStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.5)),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 16, right: 8),
                child: Icon(Icons.lock_rounded, color: AppColors.accent, size: 22),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: secondaryColor,
                  size: 22,
                ),
                onPressed: onToggleObscure,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              filled: true,
              fillColor: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.accent, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor, width: 1),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (authState.errorMessage != null) ...[
            AuthInlineErrorBanner(message: authState.errorMessage!),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
              ),
              onPressed: authState.isSubmitting
                  ? null
                  : () {
                      final pwd = passwordController.text.trim();
                      if (pwd.isNotEmpty) {
                        controller.submitPassword(pwd);
                      }
                    },
              child: authState.isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Log In',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
