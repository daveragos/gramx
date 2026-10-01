import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';

/// How long one attachment survives after it is opened. Only shown for
/// private chats; see [SelfDestruct].
abstract class SelfDestructSheet {
  /// Returns the chosen setting, or null if the sheet was dismissed.
  static Future<SelfDestruct?> show(
    BuildContext context, {
    required SelfDestruct current,
  }) {
    return showModalBottomSheet<SelfDestruct>(
      context: context,
      // Above the shell's bottom bar; see mute_sheet.dart.
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
