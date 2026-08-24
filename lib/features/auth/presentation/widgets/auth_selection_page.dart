import 'package:flutter/gestures.dart';
import 'package:gramx/features/settings/data/settings_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          // The welcome and the two buttons are one block, centred together.
          // Pushing them apart with spacers left a hand's width of nothing in
          // the middle of the screen and the buttons stranded at the bottom.
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The launcher mark, unframed: it carries its own shape,
                    // and a border around it never lined up with the artwork.
                    Image.asset(
                      'assets/icon/app_icon.png',
                      width: 88,
                      height: 88,
                      semanticLabel: AppStrings.appName,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      AppStrings.onboardingWelcome,
                      style: AppTypography.heading(color: primaryColor).copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.authTagline,
                      style: AppTypography.body(color: secondaryColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
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
                          AppStrings.authContinueWithPhone,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
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
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
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
                          isSubmitting
                              ? AppStrings.authGeneratingQr
                              : AppStrings.authLogInWithQr,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // The third way in. Below the two real sign-ins and styled
                    // plainly, because it is the lesser thing: a guest reads
                    // public channels and nothing else.
                    const _BrowseAsGuestButton(),
                  ],
                ),
              ),
            ),
          ),
          // Pinned to the bottom: it is the last thing read before agreeing.
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.lg),
            child: LegalAgreementLine(),
          ),
        ],
      ),
    );
  }
}

/// Enters guest mode and lets the router take the reader into the shell.
///
/// A `ConsumerWidget` of its own so [AuthSelectionPage] can stay a plain
/// `StatelessWidget` — it takes its controller as a parameter and has no `ref`.
class _BrowseAsGuestButton extends ConsumerWidget {
  const _BrowseAsGuestButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Column(
      children: [
        TextButton(
          onPressed: () {
            ref.read(settingsProvider.notifier).setGuestMode(true);
            // The router's redirect reopens the shell on the guest flag; no
            // push here, or the shell would sit on top of the sign-in screen.
          },
          child: Text(
            AppStrings.guestBrowseAction,
            style: AppTypography.button(color: AppColors.accent),
          ),
        ),
        Text(
          AppStrings.guestBrowseSubtitle,
          style: AppTypography.actionCount(color: secondary),
          textAlign: TextAlign.center,
        ),
      ],
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
