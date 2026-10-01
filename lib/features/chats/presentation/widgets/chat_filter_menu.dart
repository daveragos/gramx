import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/app_sheet.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/domain/chat_filter.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';

/// One-off actions listed under the filters in the filter menu.
enum ChatMenuAction { settings, markAllRead }

/// The filter pill in the chat list header and the sheet it opens, with the
/// filters followed by [ChatMenuAction] rows.
class ChatFilterMenu extends ConsumerWidget {
  final void Function(ChatMenuAction action) onAction;

  const ChatFilterMenu({super.key, required this.onAction});

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final active = ref.read(chatFilterProvider);
    final choice = await showAppSheet<Object>(
      context,
      haptic: false,
      children: [
        for (final filter in ChatFilter.values)
          AppSheetRow<Object>(
            icon: _iconFor(filter),
            label: filter.label,
            value: filter,
            isSelected: filter == active,
          ),
        const AppSheetDivider(),
        const AppSheetRow<Object>(
          icon: Icons.settings_outlined,
          label: AppStrings.messagesSettings,
          value: ChatMenuAction.settings,
        ),
        const AppSheetRow<Object>(
          icon: Icons.done_all_rounded,
          label: AppStrings.messagesMarkAllRead,
          value: ChatMenuAction.markAllRead,
        ),
      ],
    );
    if (choice == null) return;

    HapticFeedback.lightImpact();
    if (choice is ChatFilter) {
      ref.read(chatFilterProvider.notifier).select(choice);
    } else if (choice is ChatMenuAction) {
      onAction(choice);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final active = ref.watch(chatFilterProvider);

    return Semantics(
      button: true,
      label: AppStrings.messagesFilterTooltip,
      child: InkWell(
        onTap: () => _open(context, ref),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(active.label, style: AppTypography.button(color: primary)),
              const SizedBox(width: AppSpacing.xxs),
              Icon(Icons.keyboard_arrow_down_rounded, color: primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(ChatFilter filter) => switch (filter) {
    ChatFilter.all => Icons.chat_bubble_outline_rounded,
    ChatFilter.unread => Icons.mark_chat_unread_outlined,
    ChatFilter.direct => Icons.person_outline_rounded,
    ChatFilter.groups => Icons.group_outlined,
    ChatFilter.bots => Icons.smart_toy_outlined,
  };
}
