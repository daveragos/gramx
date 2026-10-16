import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/trok/presentation/trok_controller.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_style.dart';

/// Where questions are typed. While Trok answers, send turns into stop.
class TrokComposer extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const TrokComposer({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  @override
  ConsumerState<TrokComposer> createState() => _TrokComposerState();
}

class _TrokComposerState extends ConsumerState<TrokComposer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(TrokComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() => setState(() {});

  void _send() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    ref.read(trokControllerProvider.notifier).ask(text);
    widget.controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = TrokStyle.secondary(theme);
    final trok = ref.watch(trokControllerProvider);
    final notifier = ref.read(trokControllerProvider.notifier);
    final draftPost = trok.draftPost;
    final hasText = widget.controller.text.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.xs + 2),
      decoration: BoxDecoration(
        color: TrokStyle.fill(theme),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: TrokStyle.border(theme), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (draftPost != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.xxs,
                AppSpacing.xs,
                AppSpacing.xs,
              ),
              child: _DraftPostChip(
                post: draftPost,
                onRemove: () => notifier.setDraftPost(null),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              minLines: 1,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              style: AppTypography.bodyLarge(
                color: theme.colorScheme.onSurface,
              ).copyWith(fontWeight: FontWeight.w400),
              decoration: InputDecoration(
                hintText: trok.active == null
                    ? AppStrings.trokComposerHint
                    : AppStrings.trokComposerHintFollowUp,
                hintStyle: AppTypography.bodyLarge(
                  color: secondary,
                ).copyWith(fontWeight: FontWeight.w400),
                filled: false,
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
          Row(
            children: [
              _ThinkChip(
                selected: trok.think,
                onTap: () {
                  HapticFeedback.selectionClick();
                  notifier.setThink(!trok.think);
                },
              ),
              const Spacer(),
              _SendButton(
                answering: trok.isAnswering,
                enabled: hasText,
                onSend: _send,
                onStop: () {
                  HapticFeedback.lightImpact();
                  notifier.stop();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asks Trok to take longer over the next question.
class _ThinkChip extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _ThinkChip({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? AppColors.accent : TrokStyle.secondary(theme);

    return Tooltip(
      message: AppStrings.trokThinkTooltip,
      child: Semantics(
        toggled: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm - 1,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
              border: Border.all(
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.5)
                    : TrokStyle.border(theme),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected
                      ? Icons.lightbulb_rounded
                      : Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  AppStrings.trokThink,
                  style: AppTypography.actionCount(
                    color: color,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool answering;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const _SendButton({
    required this.answering,
    required this.enabled,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final active = answering || enabled;
    final background = answering
        ? onSurface
        : enabled
        ? AppColors.accent
        : onSurface.withValues(alpha: 0.12);
    final foreground = answering
        ? theme.scaffoldBackgroundColor
        : enabled
        ? Colors.white
        : onSurface.withValues(alpha: 0.38);

    return Tooltip(
      message: answering ? AppStrings.trokStop : AppStrings.trokSend,
      child: Semantics(
        button: true,
        enabled: active,
        child: GestureDetector(
          onTap: answering ? onStop : (enabled ? onSend : null),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                answering ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                key: ValueKey(answering),
                size: answering ? 20 : 22,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The post the next question is about, with a way to drop it.
class _DraftPostChip extends StatelessWidget {
  final Post post;
  final VoidCallback onRemove;

  const _DraftPostChip({required this.post, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = TrokStyle.secondary(theme);
    final snippet = (post.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.xxs,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(color: TrokStyle.border(theme)),
      ),
      child: Row(
        children: [
          ChannelAvatar(
            title: post.channelTitle,
            avatarPath: post.channelAvatarUrl,
            avatarFileId: post.channelAvatarFileId,
            avatarColorHex: post.channelAvatarColor,
            radius: 14,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.trokAboutPost(post.channelTitle),
                  style: AppTypography.actionCount(
                    color: theme.colorScheme.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (snippet.isNotEmpty)
                  Text(
                    snippet,
                    style: AppTypography.actionCount(color: secondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: AppStrings.trokRemovePost,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 18, color: secondary),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
