import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/compose/data/compose_repository.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/compose_draft.dart';
import 'package:gramx/features/compose/domain/compose_remote_media.dart';
import 'package:gramx/features/compose/domain/compose_target.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
import 'package:gramx/features/compose/presentation/post_progress_provider.dart';
import 'package:gramx/features/compose/presentation/widgets/compose_attachment_strip.dart';
import 'package:gramx/features/compose/presentation/widgets/poll_composer_sheet.dart';
import 'package:gramx/features/compose/presentation/widgets/compose_remote_preview.dart';
import 'package:gramx/features/compose/presentation/widgets/compose_sticker_sheet.dart';
import 'package:gramx/features/compose/presentation/widgets/compose_target_sheet.dart';
import 'package:gramx/app/widgets/app_dialog.dart';
import 'package:gramx/app/widgets/pill_button.dart';

/// Writing a post, with a pill that picks the destination chat. The draft
/// lives in this State, so closing the screen discards it.
class ComposeScreen extends ConsumerStatefulWidget {
  /// Text shared into gramX from another app, or null to start empty.
  final String? initialText;

  const ComposeScreen({super.key, this.initialText});

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// The user's pick, or null for the default, which is resolved on each
  /// build so a cache that fills late still gets one.
  ComposeTarget? _chosenTarget;

  List<ComposeAttachment> _attachments = const [];

  /// A sticker or GIF from the account's collection. Exclusive with
  /// [_attachments], since Telegram can't put either in an album.
  ComposeRemoteMedia? _remote;

  bool _isSending = false;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();

    // Seeded before the listener is attached, so it isn't a keystroke.
    final seed = widget.initialText;
    if (seed != null && seed.isNotEmpty) {
      _controller.text = seed;
      _controller.selection = TextSelection.collapsed(offset: seed.length);
    }

    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  ComposeDraft _draft(
    List<ComposeTarget> targets, {
    ComposeLengthLimits limits = ComposeLengthLimits.free,
  }) => ComposeDraft(
    target: _chosenTarget ?? (targets.isEmpty ? null : targets.first),
    text: _controller.text,
    attachments: _attachments,
    remote: _remote,
    isSending: _isSending,
    limits: limits,
  );

  ComposeDraft _currentDraft() => _draft(
    ref.read(composeTargetsProvider),
    limits:
        ref.read(composeLengthLimitsProvider).value ?? ComposeLengthLimits.free,
  );

  Future<void> _pickTarget(ComposeTarget? current) async {
    // Dismiss the keyboard first, or the sheet opens behind it.
    _focusNode.unfocus();
    final picked = await ComposeTargetSheet.show(context, selected: current);
    if (picked == null || !mounted) return;
    setState(() => _chosenTarget = picked);
  }

  Future<void> _attach(ComposeMediaKind kind) async {
    final draft = _currentDraft();
    if (!draft.canAttachMore) {
      _say(AppStrings.composeAttachmentLimit(ComposeLimits.maxAttachments));
      return;
    }
    if (_isPicking) return;

    setState(() => _isPicking = true);
    try {
      final picker = ref.read(composeMediaPickerProvider);
      final picked = kind == ComposeMediaKind.photo
          ? await picker.pickPhoto()
          : await picker.pickVideo();
      if (picked == null || !mounted) return;

      // Telegram rejects an unsuitable photo only after the upload, with one
      // vague error, so it is checked here first.
      final rejection = ComposeLimits.photoRejection(picked);
      if (rejection != null) {
        _say(_rejectionMessage(rejection));
        return;
      }

      setState(() {
        _attachments = [..._attachments, picked];
        _remote = null;
      });
    } catch (e) {
      debugPrint('[Compose] Picking media failed: $e');
      if (mounted) _say(AppStrings.composePickFailed);
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  static String _rejectionMessage(ComposePhotoRejection rejection) =>
      switch (rejection) {
        ComposePhotoRejection.tooLarge => AppStrings.composePhotoTooLarge(
          ComposeLimits.maxPhotoBytes ~/ (1024 * 1024),
        ),
        ComposePhotoRejection.tooManyPixels =>
          AppStrings.composePhotoTooManyPixels(
            ComposeLimits.maxPhotoDimensionTotal,
          ),
        ComposePhotoRejection.tooWide => AppStrings.composePhotoTooWide(
          ComposeLimits.maxPhotoAspectRatio,
        ),
      };

  Future<void> _pickRemote(ComposeRemoteKind kind) async {
    _focusNode.unfocus();
    final picked = await ComposeStickerSheet.show(context, initialKind: kind);
    if (picked == null || !mounted) return;

    // A sticker or GIF is a message on its own, so it replaces the selection.
    setState(() {
      _remote = picked;
      _attachments = const [];
    });
  }

  void _removeRemote() => setState(() => _remote = null);

  void _removeAttachment(int index) {
    setState(() {
      final next = [..._attachments]..removeAt(index);
      _attachments = next;
    });
  }

  /// Writes and posts a poll on its own; the composer stays open.
  Future<void> _composePoll(ComposeTarget target) async {
    _focusNode.unfocus();

    final poll = await PollComposerSheet.show(
      context,
      // Telegram refuses a poll with named voters in a channel.
      allowsPublicVotes: target.kind != ComposeTargetKind.channel,
    );
    if (poll == null || !mounted) return;

    final label = composeTargetLabel(target);
    final result = await ref
        .read(composeRepositoryProvider)
        .sendPoll(chatId: target.chatId, draft: poll);
    if (!mounted) return;

    if (!result.accepted) {
      _say(AppStrings.pollComposeSendFailed);
      return;
    }
    _say(AppStrings.composeSent(label));
  }

  Future<void> _post(ComposeDraft draft) async {
    final target = draft.target;
    if (target == null || !draft.canPost) return;

    HapticFeedback.lightImpact();
    // Captured before the await, since the screen closes on success.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final label = composeTargetLabel(target);

    setState(() => _isSending = true);
    final result = await ref
        .read(composeRepositoryProvider)
        .send(
          chatId: target.chatId,
          text: draft.trimmedText,
          attachments: draft.attachments,
          remote: draft.remote,
        );

    if (!mounted) return;
    if (!result.accepted) {
      setState(() => _isSending = false);
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.composeFailed(label))),
      );
      return;
    }

    // TDLib accepts the message before the files upload, so the progress bar
    // over the timeline reports the actual send.
    ref
        .read(postSendTrackerProvider.notifier)
        .track(result, targetLabel: label);

    navigator.pop();
  }

  Future<void> _close(ComposeDraft draft) async {
    _focusNode.unfocus();

    if (draft.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final discard = await showAppDialog<bool>(
      context,
      title: AppStrings.composeDiscardTitle,
      body: AppStrings.composeDiscardBody,
      actions: const [
        AppDialogAction(
          label: AppStrings.composeDiscardConfirm,
          value: true,
          isPrimary: true,
          isDestructive: true,
        ),
        AppDialogAction.cancel(AppStrings.composeDiscardCancel),
      ],
    );

    if (discard == true && mounted) Navigator.of(context).pop();
  }

  void _say(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final targets = ref.watch(composeTargetsProvider);
    // Free-tier limits until TDLib reports this account's own.
    final limits =
        ref.watch(composeLengthLimitsProvider).value ??
        ComposeLengthLimits.free;
    final draft = _draft(targets, limits: limits);
    final account = ref.watch(activeAccountProvider).value;

    return PopScope(
      // The back gesture must not discard a written draft without asking.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(draft);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _ComposeHeader(
                canPost: draft.canPost,
                isSending: draft.isSending,
                onClose: () => _close(draft),
                onPost: () => _post(draft),
              ),
              Expanded(
                child: draft.target == null
                    ? _NowhereToPost(secondary: secondary, primary: primary)
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.postPadding,
                                AppSpacing.sm,
                                AppSpacing.postPadding,
                                0,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ChannelAvatar(
                                    title: account?.displayName ?? 'User',
                                    avatarPath: account?.avatarPath,
                                  ),
                                  const SizedBox(width: AppSpacing.avatarGap),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _TargetPill(
                                          target: draft.target!,
                                          onTap: () =>
                                              _pickTarget(draft.target),
                                        ),
                                        _ComposeField(
                                          controller: _controller,
                                          focusNode: _focusNode,
                                          enabled: !draft.isSending,
                                          primary: primary,
                                          secondary: secondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (draft.hasAttachments) ...[
                              const SizedBox(height: AppSpacing.md),
                              ComposeAttachmentStrip(
                                attachments: draft.attachments,
                                onRemove: _removeAttachment,
                              ),
                            ],
                            if (draft.remote != null) ...[
                              const SizedBox(height: AppSpacing.md),
                              ComposeRemotePreview(
                                media: draft.remote!,
                                onRemove: _removeRemote,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.xxl),
                          ],
                        ),
                      ),
              ),
              if (draft.target != null)
                _ComposeFooter(
                  draft: draft,
                  borderColor: borderColor,
                  secondary: secondary,
                  isPicking: _isPicking,
                  onChangeTarget: () => _pickTarget(draft.target),
                  onAddPhoto: () => _attach(ComposeMediaKind.photo),
                  onAddVideo: () => _attach(ComposeMediaKind.video),
                  onAddSticker: () => _pickRemote(ComposeRemoteKind.sticker),
                  onAddGif: () => _pickRemote(ComposeRemoteKind.animation),
                  // Telegram only takes polls in channels and groups.
                  onAddPoll: draft.target!.allowsPolls
                      ? () => _composePoll(draft.target!)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposeHeader extends StatelessWidget {
  final bool canPost;
  final bool isSending;
  final VoidCallback onClose;
  final VoidCallback onPost;

  const _ComposeHeader({
    required this.canPost,
    required this.isSending,
    required this.onClose,
    required this.onPost,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            color: primary,
            tooltip: AppStrings.composeClose,
            onPressed: onClose,
          ),
          const Spacer(),
          PillButton(
            label: AppStrings.composePost,
            compact: true,
            isBusy: isSending,
            onPressed: canPost ? onPost : null,
          ),
        ],
      ),
    );
  }
}

class _TargetPill extends StatelessWidget {
  final ComposeTarget target;
  final VoidCallback onTap;

  const _TargetPill({required this.target, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.a11yComposeChangeTarget,
      value: composeTargetLabel(target),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.xl),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.accent),
              borderRadius: BorderRadius.circular(AppSpacing.xl),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    composeTargetLabel(target),
                    style: AppTypography.button(color: AppColors.accent),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposeField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final Color primary;
  final Color secondary;

  const _ComposeField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      autofocus: true,
      maxLines: null,
      // No maxLength, so the counter can show how far over the limit it is.
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      style: AppTypography.bodyLarge(color: primary),
      decoration: InputDecoration(
        hintText: AppStrings.composeHint,
        hintStyle: AppTypography.bodyLarge(color: secondary),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      ),
    );
  }
}

/// The two rows under the keyboard: where this is going, and what can be added.
class _ComposeFooter extends StatelessWidget {
  final ComposeDraft draft;
  final Color borderColor;
  final Color secondary;
  final bool isPicking;
  final VoidCallback onChangeTarget;
  final VoidCallback onAddPhoto;
  final VoidCallback onAddVideo;
  final VoidCallback onAddSticker;
  final VoidCallback onAddGif;

  /// Null where Telegram won't take a poll, which hides the button.
  final VoidCallback? onAddPoll;

  const _ComposeFooter({
    required this.draft,
    required this.borderColor,
    required this.secondary,
    required this.isPicking,
    required this.onChangeTarget,
    required this.onAddPhoto,
    required this.onAddVideo,
    required this.onAddSticker,
    required this.onAddGif,
    required this.onAddPoll,
  });

  @override
  Widget build(BuildContext context) {
    final target = draft.target!;
    final busy = isPicking || draft.isSending;
    final canAttach = draft.canAttachMore && !busy;
    // One sticker or GIF per post, never alongside uploaded files.
    final canPickRemote =
        draft.remote == null && !draft.hasAttachments && !busy;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Notes explaining why Post is disabled. Media switches the draft to
        // the shorter caption limit.
        if (draft.isCaptioned && draft.isOverLimit)
          _FooterNote(
            message: AppStrings.composeCaptionLimit(draft.characterLimit),
          ),
        // `inputMessageSticker` has no caption field.
        if (draft.stickerBlocksText)
          const _FooterNote(message: AppStrings.composeStickerTakesNoCaption),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: borderColor, width: 0.5)),
          ),
          child: InkWell(
            onTap: onChangeTarget,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.campaign_outlined,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      AppStrings.composePostingTo(composeTargetLabel(target)),
                      style: AppTypography.actionCount(color: AppColors.accent),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: borderColor, width: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image_outlined),
                  color: AppColors.accent,
                  disabledColor: secondary,
                  tooltip: AppStrings.composeAddPhoto,
                  onPressed: canAttach ? onAddPhoto : null,
                ),
                IconButton(
                  icon: const Icon(Icons.videocam_outlined),
                  color: AppColors.accent,
                  disabledColor: secondary,
                  tooltip: AppStrings.composeAddVideo,
                  onPressed: canAttach ? onAddVideo : null,
                ),
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  color: AppColors.accent,
                  disabledColor: secondary,
                  tooltip: AppStrings.composeAddSticker,
                  onPressed: canPickRemote ? onAddSticker : null,
                ),
                IconButton(
                  icon: const Icon(Icons.gif_box_outlined),
                  color: AppColors.accent,
                  disabledColor: secondary,
                  tooltip: AppStrings.composeAddGif,
                  onPressed: canPickRemote ? onAddGif : null,
                ),
                if (onAddPoll != null)
                  IconButton(
                    icon: const Icon(Icons.poll_outlined),
                    color: AppColors.accent,
                    tooltip: AppStrings.pollComposeTitle,
                    onPressed: onAddPoll,
                  ),
                const Spacer(),
                _CharacterCounter(draft: draft, secondary: secondary),
                const SizedBox(width: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A red line under the toolbar naming why the post will not send.
class _FooterNote extends StatelessWidget {
  final String message;

  const _FooterNote({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        message,
        style: AppTypography.actionCount(color: AppColors.error),
      ),
    );
  }
}

/// A ring that fills as the draft grows and shows a number near the limit.
class _CharacterCounter extends StatelessWidget {
  /// How close to the limit the number appears.
  static const int _showNumberWithin = 20;

  final ComposeDraft draft;
  final Color secondary;

  const _CharacterCounter({required this.draft, required this.secondary});

  @override
  Widget build(BuildContext context) {
    final limit = draft.characterLimit;
    final used = draft.text.length;
    final remaining = draft.remaining;
    final progress = limit == 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);

    final color = draft.isOverLimit
        ? AppColors.error
        : (remaining <= _showNumberWithin
              ? AppColors.warning
              : AppColors.accent);

    final showNumber = remaining <= _showNumberWithin;

    return Semantics(
      // The ring needs a label for screen readers, especially when red.
      label: AppStrings.a11yComposeCharacters,
      value: '$remaining',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showNumber) ...[
            Text(
              remaining.toString(),
              style: AppTypography.actionCount(color: color),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2.5,
              backgroundColor: secondary.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when this account can post nowhere. Only reachable in a race.
class _NowhereToPost extends StatelessWidget {
  final Color primary;
  final Color secondary;

  const _NowhereToPost({required this.primary, required this.secondary});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.composeTargetsEmpty,
              style: AppTypography.heading(color: primary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.composeTargetsEmptyBody,
              style: AppTypography.body(color: secondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
