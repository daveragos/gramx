import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/core/text/emoji_presentation.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/presentation/chat_search_providers.dart';
import 'package:gramx/features/chats/presentation/conversation_providers.dart';
import 'package:gramx/features/chats/presentation/widgets/forward_message_sheet.dart';
import 'package:gramx/app/widgets/app_dialog.dart';
import 'package:gramx/app/widgets/edit_text_dialog.dart';

/// An action chosen in [MessageActionsSheet], for the screen to carry out.
enum MessageAction { reply, forward, edit, pin, select, delete }

/// The chosen action plus the message's rights, which delete needs to know
/// whether "for everyone" is allowed.
typedef MessageActionChoice = ({MessageAction action, MessageActions rights});

/// Long-press actions for one message, limited to what the offline
/// `getMessageProperties` allows. The sheet returns the choice and
/// [runMessageAction] does the work, since the sheet's context is gone once
/// it closes. Copy and reactions finish first, so they run here.
class MessageActionsSheet extends ConsumerWidget {
  final int chatId;
  final ChatMessage message;

  const MessageActionsSheet({
    super.key,
    required this.chatId,
    required this.message,
  });

  static Future<MessageActionChoice?> show(
    BuildContext context, {
    required int chatId,
    required ChatMessage message,
  }) {
    return showModalBottomSheet<MessageActionChoice>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.lg),
        ),
      ),
      builder: (_) => MessageActionsSheet(chatId: chatId, message: message),
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
          // Hidden while loading and when the chat allows no reactions.
          if (reactions.value?.isNotEmpty ?? false)
            _ReactionStrip(
              emojis: reactions.value!,
              chosen: message.chosenReactions,
              onTap: (emoji) {
                // Read before the sheet closes, while `ref` is still live.
                final conversation = ref.read(
                  conversationProvider(chatId).notifier,
                );
                Navigator.of(context).pop();
                conversation.toggleReaction(message.messageId, emoji);
              },
            ),
          actions.when(
            // A spinner, so rows don't disappear under the user's thumb.
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
            data: (allowed) => _ActionList(message: message, actions: allowed),
          ),
        ],
      ),
    );
  }
}

class _ActionList extends StatelessWidget {
  final ChatMessage message;
  final MessageActions actions;

  const _ActionList({required this.message, required this.actions});

  @override
  Widget build(BuildContext context) {
    final text = message.text;
    void choose(MessageAction action) =>
        Navigator.of(context).pop((action: action, rights: actions));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (actions.canReply)
          ListTile(
            leading: const Icon(Icons.reply_rounded),
            title: const Text(AppStrings.chatActionReply),
            onTap: () => choose(MessageAction.reply),
          ),
        if (actions.canCopy && text != null && text.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: const Text(AppStrings.chatActionCopy),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              await Clipboard.setData(ClipboardData(text: text));
              navigator.pop();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(AppStrings.chatCopied),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        if (actions.canForward)
          ListTile(
            leading: const Icon(Icons.forward_rounded),
            title: const Text(AppStrings.chatActionForward),
            onTap: () => choose(MessageAction.forward),
          ),
        if (actions.canEdit)
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text(AppStrings.chatActionEdit),
            onTap: () => choose(MessageAction.edit),
          ),
        if (actions.canPin)
          ListTile(
            leading: Icon(
              message.isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
            ),
            title: Text(
              message.isPinned
                  ? AppStrings.chatActionUnpin
                  : AppStrings.chatActionPin,
            ),
            onTap: () => choose(MessageAction.pin),
          ),
        // Enters selection mode, since long press already opens this sheet.
        ListTile(
          leading: const Icon(Icons.checklist_rounded),
          title: const Text(AppStrings.chatActionSelect),
          onTap: () => choose(MessageAction.select),
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
            onTap: () => choose(MessageAction.delete),
          ),
      ],
    );
  }
}

/// Carries out a forward, edit, pin or delete using the conversation screen's
/// [context] and [ref]. The screen handles reply and select itself.
Future<void> runMessageAction(
  MessageActionChoice choice,
  BuildContext context,
  WidgetRef ref, {
  required int chatId,
  required ChatMessage message,
}) => switch (choice.action) {
  MessageAction.forward => _forward(context, ref, chatId, message),
  MessageAction.edit => _edit(context, ref, chatId, message),
  MessageAction.pin => _togglePin(context, ref, chatId, message),
  MessageAction.delete => _confirmDelete(
    context,
    ref,
    chatId,
    message,
    choice.rights,
  ),
  MessageAction.reply || MessageAction.select => Future<void>.value(),
};

/// Pins or unpins the message. Only pinning asks for confirmation.
Future<void> _togglePin(
  BuildContext context,
  WidgetRef ref,
  int chatId,
  ChatMessage message,
) async {
  final pinning = !message.isPinned;

  if (pinning) {
    final confirmed = await showAppDialog<bool>(
      context,
      title: AppStrings.chatPinTitle,
      body: AppStrings.chatPinBody,
      actions: const [
        AppDialogAction(
          label: AppStrings.chatPinConfirm,
          value: true,
          isPrimary: true,
        ),
        AppDialogAction.cancel(AppStrings.chatCancel),
      ],
    );
    if (confirmed != true || !context.mounted) return;
  }

  final ok = await ref
      .read(chatsRepositoryProvider)
      .setMessagePinned(
        chatId: chatId,
        messageId: message.messageId,
        isPinned: pinning,
      );
  if (!context.mounted) return;

  // `updateMessageIsPinned` doesn't refresh the pinned banner's provider.
  if (ok) ref.invalidate(pinnedMessageProvider(chatId));

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? (pinning ? AppStrings.chatPinned : AppStrings.chatUnpinned)
            : (pinning ? AppStrings.chatPinFailed : AppStrings.chatUnpinFailed),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<void> _forward(
  BuildContext context,
  WidgetRef ref,
  int chatId,
  ChatMessage message,
) async {
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

Future<void> _edit(
  BuildContext context,
  WidgetRef ref,
  int chatId,
  ChatMessage message,
) async {
  final updated = await EditTextDialog.show(
    context,
    initialText: message.text ?? '',
    // A caption may be emptied; a text message may not.
    allowsEmpty: message.media.isNotEmpty,
  );
  if (updated == null || !context.mounted) return;

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

/// Confirms a delete, offering "for me" and "for everyone" as allowed.
Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  int chatId,
  ChatMessage message,
  MessageActions actions,
) async {
  final revoke = await showAppDialog<bool>(
    context,
    title: AppStrings.chatDeleteTitle,
    body: AppStrings.chatDeleteBody,
    actions: [
      if (actions.canDeleteForAll)
        const AppDialogAction(
          label: AppStrings.chatActionDeleteForEveryone,
          value: true,
          isPrimary: true,
          isDestructive: true,
        ),
      if (actions.canDeleteForSelf)
        AppDialogAction(
          label: AppStrings.chatActionDeleteForMe,
          value: false,
          isPrimary: !actions.canDeleteForAll,
          isDestructive: true,
        ),
      const AppDialogAction.cancel(AppStrings.chatCancel),
    ],
  );
  if (revoke == null || !context.mounted) return;

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

/// The quick-reaction row across the top of the sheet.
class _ReactionStrip extends StatelessWidget {
  /// How many of the chat's allowed reactions to show.
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
                  child: Text(
                    emojiForDisplay(emoji),
                    style: emojiStyle(fontSize: 24),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
