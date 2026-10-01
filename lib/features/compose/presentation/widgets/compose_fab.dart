import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/l10n/app_strings.dart';

/// The compose button over the feed. The call site passes null to
/// `Scaffold` when there is nowhere to post, and `ChromeScaffold` drops it
/// with the chrome so the FAB's own animation hides it.
class ComposeFab extends StatelessWidget {
  /// The compose screen's root-level route.
  static const String route = '/compose';

  const ComposeFab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Clears the bottom bar, which overlays the content.
      padding: const EdgeInsets.only(bottom: ShellChrome.bottomBarHeight),
      child: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        tooltip: AppStrings.a11yCompose,
        shape: const CircleBorder(),
        onPressed: () {
          HapticFeedback.lightImpact();
          context.push(route);
        },
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}
