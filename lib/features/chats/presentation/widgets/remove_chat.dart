import 'package:flutter/material.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/app/widgets/app_dialog.dart';

/// Takes a conversation off the list: leaves a group, deletes a one-to-one
/// chat. Returns whether it went.
///
/// Both confirm first, because neither can be undone — a private group needs a
/// new invite to rejoin, and a deleted chat's history is gone from this
/// account. "Delete for both" is offered only where Telegram says it would
/// work, the same rule message deletion follows.
///
/// [context] must outlive the sheet or menu this is called from, since the
/// answer comes back after that has closed; pass the navigator's.
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
