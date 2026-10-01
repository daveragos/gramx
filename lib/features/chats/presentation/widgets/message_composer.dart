import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/data/chat_message_mapper.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/domain/message_schedule.dart';
import 'package:gramx/features/compose/data/voice_recorder.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/compose_remote_media.dart';
import 'package:gramx/features/compose/domain/poll_draft.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
import 'package:gramx/features/compose/presentation/widgets/compose_media_kind_sheet.dart';
import 'package:gramx/features/compose/presentation/widgets/compose_sticker_sheet.dart';
import 'package:gramx/features/compose/presentation/widgets/composer_tools.dart';
import 'package:gramx/features/compose/presentation/widgets/poll_composer_sheet.dart';
import 'package:gramx/features/compose/presentation/widgets/self_destruct_sheet.dart';
import 'package:gramx/features/chats/presentation/widgets/voice_record_bar.dart';

/// The message input bar at the bottom of a conversation. Shares the
/// attachment model and picker with the post compose screen.
class MessageComposer extends ConsumerStatefulWidget {
  /// The message being replied to, shown as a quote above the field.
  final ChatMessage? replyTo;
  final VoidCallback? onCancelReply;

  /// Sends the message. Returns whether it succeeded.
  final Future<bool> Function(
    String text,
    List<ComposeAttachment> attachments,
    MessageSchedule schedule,
  )
  onSend;

  /// Asks when to send. Null disables the long press on the send button.
  final Future<MessageSchedule?> Function()? onPickSchedule;

  /// Called on every keystroke. The screen throttles the typing signal with
  /// `TypingSignal`.
  final ValueChanged<String>? onChanged;

  /// The chat's TDLib draft, restored into the field.
  final String? initialText;

  /// Called with the unsent text on dispose, to save it as the chat's draft.
  final ValueChanged<String>? onDraftChanged;

  /// Sends a poll. Null where Telegram doesn't allow polls, hiding the option.
  final Future<bool> Function(PollDraft draft)? onSendPoll;

  /// Whether attachments may self-destruct (one-to-one chats only).
  final bool allowsSelfDestruct;

  /// Whether this chat takes voice messages. False hides the microphone.
  final bool allowsVoiceNotes;

  /// Whether this chat takes round video messages.
  final bool allowsVideoNotes;

  /// Whether this chat takes files. Hides the "File" row in the attach sheet.
  final bool allowsDocuments;

  /// Records a round video message and returns it.
  final Future<ComposeAttachment?> Function()? onRecordVideoNote;

  /// Sends the device's current location.
  final Future<bool> Function()? onSendLocation;

  /// Sends one of the account's Telegram contacts.
  final Future<bool> Function()? onSendContact;

  /// Sends a sticker or GIF as soon as it is picked (see [ComposeRemoteMedia]).
  /// Null hides the button in chats that forbid them.
  final Future<bool> Function(ComposeRemoteMedia media)? onSendRemote;

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
    this.onSendRemote,
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

  /// The active voice recorder, or null. Created per recording so the platform
  /// audio session is released between recordings.
  VoiceRecorder? _recorder;

  /// Redraws the timer and waveform while recording.
  Timer? _recordTicker;

  /// Where the finger went down for a press-and-hold recording. Null for a
  /// tapped recording, which ends with the record bar's buttons.
  Offset? _holdOrigin;

  /// How far left a held recording must be dragged to cancel it.
  static const double _slideToCancel = 120;

  /// Whether the user expanded the folded tools while typing. Reset when the
  /// field empties. See [CollapsibleComposerTools].
  bool _toolsExpanded = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialText;
    if (draft != null && draft.isNotEmpty) _controller.text = draft;
  }

  @override
  void dispose() {
    // Saved once on dispose since `SetChatDraftMessage` is a network request.
    widget.onDraftChanged?.call(_controller.text);
    _recordTicker?.cancel();
    // Leaving mid-recording discards the recording.
    unawaited(_recorder?.cancel().then((_) => _recorder?.dispose()));
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _isRecording => _recorder != null;

  /// Shows the microphone instead of send when there is nothing to send.
  bool get _showMicrophone =>
      widget.allowsVoiceNotes && !_canSend && !_isSending;

  Future<void> _startRecording() async {
    if (_isRecording) return;

    final wasHeld = _holdOrigin != null;
    final recorder = VoiceRecorder();
    final failure = await recorder.start();
    if (!mounted) {
      await recorder.dispose();
      return;
    }

    // The hold ended before recording started, usually because the first one
    // opened the microphone permission prompt.
    if (failure == null && wasHeld && _holdOrigin == null) {
      await recorder.cancel();
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
      // Stops at the maximum length and keeps what was recorded.
      if (recorder.elapsed >= VoiceRecorder.maxDuration) {
        _finishRecording();
        return;
      }
      setState(() {});
    });
  }

  void _startHeldRecording(LongPressStartDetails details) {
    _holdOrigin = details.globalPosition;
    _startRecording();
  }

  /// Ends a held recording. Driven by a [Listener] around the composer, since
  /// the record bar replaces the button once recording starts.
  void _releaseHeldRecording(Offset position, {bool cancelled = false}) {
    final origin = _holdOrigin;
    if (origin == null) return;
    _holdOrigin = null;
    if (!_isRecording) return;

    if (cancelled || origin.dx - position.dx > _slideToCancel) {
      HapticFeedback.lightImpact();
      _cancelRecording();
    } else {
      _finishRecording();
    }
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

    // Sent right away: a voice message can't join an album or take a caption.
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
      includeVideoNote:
          widget.allowsVideoNotes && widget.onRecordVideoNote != null,
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

  /// Picks a sticker or a GIF and sends it on its own.
  Future<void> _pickRemote() async {
    final send = widget.onSendRemote;
    if (send == null) return;

    final media = await ComposeStickerSheet.show(
      context,
      initialKind: ComposeRemoteKind.sticker,
    );
    if (media == null || !mounted) return;

    setState(() => _isSending = true);
    final sent = await send(media);
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

  /// Runs a screen-supplied send callback and reports a failure.
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

  /// Sets one attachment's self-destruct timer. Telegram stores the timer per
  /// media item, not per message.
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

  /// Asks when to send, then schedules. Bound to long press on send.
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
    // Cleared before the await so the next message can be typed right away.
    _controller.clear();
    _attachments.clear();
    // So dispose doesn't save the sent text back as a draft.
    widget.onDraftChanged?.call('');

    final sent = await widget.onSend(text, attachments, schedule);
    if (!mounted) return;
    setState(() => _isSending = false);

    if (!sent) {
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

    return Listener(
      onPointerUp: (event) => _releaseHeldRecording(event.position),
      onPointerCancel: (event) =>
          _releaseHeldRecording(event.position, cancelled: true),
      child: DecoratedBox(
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
                      // Folded into a chevron while the field has text.
                      CollapsibleComposerTools(
                        collapsed: composerToolsFolded(
                          hasText: _controller.text.isNotEmpty,
                          expandedByHand: _toolsExpanded,
                          toolCount: widget.onSendRemote == null ? 1 : 2,
                        ),
                        onExpand: () => setState(() => _toolsExpanded = true),
                        tools: [
                          IconButton(
                            tooltip: AppStrings.chatAttach,
                            icon: const Icon(
                              Icons.add_circle_outline_rounded,
                              color: AppColors.accent,
                            ),
                            onPressed: _attach,
                          ),
                          if (widget.onSendRemote != null)
                            IconButton(
                              tooltip: AppStrings.chatStickers,
                              icon: const Icon(
                                Icons.emoji_emotions_outlined,
                                color: AppColors.accent,
                              ),
                              onPressed: _isSending ? null : _pickRemote,
                            ),
                        ],
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
                            // Unfolds the tools again once the field is empty.
                            setState(() {
                              if (value.isEmpty) _toolsExpanded = false;
                            });
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
                        // Tap to record with the bar's buttons, or hold and
                        // release to send. No tooltip, since a tooltip would
                        // take the long press.
                        Semantics(
                          button: true,
                          label: AppStrings.voiceRecord,
                          onTap: _startRecording,
                          excludeSemantics: true,
                          child: GestureDetector(
                            onLongPressStart: _startHeldRecording,
                            child: IconButton(
                              icon: const Icon(
                                Icons.mic_none_rounded,
                                color: AppColors.accent,
                              ),
                              onPressed: _startRecording,
                            ),
                          ),
                        )
                      else
                        _SendButton(
                          isEnabled: _canSend,
                          isSending: _isSending,
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _send();
                          },
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
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool isEnabled;
  final bool isSending;
  final VoidCallback onPressed;

  /// Opens the "send later" sheet. Null when scheduling isn't offered.
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
      // IconButton has no long press of its own.
      onLongPress: isEnabled ? onLongPress : null,
      child: IconButton(
        tooltip: onLongPress == null
            ? AppStrings.chatSend
            : AppStrings.chatSendOrSchedule,
        // Disabled rather than hidden so the button doesn't move while typing.
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

/// The message being replied to, above the field, drawn like the reply line
/// in a bubble.
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
    // Uses the same mapping as the sent reply's quote.
    final author = ChatMessageMapper.replyAuthorOf(message);

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
                  author == null
                      ? AppStrings.chatReplyingTo
                      : AppStrings.chatReplyingToName(author),
                  style: AppTypography.timestamp(
                    color: AppColors.accent,
                  ).copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  ChatMessageMapper.replyPreviewOf(message) ?? '',
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

/// Thumbnails of pending attachments, each with its own self-destruct and
/// spoiler toggles since both are set per file.
class _AttachmentStrip extends StatelessWidget {
  final List<ComposeAttachment> attachments;

  /// Whether this chat allows self-destructing media. False hides the timer.
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
              // Telegram doesn't allow a spoiler on self-destructing media.
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
      // Material pads IconButtons to a 48-point tap target regardless of
      // constraints, which overflows the 64-point tile.
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 24),
      iconSize: 16,
      // The thumbnail badge also shows the state, so it isn't colour alone.
      color: isOn ? AppColors.accent : color,
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }
}

/// A small chip on a thumbnail showing its self-destruct or spoiler setting.
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
      child: Text(label, style: AppTypography.timestamp(color: Colors.white)),
    );
  }
}
