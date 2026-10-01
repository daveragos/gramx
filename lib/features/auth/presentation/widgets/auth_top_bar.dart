import 'package:flutter/material.dart';
import 'package:gramx/app/theme/app_spacing.dart';
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
    final bool showBack =
        authState.step != AuthStep.loginMethodSelection &&
        authState.step != AuthStep.loading;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: SizedBox(
        height: 48,
        child: showBack
            ? Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  // See AuthController.goBackToSelection.
                  onPressed: () => controller.goBackToSelection(),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                ),
              )
            : null,
      ),
    );
  }
}
