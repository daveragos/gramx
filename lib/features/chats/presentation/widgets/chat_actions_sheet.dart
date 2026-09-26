import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/features/chats/presentation/widgets/remove_chat.dart';

/// What can be done to a whole conversation, on a long press in the list.
///
/// A long press used to toggle unread and nothing else — a hidden gesture with
/// one meaning, which is the worst of both worlds: undiscoverable, and useless
/// use, and every row here reflects state rather than asserting it: the labels
/// flip with the chat, so there is no "Pin" on an already-pinned chat. The
/// last row is the way out — leave a group, delete a chat — and it confirms.
class ChatActionsSheet extends ConsumerWidget {
  final ChatSummary chat;

  const ChatActionsSheet({super.key, required this.chat});

  static Future<void> show(BuildContext context, ChatSummary chat) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.lg),
        ),
      ),
      builder: (_) => ChatActionsSheet(chat: chat),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(chatsRepositoryProvider);
    final isUnread = chat.unreadCount > 0 || chat.isMarkedAsUnread;
    // The sheet closes before any answer comes back, and its own context goes
    // with it — so anything said afterwards is said through the navigator's,
    // which outlives it.
    final host = Navigator.of(context).context;
    final messenger = ScaffoldMessenger.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              chat.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            ),
            title: Text(
              chat.isPinned ? AppStrings.messagesUnpin : AppStrings.messagesPin,
            ),
            onTap: () async {
              Navigator.of(context).pop();
              final ok = await repository.setPinned(
                chat.chatId,
                isPinned: !chat.isPinned,
              );
              if (ok) return;
              // Telegram caps how many chats may be pinned and refuses rather
              // than ignoring the extra one, so this is a real answer the
              // reader needs — silence would look like a dead control.
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(AppStrings.messagesPinFailed),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(
              isUnread
                  ? Icons.mark_chat_read_outlined
                  : Icons.mark_chat_unread_outlined,
            ),
            title: Text(
              isUnread
                  ? AppStrings.messagesMarkRead
                  : AppStrings.messagesMarkUnread,
            ),
            onTap: () async {
              Navigator.of(context).pop();
              if (isUnread) {
                await repository.markChatRead(chat.chatId);
                await repository.setMarkedAsUnread(chat.chatId, value: false);
              } else {
                await repository.setMarkedAsUnread(chat.chatId, value: true);
              }
            },
          ),
          ListTile(
            leading: Icon(
              chat.isMuted
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
            ),
            title: Text(
              chat.isMuted
                  ? AppStrings.messagesUnmute
                  : AppStrings.messagesMute,
            ),
            onTap: () {
              Navigator.of(context).pop();
              repository.setMuted(chat.chatId, isMuted: !chat.isMuted);
            },
          ),
          // Saved Messages is the one chat with nobody to leave and nothing a
          // reader would want gone in one tap.
          if (chat.kind != ChatKind.savedMessages)
            ListTile(
              leading: Icon(
                chat.kind == ChatKind.group
                    ? Icons.logout_rounded
                    : Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                chat.kind == ChatKind.group
                    ? AppStrings.messagesLeaveGroup
                    : AppStrings.messagesDeleteChat,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.of(context).pop();
                confirmAndRemoveChat(
                  host,
                  repository,
                  chatId: chat.chatId,
                  title: chat.title,
                );
              },
            ),
        ],
      ),
    );
  }
}
