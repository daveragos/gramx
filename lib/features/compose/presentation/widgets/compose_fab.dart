import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/l10n/app_strings.dart';

/// The compose button, over the feed.
///
/// Hidden rather than disabled when there is nowhere to post — a guest, or an
/// account that runs no channel and shares no group. A round blue button that
/// opens a screen saying "you can't do this" is the styled-but-inert control
/// the hard rules in docs/CONVENTIONS.md exist to keep out. That check lives at
/// the call site, because hiding it means handing `Scaffold` a null rather than
/// returning an empty box from here — see below.
///
/// It belongs to the chrome, so it leaves with the chrome. It used to do that
/// by translating itself down by a measured number of pixels, which had to
/// account for the bottom bar, its own height, its margin and the gesture
/// inset — and got it slightly short, so a sliver of the button stayed on
/// screen. `ChromeScaffold` now simply stops passing it to the `Scaffold`,
/// which runs the FAB's own enter/exit animation. The button says nothing
/// about where the screen edge is, and there is no number left to be wrong.
class ComposeFab extends StatelessWidget {
  /// Where the compose screen lives. Root-level, like the other full screens.
  static const String route = '/compose';

  const ComposeFab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the button clear of the bottom bar, which overlays the content
      // rather than sitting under it.
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
