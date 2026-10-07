import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/presentation/widgets/new_chat_sheet.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
import 'package:gramx/features/compose/presentation/compose_screen.dart';

/// What the shell's button does on a tab.
enum ShellFabAction {
  compose(Icons.add_rounded, 28, AppStrings.a11yCompose),
  newChat(Icons.maps_ugc_outlined, 24, AppStrings.messagesNewChat);

  const ShellFabAction(this.icon, this.iconSize, this.tooltip);

  final IconData icon;
  final double iconSize;
  final String tooltip;

  /// The action for [tab], or null where it has none: Home composes when
  /// there is somewhere to post, and Messages starts a chat.
  static ShellFabAction? forTab(ShellTab tab, {required bool canCompose}) =>
      switch (tab) {
        ShellTab.home => canCompose ? compose : null,
        ShellTab.messages => newChat,
        _ => null,
      };

  void run(BuildContext context) {
    HapticFeedback.lightImpact();
    switch (this) {
      case compose:
        context.push(ComposeScreen.route);
      case newChat:
        NewChatSheet.show(context);
    }
  }
}

/// The button over the tabs. One for the whole shell, as on X: going from
/// Home to Messages turns its icon over in place, and on a tab without an
/// action it shrinks away. It also leaves with the chrome while scrolling.
class ShellFab extends ConsumerWidget {
  final ShellTab tab;

  const ShellFab({super.key, required this.tab});

  static const Duration duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ShellFabAction.forTab(
      tab,
      canCompose: ref.watch(canComposeProvider),
    );
    final shown = action != null && ref.watch(chromeVisibleProvider);

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: shown
          ? _Button(key: const ValueKey('fab'), action: action)
          : const SizedBox.shrink(),
    );
  }
}

class _Button extends StatelessWidget {
  final ShellFabAction action;

  const _Button({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      // Outside any Scaffold, and alone in the shell: no hero flight.
      heroTag: null,
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      tooltip: action.tooltip,
      shape: const CircleBorder(),
      onPressed: () => action.run(context),
      child: AnimatedSwitcher(
        duration: ShellFab.duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        // Both icons turn the same way: the new one arrives from a quarter
        // turn back, the old one leaves a quarter turn on.
        transitionBuilder: (child, animation) {
          final arriving = child.key == ValueKey(action);
          return RotationTransition(
            turns: Tween<double>(
              begin: arriving ? -0.25 : 0.25,
              end: 0,
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Icon(action.icon, key: ValueKey(action), size: action.iconSize),
      ),
    );
  }
}
