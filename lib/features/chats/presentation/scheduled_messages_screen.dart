import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// One chat's queue of messages waiting to be sent.
///
/// A screen rather than a section of the conversation, because a scheduled
/// message is *not* in the conversation — Telegram keeps the queue separately,
/// sends it whether or not this app is running, and neither side sees it in the
/// history until it goes. Splicing them into the bubble list would put messages
/// in the scrollback that nobody has been sent.
///
/// Reached from the header's overflow, and only in a chat that has some: the
/// row is drawn from `chat.hasScheduledMessages`, which TDLib keeps current, so
/// there is no way in to an empty screen.
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
            itemBuilder: (context, index) => _ScheduledRow(
              chatId: chatId,
              message: messages[index],
            ),
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

  /// When TDLib says a scheduled message goes.
  ///
  /// Telegram encodes "when they come online" as a send date of
  /// [_whenOnlineSentinel] rather than as a flag, so a row showing the raw date
  /// would read as a moment in 1970 — which is the one thing this has to not
  /// do.
  static const int _whenOnlineSentinel = 2147483646;

  String _whenLabel() {
    final seconds = message.sentAt.millisecondsSinceEpoch ~/ 1000;
    if (seconds >= _whenOnlineSentinel) {
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
      // "Send now" is a reschedule to no schedule at all — TDLib reads a null
      // scheduling state on this call as "send it".
      _ScheduledAction.sendNow => await repository.reschedule(
        chatId: chatId,
        messageId: message.messageId,
        schedule: MessageSchedule.now,
      ),
      // Only for this account: a scheduled message has not reached anybody, so
      // there is nobody to revoke it from.
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
