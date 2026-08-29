import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/presentation/conversation_providers.dart';
import 'package:gramx/features/chats/presentation/widgets/forward_message_sheet.dart';

/// What can be done with one message, on a long press.
///
/// Every row here is gated on what Telegram says is actually possible for this
/// message, asked once when the sheet opens (`getMessageProperties`, an offline
/// request). A Delete that Telegram would refuse, or an Edit on somebody else's
/// message, is the styled-but-inert control the hard rules forbid — so the row
/// is absent rather than present and failing.
class MessageActionsSheet extends ConsumerWidget {
  final int chatId;
  final ChatMessage message;
  final VoidCallback onReply;

  const MessageActionsSheet({
    super.key,
    required this.chatId,
    required this.message,
    required this.onReply,
  });

  static Future<void> show(
    BuildContext context, {
    required int chatId,
    required ChatMessage message,
    required VoidCallback onReply,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.lg),
        ),
      ),
      builder: (_) => MessageActionsSheet(
        chatId: chatId,
        message: message,
        onReply: onReply,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(
      messageActionsProvider(MessageRef(chatId, message.messageId)),
    );
    final reactions = ref.watch(
      chatReactionsProvider(MessageRef(chatId, message.messageId)),
    );

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Absent until Telegram answers, and absent for good if it offers
          // none — a chat can genuinely disallow reactions, and an empty strip
          // of nothing is worse than no strip.
          if (reactions.value?.isNotEmpty ?? false)
            _ReactionStrip(
              emojis: reactions.value!,
              chosen: message.chosenReactions,
              onTap: (emoji) {
                Navigator.of(context).pop();
                ref
                    .read(conversationProvider(chatId).notifier)
                    .toggleReaction(message.messageId, emoji);
              },
            ),
          actions.when(
            // A spinner rather than a default set of rows: the alternative is
            // showing every action and hiding the ones Telegram refuses a beat
            // later, which is a menu that changes under a moving thumb.
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                AppStrings.chatHistoryFailed,
                style: AppTypography.body(),
              ),
            ),
            data: (allowed) => _ActionList(
              chatId: chatId,
              message: message,
              actions: allowed,
              onReply: onReply,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionList extends ConsumerWidget {
  final int chatId;
  final ChatMessage message;
  final MessageActions actions;
  final VoidCallback onReply;

  const _ActionList({
    required this.chatId,
    required this.message,
    required this.actions,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = message.text;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (actions.canReply)
          ListTile(
            leading: const Icon(Icons.reply_rounded),
            title: const Text(AppStrings.chatActionReply),
            onTap: () {
              Navigator.of(context).pop();
              onReply();
            },
          ),
        if (actions.canCopy && text != null && text.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: const Text(AppStrings.chatActionCopy),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(AppStrings.chatCopied),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        // `canForward` was fetched from Telegram and then never used, which
        // left a message with no way out of the chat it was in — while the
        // feed has had a forward picker since T8-20.
        if (actions.canForward)
          ListTile(
            leading: const Icon(Icons.forward_rounded),
            title: const Text(AppStrings.chatActionForward),
            onTap: () async {
              Navigator.of(context).pop();
              await _forward(context, ref);
            },
          ),
        if (actions.canEdit)
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text(AppStrings.chatActionEdit),
            onTap: () async {
              Navigator.of(context).pop();
              await _edit(context, ref);
            },
          ),
        if (actions.canDeleteForSelf || actions.canDeleteForAll)
          ListTile(
            leading: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              AppStrings.chatActionDelete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () async {
              Navigator.of(context).pop();
              await _confirmDelete(context, ref);
            },
          ),
      ],
    );
  }

  Future<void> _forward(BuildContext context, WidgetRef ref) async {
    final toChatId = await ForwardMessageSheet.show(context);
    if (toChatId == null || !context.mounted) return;

    final ok = await ref
        .read(chatsRepositoryProvider)
        .forward(
          fromChatId: chatId,
          messageIds: [message.messageId],
          toChatId: toChatId,
        );
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? AppStrings.chatForwarded : AppStrings.chatForwardFailed,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: message.text ?? '');
    final updated = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.chatEditTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.chatCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text(AppStrings.chatSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updated == null) return;

    final ok = await ref
        .read(conversationProvider(chatId).notifier)
        .edit(message.messageId, updated);
    if (ok || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.chatEditFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Deleting is irreversible, so it asks — and it asks *who for*, because
  /// "delete for me" and "delete for everyone" are different acts and Telegram
  /// offers both. See the destructive-action rule in `docs/UI.md`.
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final revoke = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.chatDeleteTitle),
        content: const Text(AppStrings.chatDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.chatCancel),
          ),
          if (actions.canDeleteForSelf)
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(AppStrings.chatActionDeleteForMe),
            ),
          if (actions.canDeleteForAll)
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                AppStrings.chatActionDeleteForEveryone,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
    if (revoke == null) return;

    final ok = await ref.read(conversationProvider(chatId).notifier).delete([
      message.messageId,
    ], revoke: revoke);
    if (ok || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.chatDeleteFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// The quick-reaction row across the top of the sheet.
class _ReactionStrip extends StatelessWidget {
  /// How many of the chat's allowed reactions to offer. Telegram allows dozens;
  /// a row of dozens is a scroll, not a choice.
  static const int _visibleCount = 6;

  final List<String> emojis;
  final Set<String> chosen;
  final void Function(String emoji) onTap;

  const _ReactionStrip({
    required this.emojis,
    required this.chosen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final emoji in emojis.take(_visibleCount))
            Semantics(
              button: true,
              label: chosen.contains(emoji) ? '$emoji, your reaction' : emoji,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTap(emoji);
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: chosen.contains(emoji)
                        ? AppColors.accent.withValues(alpha: 0.2)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
