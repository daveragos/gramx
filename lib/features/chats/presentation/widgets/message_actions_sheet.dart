import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// What the reader chose from [MessageActionsSheet], for the screen to carry
/// out.
enum MessageAction { reply, forward, edit, pin, select, delete }

/// A choice, and what Telegram said was allowed when it was made — delete
/// needs to know whether "for everyone" is on offer.
typedef MessageActionChoice = ({MessageAction action, MessageActions rights});

/// What can be done with one message, on a long press.
///
/// Every row here is gated on what Telegram says is actually possible for this
/// message, asked once when the sheet opens (`getMessageProperties`, an offline
/// request). A Delete that Telegram would refuse, or an Edit on somebody else's
/// message, is the styled-but-inert control the hard rules forbid — so the row
/// is absent rather than present and failing.
///
/// **The sheet chooses; the screen acts.** Every row used to close the sheet
/// and then go on using the sheet's own context and `ref` — for a dialog, a
/// chat picker, a request. Those were gone by the time the dialog answered, so
/// Forward, Edit, Pin and Delete all ended in `if (!context.mounted) return`
/// or a disposed `ref`, and did nothing at all. Now the sheet only answers
/// *which*, and [runMessageAction] does the work with the conversation
/// screen's context, which outlives it. Copy and a reaction stay here: both
/// finish before the sheet closes.
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
          // Absent until Telegram answers, and absent for good if it offers
          // none — a chat can genuinely disallow reactions, and an empty strip
          // of nothing is worse than no strip.
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
        // `canForward` was fetched from Telegram and then never used, which
        // left a message with no way out of the chat it was in — while the
        // feed has had a forward picker since T8-20.
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
        // A pinned message is already reachable from the header banner and was
        // the one thing about it nobody could change from inside gramX. The row
        // flips with the message rather than asserting one direction, the way
        // every other toggle in this app does — and unpinning needs no
        // confirmation, because it takes nothing away that cannot be put back.
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
        // The way into selection mode. Deliberately not a second gesture:
        // long-press is already taken by this menu, and a chat with two
        // long-press meanings is a chat where neither is discoverable.
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

/// Carries out a forward, an edit, a pin or a delete chosen from the sheet.
///
/// [context] and [ref] are the conversation screen's, which are still there
/// when the dialogs these open have answered. Reply and select change the
/// screen's own state, so the screen handles those itself.
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

/// Pins or unpins, asking first only in the direction that is visible to
/// everybody else in the chat.
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

  // The banner reads its own provider, which has no update to listen to —
  // `updateMessageIsPinned` moves the bubble's state, not the cached
  // "what is pinned in this chat" answer — so it is refreshed by hand.
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
    // A photo's or a file's words are its caption, and a caption may be
    // emptied; a text message may not.
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

/// Deleting is irreversible, so it asks — and it asks *who for*, because
/// "delete for me" and "delete for everyone" are different acts and Telegram
/// offers both. See the destructive-action rule in `docs/UI.md`.
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
