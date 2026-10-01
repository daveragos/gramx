import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/l10n/app_strings.dart';

/// Picks the chat-wide auto-delete timer, which applies to messages from both
/// sides. Offers Telegram's standard lengths rather than arbitrary seconds.
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
      // The shell's tab bar paints over branch navigators, so use the root.
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
            // Shows a current timer that isn't one of [choices].
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
