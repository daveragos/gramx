import 'package:flutter/material.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/domain/message_schedule.dart';

/// When a message should go out.
///
/// Three ways, and the third is the one worth having: *send when they are next
/// online* is a Telegram feature with no equivalent anywhere else, and it is
/// the answer to "I want them to see this, not to be woken by it".
///
/// Offered only where each makes sense — "when they are online" needs a
/// *they*, so it is absent in a group, where the concept does not exist.
abstract class ScheduleSheet {
  /// The quick offsets, so the common case does not open a date picker.
  static const List<Duration> quickChoices = [
    Duration(hours: 1),
    Duration(hours: 8),
    Duration(days: 1),
  ];

  /// Returns the chosen schedule, or null if the sheet was dismissed.
  ///
  /// [allowsWhenOnline] is the caller's answer to "is there one other person
  /// here", not a preference.
  static Future<MessageSchedule?> show(
    BuildContext context, {
    required bool allowsWhenOnline,
  }) {
    return showModalBottomSheet<MessageSchedule>(
      context: context,
      // See mute_sheet.dart: the shell's bottom tab bar paints over each
      // branch's own Navigator, so this needs the root Navigator's Overlay.
      useRootNavigator: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text(AppStrings.scheduleTitle)),
            const Divider(height: 1),
            if (allowsWhenOnline)
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text(AppStrings.scheduleWhenOnline),
                subtitle: const Text(AppStrings.scheduleWhenOnlineBody),
                onTap: () =>
                    Navigator.pop(context, MessageSchedule.whenOnline),
              ),
            for (final offset in quickChoices)
              ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: Text(AppStrings.scheduleIn(offset)),
                onTap: () => Navigator.pop(
                  context,
                  MessageSchedule.at(DateTime.now().add(offset)),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text(AppStrings.schedulePickDate),
              onTap: () async {
                final picked = await _pickMoment(context);
                if (!context.mounted) return;
                Navigator.pop(
                  context,
                  picked == null ? null : MessageSchedule.at(picked),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// A date, then a time. Two dialogs because Flutter has no combined picker,
  /// and backing out of either means the whole choice was abandoned.
  ///
  /// The range is Telegram's: no earlier than now, no further ahead than
  /// [MessageSchedule.maxAhead]. A picker that allowed a date in the past would
  /// send somebody into a rejection with no explanation.
  static Future<DateTime?> _pickMoment(BuildContext context) async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(MessageSchedule.maxAhead),
    );
    if (date == null || !context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}
