import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/l10n/legal_text.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/auth/presentation/widgets/auth_inline_error_banner.dart';

class AuthSelectionPage extends StatelessWidget {
  final AuthState authState;
  final AuthController controller;

  const AuthSelectionPage({
    super.key,
    required this.authState,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final isSubmitting = authState.isSubmitting;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent,
                  AppColors.accent.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Welcome to gramX',
            style: AppTypography.heading(color: primaryColor).copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your Telegram channels, as one timeline.',
            style: AppTypography.body(color: secondaryColor),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 3),
          if (authState.errorMessage != null) ...[
            AuthInlineErrorBanner(message: authState.errorMessage!),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
              ),
              onPressed: isSubmitting
                  ? null
                  : () => controller.selectPhoneLogin(),
              icon: const Icon(Icons.phone_android_rounded, size: 20),
              label: const Text(
                'Continue with Phone Number',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              onPressed: isSubmitting
                  ? null
                  : () => controller.requestQrLogin(),
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: Text(
                isSubmitting ? 'Generating QR...' : 'Log in via QR Code',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Shown before signing in, not buried in settings afterwards: this
          // is the moment someone hands over a login code, and it is the
          // moment they should be able to read what they are agreeing to.
          const LegalAgreementLine(),
          const Spacer(),
        ],
      ),
    );
  }
}

/// "By signing in you agree to the Terms of Service and Privacy Policy",
/// with both parts tappable.
class LegalAgreementLine extends StatelessWidget {
  const LegalAgreementLine({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final base = AppTypography.actionCount(color: secondary);
    final link = base.copyWith(
      color: AppColors.accent,
      fontWeight: FontWeight.w600,
    );

    TextSpan document(String label, String route) => TextSpan(
      text: label,
      style: link,
      recognizer: TapGestureRecognizer()..onTap = () => context.push(route),
    );

    return Semantics(
      link: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: AppStrings.legalAgreementLead, style: base),
            document(AppStrings.settingsTerms, LegalTexts.termsRoute),
            TextSpan(text: AppStrings.legalAgreementMiddle, style: base),
            document(AppStrings.settingsPrivacy, LegalTexts.privacyRoute),
            TextSpan(text: AppStrings.legalAgreementEnd, style: base),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
