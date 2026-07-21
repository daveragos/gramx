import 'package:flutter/material.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';

class AuthLoadingPage extends StatelessWidget {
  final AuthState authState;
  final AnimationController pulseController;
  final AuthController controller;

  const AuthLoadingPage({
    super.key,
    required this.authState,
    required this.pulseController,
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
            AnimatedBuilder(
              animation: pulseController,
              builder: (context, child) {
                final scale = 1.0 + (pulseController.value * 0.08);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent,
                          AppColors.accent.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(
                            alpha: 0.3 + (pulseController.value * 0.25),
                          ),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 36),
            Text(
              'Connecting to Telegram',
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
                'Reset Connection',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
