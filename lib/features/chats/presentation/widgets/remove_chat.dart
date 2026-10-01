import 'package:flutter/material.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/app/widgets/app_dialog.dart';

/// Leaves a group or deletes a one-to-one chat after confirming, and returns
/// whether it succeeded. "Delete for both" is offered only where Telegram
/// allows it.
///
/// [context] must outlive the calling sheet or menu; pass the navigator's.
Future<bool> confirmAndRemoveChat(
  BuildContext context,
  ChatsRepository repository, {
  required int chatId,
  required String title,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final isGroup = repository.canLeave(chatId);
  final canRevoke = !isGroup && repository.canDeleteForBoth(chatId);

  // Null is "cancel"; the bool is `revoke` for a chat, and ignored for a group.
  final answer = await showAppDialog<bool>(
    context,
    title: isGroup
        ? AppStrings.messagesLeaveGroupTitle(title)
        : AppStrings.messagesDeleteChatTitle(title),
    body: isGroup
        ? AppStrings.messagesLeaveGroupBody
        : AppStrings.messagesDeleteChatBody,
    actions: [
      AppDialogAction(
        label: isGroup
            ? AppStrings.messagesLeaveGroup
            : AppStrings.messagesDeleteChat,
        value: false,
        isPrimary: true,
        isDestructive: true,
      ),
      if (canRevoke)
        AppDialogAction(
          label: AppStrings.messagesDeleteForBoth(title),
          value: true,
          isDestructive: true,
        ),
      const AppDialogAction.cancel(AppStrings.chatCancel),
    ],
  );
  if (answer == null) return false;

  final ok = isGroup
      ? await repository.leaveChat(chatId)
      : await repository.deleteChat(chatId, revoke: answer);
  if (!ok) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          isGroup
              ? AppStrings.messagesLeaveFailed
              : AppStrings.messagesDeleteFailed,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  return ok;
}
