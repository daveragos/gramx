import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/chats/data/chat_message_mapper.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/domain/message_schedule.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';
import 'package:gramx/app/widgets/app_sheet.dart';

/// One chat's queue of scheduled messages. Kept out of the conversation
/// because Telegram stores the queue separately from the history.
class ScheduledMessagesScreen extends ConsumerWidget {
  final int chatId;

  const ScheduledMessagesScreen({super.key, required this.chatId});

  static Future<void> show(BuildContext context, int chatId) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => ScheduledMessagesScreen(chatId: chatId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final scheduled = ref.watch(scheduledMessagesProvider(chatId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: const Text(AppStrings.scheduleScreenTitle),
      ),
      body: scheduled.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (_, _) => Center(
          child: Text(
            AppStrings.chatHistoryFailed,
            style: AppTypography.body(color: secondary),
          ),
        ),
        data: (messages) {
          if (messages.isEmpty) {
            return Center(
              child: Text(
                AppStrings.scheduleEmpty,
                style: AppTypography.body(color: secondary),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: messages.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _ScheduledRow(chatId: chatId, message: messages[index]),
          );
        },
      ),
    );
  }
}

class _ScheduledRow extends ConsumerWidget {
  final int chatId;
  final ChatMessage message;

  const _ScheduledRow({required this.chatId, required this.message});

  String _whenLabel() {
    final seconds = message.sentAt.millisecondsSinceEpoch ~/ 1000;
    if (seconds >= ChatMessageMapper.whenOnlineDate) {
      return AppStrings.scheduleWhenOnlineRow;
    }
    return TimeUtils.fullDateTime(message.sentAt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return ListTile(
      title: Text(
        message.text?.isNotEmpty == true
            ? message.text!
            : AppStrings.chatAttach,
        style: AppTypography.body(color: primary),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        AppStrings.scheduledFor(_whenLabel()),
        style: AppTypography.timestamp(color: secondary),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_horiz_rounded),
        tooltip: AppStrings.chatMoreTooltip,
        onPressed: () async {
          final action = await showAppSheet<_ScheduledAction>(
            context,
            haptic: false,
            children: const [
              AppSheetRow<_ScheduledAction>(
                icon: Icons.send_rounded,
                label: AppStrings.scheduleSendNow,
                value: _ScheduledAction.sendNow,
              ),
              AppSheetRow<_ScheduledAction>(
                icon: Icons.delete_outline_rounded,
                label: AppStrings.scheduleDelete,
                value: _ScheduledAction.delete,
                isDestructive: true,
              ),
            ],
          );
          if (action == null || !context.mounted) return;
          await _run(context, ref, action);
        },
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    _ScheduledAction action,
  ) async {
    final repository = ref.read(chatsRepositoryProvider);

    final ok = switch (action) {
      // TDLib sends the message when the scheduling state is null.
      _ScheduledAction.sendNow => await repository.reschedule(
        chatId: chatId,
        messageId: message.messageId,
        schedule: MessageSchedule.now,
      ),
      // An unsent message has no other copies to revoke.
      _ScheduledAction.delete => await repository.deleteMessages(
        chatId: chatId,
        messageIds: [message.messageId],
        revoke: false,
      ),
    };

    if (!context.mounted) return;
    ref.invalidate(scheduledMessagesProvider(chatId));

    if (ok && action == _ScheduledAction.sendNow) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.scheduleSent),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (ok) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.scheduleRescheduleFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

enum _ScheduledAction { sendNow, delete }
