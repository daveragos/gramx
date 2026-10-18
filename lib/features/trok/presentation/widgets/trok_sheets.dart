import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/app_dialog.dart';
import 'package:gramx/app/widgets/app_sheet.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/trok/domain/trok_models.dart';
import 'package:gramx/features/trok/presentation/trok_chat_screen.dart';
import 'package:gramx/features/trok/presentation/trok_controller.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_mark.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_style.dart';

/// The eye on a post card, beside its "…", as X puts Grok's.
class TrokPostButton extends ConsumerWidget {
  final Post post;
  final Color color;

  const TrokPostButton({super.key, required this.post, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trok said this reader may not use it.
    if (ref.watch(trokControllerProvider.select((s) => s.blocked != null))) {
      return const SizedBox.shrink();
    }
    return Semantics(
      button: true,
      label: AppStrings.trokAskAboutPost,
      child: InkWell(
        onTap: () => TrokPostSheet.show(context, ref, post),
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            0,
            AppSpacing.xxs,
            AppSpacing.xs,
          ),
          child: TrokMark(size: 18, color: color),
        ),
      ),
    );
  }
}

/// What the eye on a post offers.
enum _PostChoice { explain, summarize, translate, factCheck, askOther }

abstract class TrokPostSheet {
  /// Offers Trok's actions on [post]. Each opens Trok over the current tab.
  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    Post post,
  ) async {
    final canTranslate =
        ref.read(trokAllowanceProvider).value?.translate ?? true;
    final choice = await showAppSheet<_PostChoice>(
      context,
      haptic: false,
      title: AppStrings.trokAskAboutPost,
      children: [
        _PostPreview(post: post),
        const AppSheetRow(
          icon: Icons.lightbulb_outline_rounded,
          label: AppStrings.trokPostExplain,
          value: _PostChoice.explain,
        ),
        const AppSheetRow(
          icon: Icons.short_text_rounded,
          label: AppStrings.trokPostSummarize,
          value: _PostChoice.summarize,
        ),
        if (canTranslate)
          const AppSheetRow(
            icon: Icons.translate_rounded,
            label: AppStrings.trokPostTranslate,
            value: _PostChoice.translate,
          ),
        const AppSheetRow(
          icon: Icons.fact_check_outlined,
          label: AppStrings.trokPostFactCheck,
          value: _PostChoice.factCheck,
        ),
        const AppSheetDivider(),
        const AppSheetRow(
          icon: Icons.edit_outlined,
          label: AppStrings.trokPostAskOther,
          value: _PostChoice.askOther,
        ),
      ],
    );
    if (choice == null || !context.mounted) return;

    HapticFeedback.lightImpact();
    final trok = ref.read(trokControllerProvider.notifier);
    final action = switch (choice) {
      _PostChoice.explain => TrokPostAction.explain,
      _PostChoice.summarize => TrokPostAction.summarize,
      _PostChoice.translate => TrokPostAction.translate,
      _PostChoice.factCheck => TrokPostAction.factCheck,
      _PostChoice.askOther => null,
    };
    if (action == null) {
      trok.startNew(draftPost: post);
      context.push(TrokChatScreen.route, extra: true);
    } else {
      trok.askAboutPost(post, action);
      context.push(TrokChatScreen.route);
    }
  }
}

/// The post the sheet is about, small, above its actions.
class _PostPreview extends StatelessWidget {
  final Post post;

  const _PostPreview({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = TrokStyle.secondary(theme);
    final snippet = (post.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: TrokStyle.fill(theme),
        borderRadius: BorderRadius.circular(AppSpacing.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChannelAvatar(
            title: post.channelTitle,
            avatarPath: post.channelAvatarUrl,
            avatarFileId: post.channelAvatarFileId,
            avatarColorHex: post.channelAvatarColor,
            radius: 14,
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.channelTitle,
                  style: AppTypography.actionCount(
                    color: theme.colorScheme.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (snippet.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    snippet,
                    style: AppTypography.actionCount(
                      color: secondary,
                    ).copyWith(height: 1.35),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What History offers.
sealed class _HistoryChoice {
  const _HistoryChoice();
}

class _NewChat extends _HistoryChoice {
  const _NewChat();
}

class _OpenChat extends _HistoryChoice {
  final String id;

  const _OpenChat(this.id);
}

class _DeleteChat extends _HistoryChoice {
  final String id;

  const _DeleteChat(this.id);
}

/// Earlier chats with Trok, newest first, and a way to start another. Trok
/// keeps them, so they are fetched again each time it opens.
abstract class TrokHistorySheet {
  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(trokControllerProvider.notifier);
    unawaited(notifier.refreshHistory());

    final choice = await showAppSheet<_HistoryChoice>(
      context,
      title: AppStrings.trokHistory,
      tall: true,
      children: const [
        AppSheetRow<_HistoryChoice>(
          icon: Icons.add_comment_outlined,
          label: AppStrings.trokNewChat,
          value: _NewChat(),
        ),
        _HistoryRows(),
      ],
    );
    if (!context.mounted) return;

    switch (choice) {
      case null:
        return;
      case _NewChat():
        notifier.startNew();
      case _OpenChat(:final id):
        notifier.open(id);
      case _DeleteChat(:final id):
        final confirmed = await showAppDialog<bool>(
          context,
          title: AppStrings.trokDeleteChatTitle,
          body: AppStrings.trokDeleteChatBody,
          actions: const [
            AppDialogAction(
              label: AppStrings.trokDelete,
              value: true,
              isPrimary: true,
              isDestructive: true,
            ),
            AppDialogAction.cancel(AppStrings.settingsCancel),
          ],
        );
        if (confirmed ?? false) {
          HapticFeedback.mediumImpact();
          notifier.delete(id);
        }
    }
  }
}

/// The chats in History, kept current while the list arrives.
class _HistoryRows extends ConsumerWidget {
  const _HistoryRows();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trok = ref.watch(trokControllerProvider);
    final secondary = TrokStyle.secondary(Theme.of(context));
    final active = trok.active;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSheetDivider(),
        if (trok.conversations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Text(
              AppStrings.trokHistoryEmpty,
              style: AppTypography.body(color: secondary),
            ),
          ),
        for (final c in trok.conversations)
          AppSheetRow<_HistoryChoice>(
            icon: Icons.chat_bubble_outline_rounded,
            label: c.title,
            subtitle: TimeUtils.relativeTime(c.updatedAt),
            value: _OpenChat(c.id),
            isSelected: c.id == trok.activeId,
          ),
        if (active != null && !active.isAnswering) ...[
          const AppSheetDivider(),
          AppSheetRow<_HistoryChoice>(
            icon: Icons.delete_outline_rounded,
            label: AppStrings.trokDeleteChat,
            value: _DeleteChat(active.id),
            isDestructive: true,
          ),
        ],
      ],
    );
  }
}
