import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/widgets/app_dialog.dart';
import 'package:gramx/app/widgets/app_sheet.dart';
import 'package:gramx/app/widgets/edit_text_dialog.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/navigation/url_launcher_utils.dart';
import 'package:gramx/core/telegram/telegram_ids.dart';
import 'package:gramx/features/channels/data/channel_repository.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/channels/presentation/widgets/mute_sheet.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/guest/data/guest_post_mapper.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';

/// What the "…" on a post card opens.
///
/// report — and gramX had the same actions scattered across the channel page,
/// the action bar and the Channels tab. Here they are in the one place a
/// reader looks for them. Every row is something Telegram can actually do to
/// this post; "not interested" and "report" are not offered because Telegram
/// has no feed to teach and no per-post report from a client like this one.
///
/// **The sheet chooses; the caller acts.** Each row hands back a choice and
/// the work happens with the card's own context, which is still there after
/// the sheet has gone.
enum PostMenuChoice { edit, mute, copyLink, openInTelegram, leaveChannel }

abstract class PostMenuSheet {
  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    Post post,
  ) async {
    final can = ref.read(readerCapabilitiesProvider);
    final mutes = ref.read(mutedChannelsProvider.notifier);
    final isMuted = mutes.isMuted(
      post.channelId,
      chatId: post.chatId,
      username: post.channelUsername,
    );
    // A guest post is a page, not a chat: there is nothing to leave.
    final isSynthetic = GuestPostMapper.isSynthetic(post.chatId);
    final canLeave = can.canJoin && !isSynthetic;

    // Whether this account may rewrite the post — its own channel, or one
    // it edits for. Asked of Telegram rather than guessed, the same
    // `getMessageProperties` the conversation's long-press menu uses, so an
    // Edit row is only ever offered where the edit will be taken.
    final canEdit = can.canMessage &&
        !isSynthetic &&
        (await ref
                .read(chatsRepositoryProvider)
                .messageActions(chatId: post.chatId, messageId: post.messageId))
            .canEdit;
    if (!context.mounted) return;

    final choice = await showAppSheet<PostMenuChoice>(
      context,
      haptic: false,
      children: [
        if (canEdit)
          const AppSheetRow<PostMenuChoice>(
            icon: Icons.edit_outlined,
            label: AppStrings.postMenuEdit,
            value: PostMenuChoice.edit,
          ),
        AppSheetRow<PostMenuChoice>(
          icon: isMuted
              ? Icons.notifications_none_rounded
              : Icons.notifications_off_outlined,
          label: isMuted
              ? AppStrings.postMenuUnmute(post.channelTitle)
              : AppStrings.postMenuMute(post.channelTitle),
          value: PostMenuChoice.mute,
        ),
        const AppSheetRow<PostMenuChoice>(
          icon: Icons.link_rounded,
          label: AppStrings.postMenuCopyLink,
          value: PostMenuChoice.copyLink,
        ),
        const AppSheetRow<PostMenuChoice>(
          icon: Icons.open_in_new_rounded,
          label: AppStrings.postOpenInTelegram,
          value: PostMenuChoice.openInTelegram,
        ),
        if (canLeave) ...[
          const AppSheetDivider(),
          AppSheetRow<PostMenuChoice>(
            icon: Icons.person_remove_outlined,
            label: AppStrings.postMenuLeave(post.channelTitle),
            value: PostMenuChoice.leaveChannel,
            isDestructive: true,
          ),
        ],
      ],
    );
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case PostMenuChoice.edit:
        await _edit(context, ref, post);
      case PostMenuChoice.mute:
        await MuteSheet.show(
          context,
          ref,
          channelId: post.channelId,
          chatId: post.chatId,
          username: post.channelUsername,
        );
      case PostMenuChoice.copyLink:
        await _copyLink(context, ref, post);
      case PostMenuChoice.openInTelegram:
        await _openInTelegram(context, ref, post);
      case PostMenuChoice.leaveChannel:
        await _leave(context, ref, post);
    }
  }

  /// Rewrites the post's words — its text, or its caption when it is media.
  ///
  /// The feed card and the post screen both take the new words at once, from
  /// the same override reactions use; nothing is refetched for an edit
  /// Telegram has already accepted.
  static Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Post post,
  ) async {
    final isCaption = post.media.isNotEmpty;
    final updated = await EditTextDialog.show(
      context,
      initialText: post.text ?? '',
      title: AppStrings.postEditTitle,
      allowsEmpty: isCaption,
    );
    if (updated == null || !context.mounted) return;

    final ok = await ref
        .read(chatsRepositoryProvider)
        .editText(
          chatId: post.chatId,
          messageId: post.messageId,
          text: updated,
          isCaption: isCaption,
        );
    if (!context.mounted) return;

    if (ok) {
      ref.read(optimisticPostUpdatesProvider.notifier).setText(post.id, updated);
      ref.read(feedPostsProvider.notifier).updateTextLive(post.id, updated);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? AppStrings.chatEditSaved : AppStrings.chatEditFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Future<String?> _link(WidgetRef ref, Post post) async {
    if (GuestPostMapper.isSynthetic(post.chatId)) {
      return GuestPostMapper.postLink(post);
    }
    return await ref.read(feedRepositoryProvider).postLink(post) ??
        TelegramIds.postLink(
          chatId: post.chatId,
          messageId: post.messageId,
          username: post.channelUsername,
        );
  }

  static Future<void> _copyLink(
    BuildContext context,
    WidgetRef ref,
    Post post,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final link = await _link(ref, post);
    if (link == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.postNotLinkable)),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: link));
    messenger.showSnackBar(
      const SnackBar(content: Text(AppStrings.postLinkCopied)),
    );
  }

  static Future<void> _openInTelegram(
    BuildContext context,
    WidgetRef ref,
    Post post,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final link = await _link(ref, post);
    final opened = link != null && await openExternalUrl(normalizeUrl(link));
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.postCannotOpenTelegram)),
      );
    }
  }

  /// Leaves the channel, asking first — the same asymmetry the channel page
  /// keeps: joining is one tap to undo, leaving a private channel is not.
  static Future<void> _leave(
    BuildContext context,
    WidgetRef ref,
    Post post,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showAppDialog<bool>(
      context,
      title: AppStrings.channelLeaveConfirmTitle,
      body: AppStrings.channelLeaveConfirmBody(post.channelTitle),
      actions: const [
        AppDialogAction(
          label: AppStrings.channelLeaveConfirmAction,
          value: true,
          isPrimary: true,
          isDestructive: true,
        ),
        AppDialogAction.cancel(AppStrings.channelLeaveCancelAction),
      ],
    );
    if (confirmed != true) return;

    final left = await ref
        .read(channelRepositoryProvider)
        .leaveChannel(post.chatId);
    if (left) {
      ref.invalidate(channelsProvider);
      ref.invalidate(feedPostsProvider);
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          left
              ? AppStrings.channelLeft(post.channelTitle)
              : AppStrings.channelLeaveFailed,
        ),
      ),
    );
  }
}
