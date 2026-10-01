import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/features/chats/presentation/widgets/premium_mark.dart';
import 'package:gramx/features/chats/presentation/widgets/message_send_state_icon.dart';

/// One conversation in the chat list: avatar on the left, name and preview on
/// the right, time at the top right, with a hairline between rows.
class ChatListTile extends StatelessWidget {
  final ChatSummary chat;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Long press on the avatar: opens a read-only preview of the chat. A long
  /// press elsewhere on the row calls [onLongPress].
  final VoidCallback? onPeek;

  /// Tap on the personal channel badge beside the name.
  final VoidCallback? onAffiliatedChannelTap;

  const ChatListTile({
    super.key,
    required this.chat,
    required this.onTap,
    this.onLongPress,
    this.onPeek,
    this.onAffiliatedChannelTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final isUnread = chat.unreadCount > 0 || chat.isMarkedAsUnread;

    return Semantics(
      button: true,
      // Unread is otherwise shown only by colour and weight.
      label: isUnread
          ? '${chat.title}, ${AppStrings.messagesUnreadSemantics(chat.unreadCount)}'
          : chat.title,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: border, width: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(chat: chat, onPeek: onPeek),
                const SizedBox(width: AppSpacing.avatarGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TitleRow(
                        chat: chat,
                        primary: primary,
                        secondary: secondary,
                        onAffiliatedChannelTap: onAffiliatedChannelTap,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      _PreviewRow(
                        chat: chat,
                        secondary: secondary,
                        isUnread: isUnread,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The avatar, with a dot when the user is online.
class _Avatar extends StatelessWidget {
  final ChatSummary chat;
  final VoidCallback? onPeek;

  const _Avatar({required this.chat, this.onPeek});

  @override
  Widget build(BuildContext context) {
    final avatar = _buildAvatar(context);
    if (onPeek == null) return avatar;

    return Semantics(
      button: true,
      label: AppStrings.chatPeekSemantics(chat.title),
      child: GestureDetector(
        // The innermost detector wins, so the row's long press doesn't fire.
        onLongPress: onPeek,
        child: avatar,
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    // Saved Messages gets a bookmark instead of the user's own photo.
    final avatar = chat.kind == ChatKind.savedMessages
        ? const CircleAvatar(
            radius: AppSpacing.avatarSizeLarge / 2,
            backgroundColor: AppColors.accent,
            child: Icon(Icons.bookmark_rounded, color: Colors.white, size: 22),
          )
        : ChannelAvatar(
            title: chat.title,
            avatarPath: chat.avatarPath,
            avatarFileId: chat.avatarFileId,
            avatarColorHex: chat.avatarColorHex,
            radius: AppSpacing.avatarSizeLarge / 2,
          );

    if (chat.presence != ChatPresence.online) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          // Ringed in the background colour to separate it from the avatar.
          child: Semantics(
            label: AppStrings.chatOnline,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                // Accent rather than green, which this app uses for reposts.
                color: AppColors.accent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleRow extends StatelessWidget {
  final ChatSummary chat;
  final Color primary;
  final Color secondary;
  final VoidCallback? onAffiliatedChannelTap;

  const _TitleRow({
    required this.chat,
    required this.primary,
    required this.secondary,
    this.onAffiliatedChannelTap,
  });

  @override
  Widget build(BuildContext context) {
    // The name side is Expanded so the timestamp stays at the right edge. A
    // Flexible plus Spacer would split the free space and centre it.
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  chat.title,
                  style: AppTypography.displayName(color: primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // The lock comes first: it is the only thing that tells a secret
              // chat apart from the regular chat with the same user.
              if (chat.isSecret) ...[
                const SizedBox(width: AppSpacing.xs),
                Tooltip(
                  message: chat.isSecretPending
                      ? AppStrings.secretChatPendingShort
                      : AppStrings.secretChatLockLabel,
                  child: Icon(
                    chat.isSecretPending
                        ? Icons.lock_clock_rounded
                        : Icons.lock_rounded,
                    color: chat.isSecretPending
                        ? secondary
                        : AppColors.verified,
                    size: 14,
                  ),
                ),
              ],
              if (chat.isVerified) ...[
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.verified, color: AppColors.verified, size: 15),
              ],
              // The plain check rather than the emoji status, to keep the list
              // scannable. Verified names already have a check.
              if (chat.isPremium && !chat.isVerified) ...[
                const SizedBox(width: AppSpacing.xs),
                const PremiumCheck(size: 15),
              ],
              // Telegram models a bot as a private chat, so tag it.
              if (chat.kind == ChatKind.bot) ...[
                const SizedBox(width: AppSpacing.xs),
                _Pill(label: AppStrings.messagesBotBadge, color: secondary),
              ],
              if (chat.isMuted) ...[
                const SizedBox(width: AppSpacing.xs),
                Tooltip(
                  message: AppStrings.messagesMuted,
                  child: Icon(
                    Icons.volume_off_rounded,
                    color: secondary,
                    size: 14,
                  ),
                ),
              ],
              if (chat.affiliatedChannelId != null) ...[
                const SizedBox(width: AppSpacing.xs),
                _AffiliationBadge(chat: chat, onTap: onAffiliatedChannelTap),
              ],
            ],
          ),
        ),
        if (chat.lastMessageAt != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            TimeUtils.relativeTime(chat.lastMessageAt!),
            style: AppTypography.timestamp(color: secondary),
          ),
        ],
        // Explains why an older chat sits above newer ones.
        if (chat.isPinned) ...[
          const SizedBox(width: AppSpacing.xs),
          Tooltip(
            message: AppStrings.messagesPinned,
            child: Transform.rotate(
              angle: 0.7,
              child: Icon(Icons.push_pin_outlined, color: secondary, size: 13),
            ),
          ),
        ],
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final ChatSummary chat;
  final Color secondary;
  final bool isUnread;

  const _PreviewRow({
    required this.chat,
    required this.secondary,
    required this.isUnread,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewStyle = AppTypography.body(
      color: isUnread ? theme.colorScheme.onSurface : secondary,
    ).copyWith(fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chat.previewSendState case final state?) ...[
          Padding(
            padding: const EdgeInsets.only(top: 2, right: AppSpacing.xxs),
            child: MessageSendStateIcon(
              state: state,
              color: secondary,
              // No bubble fill here, so read uses the accent rather than white.
              readColor: AppColors.accent,
            ),
          ),
        ],
        Expanded(
          child: RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                if (chat.previewIsDraft)
                  TextSpan(
                    text: '${AppStrings.messagesDraftPrefix}: ',
                    style: previewStyle.copyWith(color: AppColors.like),
                  )
                else if (chat.previewSender != null)
                  TextSpan(
                    text: '${chat.previewSender}: ',
                    style: previewStyle,
                  ),
                TextSpan(text: chat.preview ?? '', style: previewStyle),
              ],
            ),
          ),
        ),
        if (chat.isRequest) ...[
          const SizedBox(width: AppSpacing.sm),
          _Pill(label: AppStrings.messagesRequestBadge, color: secondary),
        ],
        if (isUnread) ...[
          const SizedBox(width: AppSpacing.sm),
          _UnreadBadge(count: chat.unreadCount, isMuted: chat.isMuted),
        ],
      ],
    );
  }
}

/// The unread count, or a plain dot for a chat marked unread by hand.
class _UnreadBadge extends StatelessWidget {
  final int count;

  /// Muted chats get a grey badge instead of the accent.
  final bool isMuted;

  const _UnreadBadge({required this.count, required this.isMuted});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final fill = isMuted ? muted : AppColors.accent;

    if (count <= 0) {
      return Semantics(
        label: AppStrings.messagesMarkedUnread,
        child: Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        AppStrings.messagesUnreadBadge(count),
        textAlign: TextAlign.center,
        style: AppTypography.actionCount(
          color: Colors.white,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// The user's personal channel as a small avatar beside their name, with the
/// channel name in the tooltip. See [ChatSummary.affiliatedChannelId].
class _AffiliationBadge extends StatelessWidget {
  static const double _size = 16;

  final ChatSummary chat;
  final VoidCallback? onTap;

  const _AffiliationBadge({required this.chat, this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = chat.affiliatedChannelTitle;
    final label = title == null
        ? AppStrings.chatAffiliationUnnamed
        : AppStrings.chatAffiliation(title);

    return Semantics(
      button: onTap != null,
      label: label,
      child: Tooltip(
        message: label,
        child: ChannelAvatar(
          // Falls back to an initial until the picture arrives.
          title: title ?? '?',
          avatarPath: chat.affiliatedChannelAvatarPath,
          avatarFileId: chat.affiliatedChannelAvatarFileId,
          avatarColorHex: chat.affiliatedChannelAvatarColorHex,
          radius: _size / 2,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: AppTypography.timestamp(color: color)),
    );
  }
}
