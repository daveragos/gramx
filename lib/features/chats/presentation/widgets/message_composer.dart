import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/domain/message_schedule.dart';
import 'package:gramx/features/compose/data/voice_recorder.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/poll_draft.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
import 'package:gramx/features/compose/presentation/widgets/compose_media_kind_sheet.dart';
import 'package:gramx/features/compose/presentation/widgets/poll_composer_sheet.dart';
import 'package:gramx/features/compose/presentation/widgets/self_destruct_sheet.dart';
import 'package:gramx/features/chats/presentation/widgets/voice_record_bar.dart';

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

  /// Called with the text, any attachments, and when it should go. Returns
  /// whether Telegram took it.
  final Future<bool> Function(
    String text,
    List<ComposeAttachment> attachments,
    MessageSchedule schedule,
  )
  onSend;

  /// Asks when a message should go out. Null where scheduling makes no sense,
  /// which is what hides the long-press on the send button.
  final Future<MessageSchedule?> Function()? onPickSchedule;

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

  /// Sends a poll. Null where Telegram will not take one — a private chat with
  /// a person — which is also what hides the row that would offer it.
  final Future<bool> Function(PollDraft draft)? onSendPoll;

  /// Whether media sent from here may be given a self-destruct timer.
  ///
  /// True only in a one-to-one chat: Telegram refuses a disappearing message
  /// anywhere else, so the control is absent rather than present and rejected.
  final bool allowsSelfDestruct;

  /// Whether this chat takes voice messages. False hides the microphone, which
  /// is otherwise where the send button sits when nothing is typed.
  final bool allowsVoiceNotes;

  /// Whether this chat takes round video messages.
  final bool allowsVideoNotes;

  /// Whether this chat takes files. Hides the "File" row in the attach sheet.
  final bool allowsDocuments;

  /// Records a round video message and hands back what was recorded. Supplied
  /// by the screen, because it opens a camera route and a widget must not.
  final Future<ComposeAttachment?> Function()? onRecordVideoNote;

  /// Sends a location, having asked the device where it is. Also supplied by
  /// the screen — it needs a permission prompt and an error path.
  final Future<bool> Function()? onSendLocation;

  /// Sends one of the account's Telegram contacts.
  final Future<bool> Function()? onSendContact;

  const MessageComposer({
    super.key,
    required this.onSend,
    this.replyTo,
    this.onCancelReply,
    this.onChanged,
    this.initialText,
    this.onDraftChanged,
    this.onSendPoll,
    this.allowsSelfDestruct = false,
    this.allowsVoiceNotes = false,
    this.allowsVideoNotes = false,
    this.allowsDocuments = false,
    this.onRecordVideoNote,
    this.onSendLocation,
    this.onSendContact,
    this.onPickSchedule,
  });

  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<MessageComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final List<ComposeAttachment> _attachments = [];
  bool _isSending = false;

  /// Running while a voice message is being recorded, null otherwise.
  ///
  /// The recorder is created per recording and disposed with it rather than
  /// held for the lifetime of the composer: it owns a platform audio session,
  /// and one kept open in every chat the reader visits is a microphone
  /// indicator that never goes out.
  VoiceRecorder? _recorder;

  /// Redraws the clock and the bars while recording. There is nothing else to
  /// rebuild on, because the amplitudes accumulate inside the recorder.
  Timer? _recordTicker;

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
    _recordTicker?.cancel();
    // Leaving the screen mid-recording throws it away rather than sending it.
    // A voice message somebody walked away from is not one they meant to send.
    unawaited(_recorder?.cancel().then((_) => _recorder?.dispose()));
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _isRecording => _recorder != null;

  /// Whether the trailing button is a microphone rather than a send arrow.
  ///
  /// send and a microphone when there is not, so one thumb position does the
  /// obvious thing either way.
  bool get _showMicrophone =>
      widget.allowsVoiceNotes && !_canSend && !_isSending;

  Future<void> _startRecording() async {
    if (_isRecording) return;

    final recorder = VoiceRecorder();
    final failure = await recorder.start();
    if (!mounted) {
      await recorder.dispose();
      return;
    }

    if (failure != null) {
      await recorder.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failure == VoiceRecordFailure.noPermission
                ? AppStrings.voiceNoMicrophone
                : AppStrings.voiceUnavailable,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _recorder = recorder);
    _recordTicker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      // Stops itself at the ceiling and keeps what it has — a recorder that ran
      // on in somebody's pocket is the failure this guards.
      if (recorder.elapsed >= VoiceRecorder.maxDuration) {
        _finishRecording();
        return;
      }
      setState(() {});
    });
  }

  Future<void> _cancelRecording() async {
    final recorder = _recorder;
    if (recorder == null) return;

    _recordTicker?.cancel();
    _recordTicker = null;
    setState(() => _recorder = null);
    await recorder.cancel();
    await recorder.dispose();
  }

  Future<void> _finishRecording() async {
    final recorder = _recorder;
    if (recorder == null) return;

    _recordTicker?.cancel();
    _recordTicker = null;
    setState(() => _recorder = null);

    final attachment = await recorder.stop();
    await recorder.dispose();
    if (!mounted) return;

    if (attachment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.voiceTooShort),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Sent on its own, not staged. A voice message is a whole message —
    // Telegram cannot group one into an album, and there is no second thing a
    // writer means to add to it after holding a button for ten seconds.
    await _sendNow([attachment]);
  }

  /// Sends one thing immediately, keeping whatever is typed where it is.
  Future<void> _sendNow(List<ComposeAttachment> attachments) async {
    setState(() => _isSending = true);
    final sent = await widget.onSend('', attachments, MessageSchedule.now);
    if (!mounted) return;
    setState(() => _isSending = false);

    if (sent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.chatSendFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _recordVideoNote() async {
    final record = widget.onRecordVideoNote;
    if (record == null) return;

    final attachment = await record();
    if (attachment == null || !mounted) return;
    await _sendNow([attachment]);
  }

  bool get _canSend =>
      !_isSending &&
      (_controller.text.trim().isNotEmpty || _attachments.isNotEmpty);

  Future<void> _attach() async {
    final picker = ref.read(composeMediaPickerProvider);
    final choice = await ComposeMediaKindSheet.show(
      context,
      includePoll: widget.onSendPoll != null,
      includeDocument: widget.allowsDocuments,
      includeVideoNote: widget.allowsVideoNotes && widget.onRecordVideoNote != null,
      includeLocation: widget.onSendLocation != null,
      includeContact: widget.onSendContact != null,
    );
    if (choice == null || !mounted) return;

    switch (choice) {
      case ComposeAttachChoice.poll:
        await _composePoll();
        return;
      case ComposeAttachChoice.videoNote:
        await _recordVideoNote();
        return;
      case ComposeAttachChoice.location:
        await _sendFrom(widget.onSendLocation, AppStrings.locationSendFailed);
        return;
      case ComposeAttachChoice.contact:
        await _sendFrom(widget.onSendContact, AppStrings.contactSendFailed);
        return;
      case ComposeAttachChoice.photo:
      case ComposeAttachChoice.video:
      case ComposeAttachChoice.document:
        break;
    }

    final attachment = switch (choice) {
      ComposeAttachChoice.photo => await picker.pickPhoto(),
      ComposeAttachChoice.video => await picker.pickVideo(),
      _ => await picker.pickDocument(),
    };
    if (attachment == null || !mounted) return;
    setState(() => _attachments.add(attachment));
  }

  /// Runs one of the screen's own send callbacks and reports a refusal.
  ///
  /// A location and a contact are both "the screen does something and the
  /// message appears" — there is nothing to stage in the composer for either,
  /// so neither goes through the attachment list.
  Future<void> _sendFrom(
    Future<bool> Function()? send,
    String failureMessage,
  ) async {
    if (send == null) return;
    final sent = await send();
    if (sent || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failureMessage),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _composePoll() async {
    final send = widget.onSendPoll;
    if (send == null) return;

    final draft = await PollComposerSheet.show(context);
    if (draft == null || !mounted) return;

    final sent = await send(draft);
    if (sent || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.pollComposeSendFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Sets how long one attachment survives after it is opened.
  ///
  /// Per attachment rather than per message: somebody sending three pictures
  /// may well mean only one of them to disappear, and Telegram's own field is
  /// on the media, not on the send.
  Future<void> _setSelfDestruct(ComposeAttachment attachment) async {
    final choice = await SelfDestructSheet.show(
      context,
      current: attachment.selfDestruct,
    );
    if (choice == null || !mounted) return;

    final index = _attachments.indexOf(attachment);
    if (index < 0) return;
    setState(
      () => _attachments[index] = attachment.copyWith(selfDestruct: choice),
    );
  }

  void _toggleSpoiler(ComposeAttachment attachment) {
    final index = _attachments.indexOf(attachment);
    if (index < 0) return;
    setState(
      () => _attachments[index] = attachment.copyWith(
        hasSpoiler: !attachment.hasSpoiler,
      ),
    );
  }

  /// Asks when, then sends. The long-press on the send button.
  Future<void> _sendLater() async {
    final pick = widget.onPickSchedule;
    if (pick == null || !_canSend) return;

    final schedule = await pick();
    if (schedule == null || !mounted) return;
    await _send(schedule: schedule);
  }

  Future<void> _send({MessageSchedule schedule = MessageSchedule.now}) async {
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

    final sent = await widget.onSend(text, attachments, schedule);
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
                allowsSelfDestruct: widget.allowsSelfDestruct,
                onRemove: (attachment) =>
                    setState(() => _attachments.remove(attachment)),
                onSelfDestruct: _setSelfDestruct,
                onToggleSpoiler: _toggleSpoiler,
              ),
            if (_isRecording)
              VoiceRecordBar(
                elapsed: _recorder!.elapsed,
                waveform: _recorder!.liveWaveform,
                onCancel: _cancelRecording,
                onSend: _finishRecording,
              )
            else
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
                  if (_showMicrophone)
                    IconButton(
                      tooltip: AppStrings.voiceRecord,
                      icon: const Icon(
                        Icons.mic_none_rounded,
                        color: AppColors.accent,
                      ),
                      onPressed: _startRecording,
                    )
                  else
                    _SendButton(
                      isEnabled: _canSend,
                      isSending: _isSending,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _send();
                      },
                      // Telegram's gesture, and the reason scheduling needs no
                      // button of its own: the control that sends a message is
                      // where somebody would look to send it later.
                      onLongPress: widget.onPickSchedule == null
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              _sendLater();
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

  /// Opens the "send later" sheet. Null where scheduling is not offered.
  final VoidCallback? onLongPress;

  const _SendButton({
    required this.isEnabled,
    required this.isSending,
    required this.onPressed,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idle = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return GestureDetector(
      // The long press is on a wrapper rather than on the IconButton, which has
      // no long-press of its own. The tooltip names both, because a gesture
      // nothing announces is a gesture nobody finds.
      onLongPress: isEnabled ? onLongPress : null,
      child: IconButton(
        tooltip: onLongPress == null
            ? AppStrings.chatSend
            : AppStrings.chatSendOrSchedule,
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
///
/// Each tile carries what will happen to that file: a timer glyph when it is
/// set to disappear, a spoiler glyph when it will arrive covered. Both are on
/// the tile rather than in a menu because the setting is per file, and a
/// message with one disappearing picture in three has to be able to say which.
class _AttachmentStrip extends StatelessWidget {
  final List<ComposeAttachment> attachments;

  /// Whether this chat may carry disappearing media at all. False hides the
  /// timer control rather than disabling it.
  final bool allowsSelfDestruct;

  final ValueChanged<ComposeAttachment> onRemove;
  final ValueChanged<ComposeAttachment> onSelfDestruct;
  final ValueChanged<ComposeAttachment> onToggleSpoiler;

  const _AttachmentStrip({
    required this.attachments,
    required this.allowsSelfDestruct,
    required this.onRemove,
    required this.onSelfDestruct,
    required this.onToggleSpoiler,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
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
          return _AttachmentTile(
            attachment: attachment,
            allowsSelfDestruct: allowsSelfDestruct,
            onRemove: () => onRemove(attachment),
            onSelfDestruct: () => onSelfDestruct(attachment),
            onToggleSpoiler: () => onToggleSpoiler(attachment),
          );
        },
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final ComposeAttachment attachment;
  final bool allowsSelfDestruct;
  final VoidCallback onRemove;
  final VoidCallback onSelfDestruct;
  final VoidCallback onToggleSpoiler;

  const _AttachmentTile({
    required this.attachment,
    required this.allowsSelfDestruct,
    required this.onRemove,
    required this.onSelfDestruct,
    required this.onToggleSpoiler,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
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
            if (attachment.selfDestruct.isEnabled)
              Positioned(
                left: AppSpacing.xs,
                bottom: AppSpacing.xs,
                child: _Badge(
                  label: AppStrings.selfDestructSummary(
                    attachment.selfDestruct.seconds,
                    attachment.selfDestruct.isViewOnce,
                  ),
                ),
              )
            else if (attachment.hasSpoiler)
              const Positioned(
                left: AppSpacing.xs,
                bottom: AppSpacing.xs,
                child: _Badge(label: AppStrings.selfDestructSpoilerOn),
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
                onPressed: onRemove,
              ),
            ),
          ],
        ),
        SizedBox(
          width: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (allowsSelfDestruct)
                _TileAction(
                  tooltip: AppStrings.selfDestructTitle,
                  icon: attachment.selfDestruct.isEnabled
                      ? Icons.timer_rounded
                      : Icons.timer_outlined,
                  isOn: attachment.selfDestruct.isEnabled,
                  color: secondary,
                  onPressed: onSelfDestruct,
                ),
              // Telegram refuses a spoiler on media that already destroys
              // itself, so the toggle goes rather than sitting there greyed.
              if (attachment.canSpoiler)
                _TileAction(
                  tooltip: AppStrings.selfDestructSpoiler,
                  icon: attachment.hasSpoiler
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_off_outlined,
                  isOn: attachment.hasSpoiler,
                  color: secondary,
                  onPressed: onToggleSpoiler,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One small toggle under an attachment thumbnail.
class _TileAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool isOn;
  final Color color;
  final VoidCallback onPressed;

  const _TileAction({
    required this.tooltip,
    required this.icon,
    required this.isOn,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 24),
      iconSize: 16,
      // The state is also in the badge on the thumbnail, so colour is not the
      // only thing saying a toggle is on.
      color: isOn ? AppColors.accent : color,
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }
}

/// The little dark chip over a thumbnail, naming what will happen to it.
class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
      child: Text(
        label,
        style: AppTypography.timestamp(color: Colors.white),
      ),
    );
  }
}
