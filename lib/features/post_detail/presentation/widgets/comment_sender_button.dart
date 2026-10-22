import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/app/widgets/app_sheet.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/infrastructure/telegram/chat_identity.dart';

/// Who the reader can comment as under a post, by the post's
/// `chatId_messageId`. Null when only as themselves.
final commentSendersProvider = FutureProvider.autoDispose
    .family<CommentSenders?, String>((ref, postId) async {
      final parts = postId.split('_');
      final chatId = int.tryParse(parts.first);
      final messageId = parts.length == 2 ? int.tryParse(parts.last) : null;
      if (chatId == null || messageId == null) return null;

      final repository = ref.read(feedRepositoryProvider);
      final discussion = await repository.commentsChatId(chatId, messageId);
      if (discussion == null) return null;
      return repository.commentSenders(discussion);
    });

/// The picture beside the comment field: whoever the comment will come from.
/// Where the reader runs channels that may comment, tapping it picks one, as
/// "Send as" does in Telegram.
class CommentSenderButton extends ConsumerWidget {
  final String postId;
  final double radius;

  const CommentSenderButton({
    super.key,
    required this.postId,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senders = ref.watch(commentSendersProvider(postId)).value;
    final avatar = CommentSenderAvatar(sender: senders?.chosen, radius: radius);
    if (senders == null) return avatar;

    return Tooltip(
      message: AppStrings.commentAs,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _choose(context, ref, senders),
        child: avatar,
      ),
    );
  }

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    CommentSenders senders,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final chosen = await showAppSheet<td.MessageSender>(
      context,
      title: AppStrings.commentAs,
      children: [
        for (final option in senders.senders)
          _SenderRow(
            option: option,
            isSelected: _same(option.sender, senders.chosen),
          ),
      ],
    );
    if (chosen == null || _same(chosen, senders.chosen)) return;

    final ok = await ref
        .read(feedRepositoryProvider)
        .setCommentSender(senders.chatId, chosen);
    ref.invalidate(commentSendersProvider(postId));
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(AppStrings.commentAsFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Whether [a] and [b] are the same user or chat. No choice yet means the
  /// reader themselves.
  static bool _same(td.MessageSender a, td.MessageSender? b) =>
      switch ((a, b)) {
        (
          td.MessageSenderUser(:final userId),
          td.MessageSenderUser(userId: final other),
        ) =>
          userId == other,
        (
          td.MessageSenderChat(:final chatId),
          td.MessageSenderChat(chatId: final other),
        ) =>
          chatId == other,
        (td.MessageSenderUser(), null) => true,
        _ => false,
      };
}

/// One choice in the "Comment as" sheet.
class _SenderRow extends ConsumerWidget {
  final td.ChatMessageSender option;
  final bool isSelected;

  const _SenderRow({required this.option, required this.isSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sender = option.sender;
    final String label;
    final String subtitle;
    if (sender is td.MessageSenderChat) {
      final chat = ref.watch(chatIdentityProvider(sender.chatId));
      label = chat.title ?? AppStrings.commentAsChannel;
      subtitle = chat.username != null
          ? '@${chat.username}'
          : AppStrings.commentAsChannel;
    } else {
      final account = ref.watch(activeAccountProvider).value;
      label = account?.displayName ?? AppStrings.drawerAccountFallback;
      subtitle = AppStrings.commentAsAccount;
    }

    return AppSheetRow<td.MessageSender>(
      leading: CommentSenderAvatar(sender: sender, radius: 14),
      label: label,
      subtitle: option.needsPremium
          ? AppStrings.commentAsNeedsPremium
          : subtitle,
      value: sender,
      isSelected: isSelected,
    );
  }
}

/// The picture of whoever a comment comes from: one of the reader's channels,
/// or the reader when [sender] is a user or not chosen.
class CommentSenderAvatar extends ConsumerWidget {
  final td.MessageSender? sender;
  final double radius;

  const CommentSenderAvatar({super.key, this.sender, this.radius = 16});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sender = this.sender;
    if (sender is td.MessageSenderChat) {
      final chat = ref.watch(chatIdentityProvider(sender.chatId));
      return ChannelAvatar(
        title: chat.title ?? AppStrings.commentAsChannel,
        avatarPath: chat.avatarPath,
        avatarFileId: chat.avatarFileId,
        radius: radius,
      );
    }
    final account = ref.watch(activeAccountProvider).value;
    return ChannelAvatar(
      title: account?.displayName ?? AppStrings.drawerAccountFallback,
      avatarPath: account?.avatarPath,
      radius: radius,
    );
  }
}
