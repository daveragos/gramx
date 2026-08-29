import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';

/// Where the app sits while it works out whether anybody is signed in.
///
/// It exists because the alternative was a *guess*. The router used to open
/// straight onto the feed and let the auth rules move the reader off it, which
/// meant that any authorization state TDLib announced on the way up — and it
/// announces several while it starts, some of them immediately superseded —
/// could paint the sign-in screen for a frame or two before the feed arrived.
/// That flash is what this removes: there is now a destination that means
/// "not decided yet", and it is neither of the two screens that would be wrong.
///
/// Deliberately almost nothing. It is a continuation of the platform's own
/// launch screen, not a third piece of UI to look at, so it carries the
/// wordmark and a thread of motion and no message — there is nothing to tell
/// somebody in the half-second it is up.
class SplashScreen extends StatelessWidget {
  /// The route. Also the router's initial location, so it is the first thing
  /// every cold start lands on.
  static const String route = '/';

  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.appName,
              style: AppTypography.heading(
                color: primary,
              ).copyWith(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
