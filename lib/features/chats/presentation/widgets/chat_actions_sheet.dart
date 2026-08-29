import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';

/// What can be done to a whole conversation, on a long press in the list.
///
/// A long press used to toggle unread and nothing else — a hidden gesture with
/// one meaning, which is the worst of both worlds: undiscoverable, and useless
/// use, and every row here reflects state rather than asserting it: the labels
/// flip with the chat, so there is no "Pin" on an already-pinned chat.
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
              if (ok || !context.mounted) return;
              // Telegram caps how many chats may be pinned and refuses rather
              // than ignoring the extra one, so this is a real answer the
              // reader needs — silence would look like a dead control.
              ScaffoldMessenger.of(context).showSnackBar(
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
        ],
      ),
    );
  }
}
