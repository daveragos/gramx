import 'package:flutter/material.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/auth/presentation/widgets/auth_inline_error_banner.dart';

class AuthQrPage extends StatelessWidget {
  final AuthState authState;
  final AuthController controller;

  const AuthQrPage({
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
    final link = authState.qrCodeLink;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        children: [
          const Spacer(),
          Text(
            'Scan QR Code',
            style: AppTypography.heading(
              color: primaryColor,
            ).copyWith(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Open Telegram on your mobile device:\n'
            'Settings → Devices → Link Desktop Device',
            style: AppTypography.body(color: secondaryColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: link != null && link.isNotEmpty
                ? QrImageView(
                    data: link,
                    version: QrVersions.auto,
                    size: 200,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  )
                : const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          if (authState.errorMessage != null) ...[
            AuthInlineErrorBanner(message: authState.errorMessage!),
            const SizedBox(height: 16),
          ],
          // No refresh button: TDLib renews the link itself and rejects
          // requests for a new one.
          TextButton.icon(
            onPressed: () => controller.selectPhoneLogin(),
            icon: const Icon(Icons.phone_android_rounded, size: 18),
            label: const Text(AppStrings.authUsePhoneInstead),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
