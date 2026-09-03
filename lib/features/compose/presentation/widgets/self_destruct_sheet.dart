import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';

/// How long one attachment survives after it is opened.
///
/// Only ever shown for a private chat — [SelfDestruct] explains why — so this
/// widget does not have to ask: whoever opens it has already decided the
/// destination allows it.
abstract class SelfDestructSheet {
  /// Returns the chosen setting, or null if the sheet was dismissed.
  static Future<SelfDestruct?> show(
    BuildContext context, {
    required SelfDestruct current,
  }) {
    return showModalBottomSheet<SelfDestruct>(
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
              leading: const Icon(Icons.image_outlined),
              title: const Text(AppStrings.selfDestructOff),
              trailing: _tick(current == SelfDestruct.none),
              onTap: () => Navigator.pop(context, SelfDestruct.none),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text(AppStrings.selfDestructViewOnce),
              subtitle: const Text(AppStrings.selfDestructViewOnceBody),
              trailing: _tick(current == SelfDestruct.viewOnce),
              onTap: () => Navigator.pop(context, SelfDestruct.viewOnce),
            ),
            for (final seconds in SelfDestruct.timerChoices)
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(AppStrings.selfDestructAfter(seconds)),
                trailing: _tick(
                  !current.isViewOnce && current.seconds == seconds,
                ),
                onTap: () =>
                    Navigator.pop(context, SelfDestruct.after(seconds)),
              ),
          ],
        ),
      ),
    );
  }

  static Widget? _tick(bool isSelected) => isSelected
      ? const Icon(Icons.check_rounded, color: AppColors.accent)
      : null;
}
