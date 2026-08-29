import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/presentation/widgets/compose_media_kind_sheet.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';

/// The bar at the bottom of a conversation.
///
/// Deliberately not the full compose screen. Writing a channel post is a
/// deliberate act with a destination picker, a character ring and a discard
/// confirmation; writing a message is a line you type and send. What the two
/// *do* share is the attachment model and the picker, so a photo attached here
/// travels through exactly the same code that attaches one to a post.
class MessageComposer extends ConsumerStatefulWidget {
  /// The message being replied to, if any. The bar shows a cancellable quote
  /// above the field while one is set.
  final ChatMessage? replyTo;
  final VoidCallback? onCancelReply;

  /// Called with the text and any attachments. Returns whether it went.
  final Future<bool> Function(String text, List<ComposeAttachment> attachments)
  onSend;

  /// Called on every keystroke, so the screen can tell Telegram this account is
  /// typing — throttled by `TypingSignal`, never per keystroke on the wire.
  final ValueChanged<String>? onChanged;

  /// What TDLib already holds as this chat's draft, restored into the field.
  ///
  /// The chat list has always *shown* drafts, but nothing here wrote or read
  /// one — so a draft in the list could only ever have come from another
  /// Telegram client, and anything typed here and abandoned was lost.
  final String? initialText;

  /// Called with whatever is unsent when the composer goes away, so it survives
  /// leaving the screen and follows the reader to their other clients.
  final ValueChanged<String>? onDraftChanged;

  const MessageComposer({
    super.key,
    required this.onSend,
    this.replyTo,
    this.onCancelReply,
    this.onChanged,
    this.initialText,
    this.onDraftChanged,
  });

  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<MessageComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final List<ComposeAttachment> _attachments = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialText;
    if (draft != null && draft.isNotEmpty) _controller.text = draft;
  }

  @override
  void dispose() {
    // Saved on the way out rather than per keystroke: a draft is what is left
    // when somebody walks away, and `SetChatDraftMessage` reaches the network.
    widget.onDraftChanged?.call(_controller.text);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _canSend =>
      !_isSending &&
      (_controller.text.trim().isNotEmpty || _attachments.isNotEmpty);

  Future<void> _attach() async {
    final picker = ref.read(composeMediaPickerProvider);
    final choice = await ComposeMediaKindSheet.show(context);
    if (choice == null || !mounted) return;

    final attachment = choice == ComposeMediaKind.photo
        ? await picker.pickPhoto()
        : await picker.pickVideo();
    if (attachment == null || !mounted) return;
    setState(() => _attachments.add(attachment));
  }

  Future<void> _send() async {
    if (!_canSend) return;
    final text = _controller.text.trim();
    final attachments = List<ComposeAttachment>.from(_attachments);

    setState(() => _isSending = true);
    // Cleared before the await, not after: the sender should be able to start
    // the next message immediately, and the bubble is already on screen
    // optimistically by the time this returns.
    _controller.clear();
    _attachments.clear();
    // The send path clears TDLib's draft too, so nothing here should write the
    // just-sent text back on the way out.
    widget.onDraftChanged?.call('');

    final sent = await widget.onSend(text, attachments);
    if (!mounted) return;
    setState(() => _isSending = false);

    if (!sent) {
      // Put it back rather than losing what somebody wrote.
      _controller.text = text;
      _attachments.addAll(attachments);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.chatSendFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final fill = isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyTo != null)
              _ReplyBar(
                message: widget.replyTo!,
                onCancel: widget.onCancelReply,
              ),
            if (_attachments.isNotEmpty)
              _AttachmentStrip(
                attachments: _attachments,
                onRemove: (attachment) =>
                    setState(() => _attachments.remove(attachment)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: AppStrings.chatAttach,
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.accent,
                    ),
                    onPressed: _attach,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      maxLines: 5,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      style: AppTypography.body(color: primary),
                      onChanged: (value) {
                        widget.onChanged?.call(value);
                        // Rebuilds the send button's enabled state. The field
                        // itself is uncontrolled, so this costs one setState
                        // per keystroke and no request at all.
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: AppStrings.chatComposerHint,
                        hintStyle: AppTypography.body(color: secondary),
                        filled: true,
                        fillColor: fill,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _SendButton(
                    isEnabled: _canSend,
                    isSending: _isSending,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _send();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool isEnabled;
  final bool isSending;
  final VoidCallback onPressed;

  const _SendButton({
    required this.isEnabled,
    required this.isSending,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idle = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return IconButton(
      tooltip: AppStrings.chatSend,
      // Disabled rather than hidden: the button's position is where somebody's
      // thumb already is, and a control that moves as you type is worse than
      // one that greys out.
      onPressed: isEnabled ? onPressed : null,
      icon: isSending
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            )
          : Icon(
              Icons.arrow_upward_rounded,
              color: isEnabled ? AppColors.accent : idle,
            ),
    );
  }
}

/// Who the reply being written is to, above the field.
///
/// no accent bar down the side. Both places show the same thing, so both
/// should look like the same thing.
class _ReplyBar extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onCancel;

  const _ReplyBar({required this.message, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, size: 14, color: secondary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderName == null
                      ? AppStrings.chatReplyingTo
                      : AppStrings.chatReplyingToName(message.senderName!),
                  style: AppTypography.timestamp(
                    color: AppColors.accent,
                  ).copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  message.text ?? '',
                  style: AppTypography.timestamp(color: secondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: AppStrings.chatCancelReply,
            icon: Icon(Icons.close_rounded, color: secondary, size: 18),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// Thumbnails of what is attached but not yet sent.
class _AttachmentStrip extends StatelessWidget {
  final List<ComposeAttachment> attachments;
  final ValueChanged<ComposeAttachment> onRemove;

  const _AttachmentStrip({required this.attachments, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          0,
        ),
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                child: attachment.isPhoto
                    ? Image.file(
                        File(attachment.path),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 64,
                        height: 64,
                        color: Colors.black,
                        child: const Icon(
                          Icons.videocam_rounded,
                          color: Colors.white,
                        ),
                      ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: IconButton(
                  tooltip: AppStrings.composeRemoveAttachment,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.black87,
                    child: Icon(
                      Icons.close_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: () => onRemove(attachment),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
