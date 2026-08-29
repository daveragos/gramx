import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/domain/chat_filter.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';

/// Extra rows on the filter menu that are not filters.
///
/// divider. Modelled as their own type rather than as extra [ChatFilter]
/// values, because a filter and an action behave differently: one changes what
/// the list shows and stays selected, the other happens once.
enum ChatMenuAction { settings, markAllRead }

/// The "All ⌄" pill in the header, and the menu it opens.
///
/// Every row here does something — the five filters change the list, Settings
/// opens Settings, and "Mark all as read" acknowledges every unread
/// conversation. That is the bar for shipping a control at all.
class ChatFilterMenu extends ConsumerWidget {
  final void Function(ChatMenuAction action) onAction;

  const ChatFilterMenu({super.key, required this.onAction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final active = ref.watch(chatFilterProvider);

    return PopupMenuButton<Object>(
      tooltip: AppStrings.messagesFilterTooltip,
      position: PopupMenuPosition.under,
      color: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        side: BorderSide(color: border, width: 0.5),
      ),
      onSelected: (value) {
        HapticFeedback.lightImpact();
        if (value is ChatFilter) {
          ref.read(chatFilterProvider.notifier).select(value);
        } else if (value is ChatMenuAction) {
          onAction(value);
        }
      },
      itemBuilder: (context) => [
        for (final filter in ChatFilter.values)
          PopupMenuItem<Object>(
            value: filter,
            child: _MenuRow(
              icon: _iconFor(filter),
              label: filter.label,
              isSelected: filter == active,
              color: primary,
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<Object>(
          value: ChatMenuAction.settings,
          child: _MenuRow(
            icon: Icons.settings_outlined,
            label: AppStrings.messagesSettings,
            isSelected: false,
            color: primary,
          ),
        ),
        PopupMenuItem<Object>(
          value: ChatMenuAction.markAllRead,
          child: _MenuRow(
            icon: Icons.done_all_rounded,
            label: AppStrings.messagesMarkAllRead,
            isSelected: false,
            color: primary,
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(20),
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

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color color;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(label, style: AppTypography.body(color: color)),
        ),
        // The tick, not a highlight: the selected filter has to be readable
        // without relying on a background tint that the three themes render
        // differently.
        if (isSelected) Icon(Icons.check_rounded, color: color, size: 20),
      ],
    );
  }
}
