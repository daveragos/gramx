import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/features/chats/presentation/widgets/message_send_state_icon.dart';

/// One conversation in the messages list.
///
/// preview in the right column, the time at the top right. Rows are separated
/// by a hairline, never a gap or a card — the same rule the feed follows.
class ChatListTile extends StatelessWidget {
  final ChatSummary chat;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Held down on the **avatar** specifically: opens a read-only look into the
  /// conversation. Two different long presses on one row, and the split is
  /// deliberate — the row's own long press is the actions sheet, and the face
  /// is the part of the row that stands for the person you want to look in on.
  final VoidCallback? onPeek;

  /// Tapping the channel badge beside somebody's name.
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
      // The unread state is a blue dot and a heavier weight — colour and
      // weight alone, which is exactly the case the accessibility rule names.
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

/// The avatar, with the online pip for a person who is online right now.
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
        // Innermost wins the arena, so this takes the press without the row's
        // own long press — the actions sheet — also firing.
        onLongPress: onPeek,
        child: avatar,
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    // Saved Messages is a private chat with yourself, so its "avatar" is your
    // own face — which reads as a conversation with a stranger who looks
    // exactly like you. Every Telegram client substitutes a mark instead.
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
          // Ringed in the page's own background so the pip reads as a badge on
          // the avatar rather than a dot floating over it.
          child: Semantics(
            label: AppStrings.chatOnline,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                // Blue, not the green Telegram uses. Green is this app's
                // repost colour and means something else here; presence is the
                // accent, which is what the header's live states use too.
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
    // The name side is one Expanded child and the timestamp is a plain trailing
    // one. It used to be `Flexible(title) … Spacer() … time`, and those two
    // share the free space by flex factor — so a short name left the Spacer
    // with only half of what was going spare and the timestamp landed in the
    // middle of the row. Only long names, which consumed their whole share,
    // looked right.
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
              if (chat.isVerified) ...[
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.verified, color: AppColors.verified, size: 15),
              ],
              // A bot is a private chat in Telegram's model, so nothing about
              // the row says so by itself — and the difference between a person
              // and a piece of software is worth one tag.
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
              // somebody works for — who they speak for, next to who they are.
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
        // The ordering already puts a pinned chat on top, but nothing said
        // *why* — so a pin was indistinguishable from a busy conversation, and
        // an old chat sitting above a new one looked like a sorting bug.
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
        // The tick sits before the words, which is where every messaging app
        // puts it: the line already begins with "You: " often enough that the
        // mark reads as part of the same statement about your own message.
        if (chat.previewSendState case final state?) ...[
          Padding(
            padding: const EdgeInsets.only(top: 2, right: AppSpacing.xxs),
            child: MessageSendStateIcon(
              state: state,
              color: secondary,
              // On a bubble, read is white against the accent fill. In a list
              // there is no fill, so it takes the accent itself — otherwise
              // "read" would be invisible on a light background.
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
                // A draft is marked, because otherwise the thing you started
                // saying looks exactly like something you already said.
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

/// A chat marked unread by hand has no count, so the badge is a plain dot —
/// which is the honest shape for "something here, no number for it".
class _UnreadBadge extends StatelessWidget {
  final int count;

  /// A muted chat's badge is grey rather than blue — Telegram's own
  /// convention, and the useful one: the count still says how much is waiting,
  /// while the colour says none of it will interrupt you. The crossed-out
  /// speaker beside the name is the same fact stated twice, which is what makes
  /// mute readable at a glance down a list rather than one icon at a time.
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

/// The channel a person runs, beside their name.
///
/// Present only when Telegram has already told us about it — see
/// [ChatSummary.affiliatedChannelId] for why this is never fetched per row.
///
/// **The picture and nothing else.** Spelling the channel's name out put two
/// names on one line, competing with the one that actually belongs to the
/// person — and the row still has to fit a timestamp and a pin. The megaphone
/// beside it was a third thing saying "channel" when the avatar already looks
/// like one. The name survives as the label and the tooltip, which is where a
/// detail nobody needs at a glance belongs.
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
          // The avatar falls back to an initial, so a channel whose picture has
          // not arrived is still a mark rather than a hole in the row.
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
