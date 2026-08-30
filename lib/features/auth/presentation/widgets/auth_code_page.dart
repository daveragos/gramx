import 'package:flutter/material.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:flutter/services.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/auth/presentation/widgets/auth_inline_error_banner.dart';

class AuthCodePage extends StatelessWidget {
  final AuthState authState;
  final AuthController controller;
  final TextEditingController codeController;

  const AuthCodePage({
    super.key,
    required this.authState,
    required this.controller,
    required this.codeController,
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
              Icons.mark_email_read_rounded,
              color: AppColors.accent,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Check your Telegram app',
            style: AppTypography.heading(color: primaryColor).copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a login code to your Telegram app'
            '${authState.phoneNumber != null ? ' (${authState.phoneNumber})' : ''}.',
            style: AppTypography.body(color: secondaryColor),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 10,
              color: primaryColor,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              hintText: AppStrings.authCodeHint,
              hintStyle: TextStyle(
                color: secondaryColor.withValues(alpha: 0.3),
                fontSize: 28,
                letterSpacing: 10,
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
                      final code = codeController.text.trim();
                      if (code.isNotEmpty) {
                        controller.submitCode(code);
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
                      'Verify Code',
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
