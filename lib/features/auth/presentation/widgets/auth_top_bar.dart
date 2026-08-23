import 'package:flutter/material.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';

class AuthTopBar extends StatelessWidget {
  final AuthState authState;
  final AuthController controller;

  const AuthTopBar({
    super.key,
    required this.authState,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final bool showBack = authState.step != AuthStep.loginMethodSelection &&
        authState.step != AuthStep.loading;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              // Leaves the attempt standing but stops it driving the screen —
              // see AuthController.goBackToSelection.
              onPressed: () => controller.goBackToSelection(),
              tooltip: 'Back',
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Center(
              child: Text(
                'gramX',
                style: AppTypography.heading(
                  color: AppColors.accent,
                ).copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
