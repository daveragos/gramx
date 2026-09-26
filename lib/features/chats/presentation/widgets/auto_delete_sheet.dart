import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/l10n/app_strings.dart';

/// How long messages live in a chat before Telegram deletes them.
///
/// Chat-wide and two-sided, which is the whole reason it is not on the
/// composer: it applies to everything *either* side sends from now on, both
/// people see the change, and Telegram posts a service notice announcing it.
/// The per-message timer in [SelfDestructSheet] is the other thing entirely —
/// one sender, one picture, no notice.
///
/// Telegram's own three lengths, and off. TDLib takes any number of seconds,
/// but a free-form duration picker would produce timers no other client can
/// name, and the other side reads this setting in their client, not ours.
abstract class AutoDeleteSheet {
  /// The choices, in seconds. Zero is off.
  static const List<int> choices = [
    0,
    86400, // a day
    604800, // a week
    2678400, // a month, as Telegram counts one
  ];

  /// Returns the chosen number of seconds, or null if the sheet was dismissed.
  static Future<int?> show(BuildContext context, {required int current}) {
    return showModalBottomSheet<int>(
      context: context,
      // See mute_sheet.dart: the shell's bottom tab bar paints over each
      // branch's own Navigator, so this needs the root Navigator's Overlay.
      useRootNavigator: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text(AppStrings.autoDeleteTitle),
              subtitle: const Text(AppStrings.autoDeleteBody),
            ),
            const Divider(height: 1),
            for (final seconds in choices)
              ListTile(
                leading: Icon(
                  seconds == 0
                      ? Icons.timer_off_outlined
                      : Icons.auto_delete_outlined,
                ),
                title: Text(AppStrings.autoDeleteChoice(seconds)),
                trailing: seconds == current
                    ? const Icon(Icons.check_rounded, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.pop(context, seconds),
              ),
            // A timer set from another client to a length gramX does not offer
            // is still shown, ticked, rather than leaving the sheet claiming
            // nothing is set. Telegram allows any number of seconds.
            if (current != 0 && !choices.contains(current))
              ListTile(
                leading: const Icon(Icons.auto_delete_outlined),
                title: Text(AppStrings.autoDeleteChoice(current)),
                trailing: const Icon(
                  Icons.check_rounded,
                  color: AppColors.accent,
                ),
                onTap: () => Navigator.pop(context, current),
              ),
          ],
        ),
      ),
    );
  }
}
