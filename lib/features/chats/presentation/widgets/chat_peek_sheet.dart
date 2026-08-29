import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/data/conversation_rows.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/features/chats/presentation/chats_screen.dart';
import 'package:gramx/features/chats/presentation/widgets/chat_date_separator.dart';
import 'package:gramx/features/chats/presentation/widgets/message_bubble.dart';

/// A read-only look into a conversation, without opening it.
///
/// The point is the thing it does **not** do. Opening a chat is an `OpenChat`
/// followed by read acknowledgements, and those are pushed to Telegram — so
/// every device the reader is signed in on, and the person on the other end,
/// learn that the message was seen. Sometimes you want to know what somebody
/// said without telling them you know.
///
/// So this issues exactly one `GetChatHistory` and nothing else: no `OpenChat`,
/// no `ViewMessages`, no typing signal, no live subscription. Everything that
/// makes the conversation screen *interactive* is what would make this leave a
/// trace, which is why it is a separate surface rather than a flag on that one.
///
/// One request per peek, user-driven — the shape `docs/TDLIB.md` allows.
class ChatPeekSheet extends ConsumerWidget {
  final ChatSummary chat;

  const ChatPeekSheet({super.key, required this.chat});

  /// How much history a peek pulls. Enough to see what was said, short enough
  /// to be one request.
  static const int pageSize = 30;

  static Future<void> show(BuildContext context, ChatSummary chat) {
    return showModalBottomSheet<void>(
      context: context,
      // See mute_sheet.dart: the shell's bottom tab bar paints over each
      // branch's own Navigator, so this needs the root Navigator's Overlay.
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChatPeekSheet(chat: chat),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  ChannelAvatar(
                    title: chat.title,
                    avatarPath: chat.avatarPath,
                    avatarFileId: chat.avatarFileId,
                    avatarColorHex: chat.avatarColorHex,
                    radius: AppSpacing.avatarSizeSmall / 2,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chat.title,
                          style: AppTypography.displayName(color: primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          AppStrings.chatPeekTitle,
                          style: AppTypography.timestamp(color: secondary),
                        ),
                      ],
                    ),
                  ),
                  // The way out of read-only and into the real thing. Opening
                  // it from here is an ordinary open — it marks things read,
                  // because that is what opening a chat means.
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(ChatsScreen.routeFor(chat.chatId));
                    },
                    child: const Text(AppStrings.chatPeekOpen),
                  ),
                ],
              ),
            ),
            // Said plainly rather than implied by the absence of a composer:
            // "this does not mark anything read" is the entire reason somebody
            // would use this instead of just opening the chat.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(color: border, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 14, color: secondary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      AppStrings.chatPeekHint,
                      style: AppTypography.timestamp(color: secondary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ref
                  .watch(chatPeekProvider(chat.chatId))
                  .when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                    error: (_, _) => _Message(
                      text: AppStrings.chatPeekFailed,
                      color: secondary,
                    ),
                    data: (messages) => messages.isEmpty
                        ? _Message(
                            text: AppStrings.chatPeekEmpty,
                            color: secondary,
                          )
                        : _PeekList(
                            messages: messages,
                            isGroup: chat.kind == ChatKind.group,
                          ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The history behind a peek: one `GetChatHistory`, and no `OpenChat`.
///
/// Auto-disposed, so closing the sheet drops it and re-peeking is a fresh
/// look rather than a stale one.
final chatPeekProvider = FutureProvider.autoDispose
    .family<List<ChatMessage>, int>((ref, chatId) async {
      final page = await ref
          .watch(chatsRepositoryProvider)
          .history(chatId, limit: ChatPeekSheet.pageSize);
      return page.messages;
    });

/// The same bubbles the conversation draws, with every handler left off.
///
/// Nothing here is tappable, and that is the design: a reply, a reaction or a
/// long press would all reach Telegram, and reaching Telegram is what a peek
/// is defined by not doing.
class _PeekList extends StatelessWidget {
  final List<ChatMessage> messages;
  final bool isGroup;

  const _PeekList({required this.messages, required this.isGroup});

  @override
  Widget build(BuildContext context) {
    final rows = ConversationRows.build(messages).reversed.toList();

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return switch (row) {
          ConversationDateRow() => ChatDateSeparator(date: row.date),
          ConversationUnreadRow() => const SizedBox.shrink(),
          ConversationMessageRow() => MessageBubble(
            message: row.message,
            isGroup: isGroup,
            isFirstInGroup: row.isFirstInGroup,
            isLastInGroup: row.isLastInGroup,
          ),
        };
      },
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final Color color;

  const _Message({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.body(color: color),
        ),
      ),
    );
  }
}
