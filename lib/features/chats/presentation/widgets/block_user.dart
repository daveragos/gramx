import 'package:flutter/material.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/app/widgets/app_dialog.dart';

/// Blocks [userId], or unblocks them if they already are. Returns whether
/// Telegram took it.
///
/// Blocking confirms first — it cuts somebody off, and they are not told, so a
/// tap that missed its target would be silent on both sides. Unblocking just
/// happens: it restores what the reader chose to have, and is one tap to undo.
Future<bool> toggleBlock(
  BuildContext context,
  ChatsRepository repository, {
  required int userId,
  required String name,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final isBlocked = repository.isBlocked(userId);

  if (!isBlocked) {
    final confirmed = await showAppDialog<bool>(
      context,
      title: AppStrings.userBlockTitle(name),
      body: AppStrings.userBlockBody,
      actions: const [
        AppDialogAction(
          label: AppStrings.userBlock,
          value: true,
          isPrimary: true,
          isDestructive: true,
        ),
        AppDialogAction.cancel(AppStrings.chatCancel),
      ],
    );
    if (confirmed != true) return false;
  }

  final ok = await repository.setBlocked(userId, isBlocked: !isBlocked);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        !ok
            ? AppStrings.userBlockFailed
            : isBlocked
            ? AppStrings.userUnblocked
            : AppStrings.userBlocked,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
  return ok;
}
