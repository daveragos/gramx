import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/chats/presentation/widgets/bubble_media.dart';
import 'package:gramx/features/chats/presentation/widgets/message_reactions_row.dart';
import 'package:gramx/features/chats/presentation/widgets/place_bubble.dart';
import 'package:gramx/features/chats/presentation/widgets/message_send_state_icon.dart';
import 'package:gramx/features/chats/presentation/widgets/secret_media_bubble.dart';
import 'package:gramx/features/feed/presentation/widgets/poll_card.dart';

/// One message in a conversation.
///
/// accent blue, incoming on the left on a neutral surface, both capped at a
/// share of the screen so a long line wraps instead of running edge to edge.
///
/// The bubble draws only what the message actually has. A name row appears in
/// groups and not in private chats, an avatar only under the last of a run, a
/// tick only on messages this account sent — each of those absences is a
/// decision made in [ConversationRows] or here, never a widget rendering empty.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  /// Whether this chat has more than two people in it.
  final bool isGroup;

  /// First of a run from the same sender: carries the name.
  final bool isFirstInGroup;

  /// Last of a run: carries the avatar and the timestamp.
  final bool isLastInGroup;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Flashed when a reply jump lands on this bubble, so the reader can see
  /// where they were sent.
  final bool isHighlighted;

  /// Tapping the quoted line jumps to what was replied to.
  final VoidCallback? onReplyTap;

  /// Tapping an `@name` in the body. Supplied by the screen, because resolving
  /// one reaches Telegram and a widget must not.
  final ValueChanged<String>? onMentionTap;
  final void Function(String emoji)? onReactionTap;

  /// Tapping the sender's face in a group. gramX now has somewhere for a
  /// person to lead to, and the avatar is where every chat app puts that door.
  final VoidCallback? onSenderTap;

  /// Records an answer to the poll in this bubble. Supplied by the screen,
  /// because voting reaches Telegram and a widget must not.
  final Future<void> Function(List<int> optionIds)? onVote;

  /// Opens media that disappears once it is opened. Null on an outgoing one and
  /// on one that has already been opened — and null is what makes the cover
  /// untappable, so a bubble cannot offer a tap that destroys nothing.
  final VoidCallback? onOpenSecretMedia;

  /// Opens a location or venue in a maps app. Supplied by the screen, because
  /// launching one leaves the app.
  final VoidCallback? onOpenPlace;

  /// Opens the profile of a shared contact. Null when they are not on Telegram.
  final ValueChanged<int>? onOpenContact;

  /// Whether the conversation is in selection mode. Every bubble reserves the
  /// tick gutter while it is, so ticking one does not shunt the others
  /// sideways under the reader's thumb.
  final bool isSelecting;

  /// Whether this one is ticked.
  final bool isSelected;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isGroup,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    this.isHighlighted = false,
    this.onTap,
    this.onLongPress,
    this.onReplyTap,
    this.onMentionTap,
    this.onReactionTap,
    this.onSenderTap,
    this.onVote,
    this.onOpenSecretMedia,
    this.onOpenPlace,
    this.onOpenContact,
    this.isSelecting = false,
    this.isSelected = false,
  });

  /// enough for a paragraph, narrow enough that the other side of the
  /// conversation is always visibly there.
  static const double maxWidthFraction = 0.78;

  @override
  Widget build(BuildContext context) {
    // Telegram's own narration about the chat — "you joined", "photo changed" —
    // is centred and unbubbled, so it reads as the app talking rather than as
    // something a person said.
    if (message.isService) return _ServiceLine(message: message);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOutgoing = message.isOutgoing;
    final maxWidth = MediaQuery.of(context).size.width * maxWidthFraction;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      // Selection wins over the jump flash: the flash is a moment, the tick is
      // a state, and a bubble that lost its tint mid-selection would read as
      // having been unticked.
      color: isSelected
          ? AppColors.accent.withValues(alpha: 0.18)
          : (isHighlighted
                ? AppColors.accent.withValues(alpha: 0.12)
                : Colors.transparent),
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: isFirstInGroup ? AppSpacing.sm : AppSpacing.xxs,
        bottom: isLastInGroup ? AppSpacing.xs : 0,
      ),
      child: Row(
        mainAxisAlignment: isOutgoing
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // The tick, on the leading edge for both sides. Colour alone does not
          // say a message is selected — the tint is easy to miss on one bubble
          // in a run — so the state is drawn as a mark as well.
          if (isSelecting) ...[
            Semantics(
              selected: isSelected,
              child: Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: isSelected
                    ? AppColors.accent
                    : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          // The avatar gutter is reserved for every incoming bubble in a group,
          // not just the one that draws an avatar — otherwise a run of messages
          // steps sideways under the one that has it.
          if (!isOutgoing && isGroup) ...[
            SizedBox(
              width: AppSpacing.avatarSizeSmall,
              child: isLastInGroup
                  ? ChannelAvatar(
                      title: message.senderName ?? '?',
                      avatarPath: message.senderAvatarPath,
                      avatarFileId: message.senderAvatarFileId,
                      avatarColorHex: message.senderAvatarColorHex,
                      radius: AppSpacing.avatarSizeSmall / 2,
                      onTap: onSenderTap,
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isOutgoing
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _Body(
                  message: message,
                  isGroup: isGroup,
                  isFirstInGroup: isFirstInGroup,
                  isLastInGroup: isLastInGroup,
                  maxWidth: maxWidth,
                  onTap: onTap,
                  onLongPress: onLongPress,
                  onReplyTap: onReplyTap,
                  onMentionTap: onMentionTap,
                  onVote: onVote,
                  onOpenSecretMedia: onOpenSecretMedia,
                  onOpenPlace: onOpenPlace,
                  onOpenContact: onOpenContact,
                ),
                if (message.reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: MessageReactionsRow(
                      reactions: message.reactions,
                      chosen: message.chosenReactions,
                      onTap: onReactionTap,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The bubble itself.
class _Body extends StatelessWidget {
  final ChatMessage message;
  final bool isGroup;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final double maxWidth;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onReplyTap;
  final ValueChanged<String>? onMentionTap;
  final Future<void> Function(List<int> optionIds)? onVote;
  final VoidCallback? onOpenSecretMedia;
  final VoidCallback? onOpenPlace;
  final ValueChanged<int>? onOpenContact;

  const _Body({
    required this.message,
    required this.isGroup,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.maxWidth,
    this.onTap,
    this.onLongPress,
    this.onReplyTap,
    this.onMentionTap,
    this.onVote,
    this.onOpenSecretMedia,
    this.onOpenPlace,
    this.onOpenContact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOutgoing = message.isOutgoing;

    final bubbleColor = isOutgoing
        ? AppColors.accent
        : (isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant);
    final textColor = isOutgoing ? Colors.white : theme.colorScheme.onSurface;
    final metaColor = isOutgoing
        ? Colors.white.withValues(alpha: 0.75)
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    // A sticker is the whole message and Telegram draws it with no bubble at
    // all — a coloured box behind a die-cut image looks like a bug.
    final isBareSticker =
        message.media.length == 1 &&
        message.media.first.type == MediaType.sticker &&
        (message.text == null || message.text!.isEmpty);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isGroup &&
            !isOutgoing &&
            isFirstInGroup &&
            message.senderName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
            child: Text(
              message.senderName!,
              style: AppTypography.username(
                color: AppColors.accent,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        if (message.forwardedFromTitle != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
            child: Text(
              AppStrings.chatForwardedFrom(message.forwardedFromTitle!),
              style: AppTypography.timestamp(
                color: metaColor,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        if (message.replyToMessageId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _ReplyQuote(
              message: message,
              accent: isOutgoing ? Colors.white : AppColors.accent,
              textColor: textColor,
              metaColor: metaColor,
              onTap: onReplyTap,
            ),
          ),
        // Media that disappears is drawn as a cover, never as itself. The
        // thumbnail is a small copy of the picture, and a feature whose whole
        // point is that it has not been seen cannot lead with one.
        if (message.isSecretMedia)
          Padding(
            padding: EdgeInsets.only(
              bottom: message.isMediaOnly ? 0 : AppSpacing.xs,
            ),
            child: SecretMediaCover(
              message: message,
              maxWidth: maxWidth - AppSpacing.md * 2,
              foregroundColor: textColor,
              mutedColor: metaColor,
              onOpen: message.isOutgoing ? null : onOpenSecretMedia,
            ),
          )
        else
          for (final item in message.media)
            Padding(
              padding: EdgeInsets.only(
                bottom: message.isMediaOnly ? 0 : AppSpacing.xs,
              ),
              child: BubbleMedia(
                item: item,
                // The bubble's padding is inside its width, so the media gets
                // what is left of it.
                maxWidth: maxWidth - AppSpacing.md * 2,
                isAlone: message.isMediaOnly,
              ),
            ),
        if (message.place case final place?)
          PlaceBubble(
            place: place,
            maxWidth: maxWidth - AppSpacing.md * 2,
            foregroundColor: textColor,
            mutedColor: metaColor,
            onOpen: onOpenPlace,
          ),
        if (message.contact case final contact?)
          ContactBubble(
            contact: contact,
            maxWidth: maxWidth - AppSpacing.md * 2,
            foregroundColor: textColor,
            mutedColor: metaColor,
            onOpen: contact.hasTelegramAccount && onOpenContact != null
                ? () => onOpenContact!(contact.userId)
                : null,
          ),
        if (message.poll case final poll?)
          PollCard(
            poll: poll,
            isEmbedded: true,
            foregroundColor: textColor,
            mutedColor: metaColor,
            // On an outgoing bubble the accent *is* the background, so the
            // bars and ticks borrow the bubble's foreground instead.
            accentColor: isOutgoing ? textColor : AppColors.accent,
            onVote: onVote ?? (_) async {},
          ),
        if (message.text != null && message.text!.isNotEmpty)
          TextEntityRenderer(
            text: message.text!,
            entities: message.entities,
            style: AppTypography.body(color: textColor),
            onMentionTap: onMentionTap,
            // The long press belongs to the bubble. See
            // [TextEntityRenderer.selectable].
            selectable: false,
            // An outgoing bubble *is* the accent colour, so a mention or link
            // drawn in accent on it is invisible. Handing the renderer the
            // bubble's own foreground makes it legible, and it underlines when
            // overridden so colour is not the only signal left.
            linkColor: isOutgoing ? textColor : null,
          ),
        if (message.unsupportedKind != null)
          Text(
            AppStrings.chatUnsupported,
            style: AppTypography.body(
              color: metaColor,
            ).copyWith(fontStyle: FontStyle.italic),
          ),
        const SizedBox(height: AppSpacing.xxs),
        _MetaRow(message: message, color: metaColor),
      ],
    );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: isBareSticker
            ? content
            : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: _radius(isOutgoing),
                ),
                child: content,
              ),
      ),
    );
  }

  /// on the last of a run, which squares off into the tail.
  BorderRadius _radius(bool isOutgoing) {
    const round = Radius.circular(18);
    const tail = Radius.circular(4);
    return BorderRadius.only(
      topLeft: !isOutgoing && !isFirstInGroup ? tail : round,
      topRight: isOutgoing && !isFirstInGroup ? tail : round,
      bottomLeft: !isOutgoing && isLastInGroup ? tail : round,
      bottomRight: isOutgoing && isLastInGroup ? tail : round,
    );
  }
}

/// Who this message is answering, above the answer.
///
/// left, the author in bold, the quoted words indented behind it — a card
/// says "Replying to @ada" in one grey line and lets the message itself be the
/// message. That is what this is: a naming line, then the quoted words in the
/// same muted weight underneath, with nothing drawn around either.
///
/// It stays tappable — the line is the jump to what was replied to — so it
/// carries the reply glyph and the name in the accent colour rather than a
/// border to say so.
class _ReplyQuote extends StatelessWidget {
  final ChatMessage message;
  final Color accent;
  final Color textColor;
  final Color metaColor;
  final VoidCallback? onTap;

  const _ReplyQuote({
    required this.message,
    required this.accent,
    required this.textColor,
    required this.metaColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = message.replyToAuthorName;
    final quoted = message.replyToText;

    return Semantics(
      button: onTap != null,
      label: name == null
          ? AppStrings.chatReplyingTo
          : AppStrings.chatReplyingToName(name),
      child: GestureDetector(
        onTap: onTap,
        // Opaque so the whole line is the target, not just the glyphs in it.
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.reply_rounded, size: 12, color: metaColor),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    name == null
                        ? AppStrings.chatReplyingTo
                        : AppStrings.chatReplyingToName(name),
                    style: AppTypography.timestamp(
                      color: accent,
                    ).copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Null when the replied-to message is older than the loaded page.
            // The naming line alone is honest; inventing a preview is not.
            if (quoted != null && quoted.isNotEmpty)
              Text(
                quoted,
                style: AppTypography.timestamp(color: metaColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

/// Time, the edited mark, and the delivery tick.
class _MetaRow extends StatelessWidget {
  final ChatMessage message;
  final Color color;

  const _MetaRow({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(message.sentAt);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.editedAt != null) ...[
          Text(
            AppStrings.chatEdited,
            style: AppTypography.timestamp(color: color),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Text(
          time.format(context),
          style: AppTypography.timestamp(color: color),
        ),
        if (message.isOutgoing) ...[
          const SizedBox(width: AppSpacing.xs),
          MessageSendStateIcon(state: message.sendState, color: color),
        ],
      ],
    );
  }
}

/// Telegram's own narration about the chat, centred and unbubbled.
class _ServiceLine extends StatelessWidget {
  final ChatMessage message;
  const _ServiceLine({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.sm,
      ),
      child: Center(
        child: Text(
          message.text ?? '',
          textAlign: TextAlign.center,
          style: AppTypography.timestamp(color: secondary),
        ),
      ),
    );
  }
}
