import 'package:flutter/material.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/domain/message_schedule.dart';

/// Picks when to send a message: a quick offset, a chosen date and time, or
/// (in a private chat) when the other user is next online.
abstract class ScheduleSheet {
  /// The quick offsets offered before the date picker.
  static const List<Duration> quickChoices = [
    Duration(hours: 1),
    Duration(hours: 8),
    Duration(days: 1),
  ];

  /// Returns the chosen schedule, or null if the sheet was dismissed.
  /// [allowsWhenOnline] should be true only in a chat with one other user.
  static Future<MessageSchedule?> show(
    BuildContext context, {
    required bool allowsWhenOnline,
  }) {
    return showModalBottomSheet<MessageSchedule>(
      context: context,
      // The shell's tab bar paints over branch navigators, so use the root.
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
                onTap: () => Navigator.pop(context, MessageSchedule.whenOnline),
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

  /// Picks a date then a time, within Telegram's range of now to
  /// [MessageSchedule.maxAhead]. Returns null if either dialog is dismissed.
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
