import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gramx/core/text/emoji_presentation.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';

/// The reaction chips under a message. Tapping one toggles the user's own
/// reaction, which is shown tinted.
class MessageReactionsRow extends StatelessWidget {
  final Map<String, int> reactions;
  final Set<String> chosen;
  final void Function(String emoji)? onTap;

  const MessageReactionsRow({
    super.key,
    required this.reactions,
    required this.chosen,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final surface = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurfaceVariant;

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final entry in reactions.entries)
          _Chip(
            emoji: entry.key,
            count: entry.value,
            isChosen: chosen.contains(entry.key),
            surface: surface,
            textColor: secondary,
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onTap!(entry.key);
                  },
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool isChosen;
  final Color surface;
  final Color textColor;
  final VoidCallback? onTap;

  const _Chip({
    required this.emoji,
    required this.count,
    required this.isChosen,
    required this.surface,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      // The tint alone marks the user's reaction, so the label says it too.
      label: isChosen ? '$emoji $count, your reaction' : '$emoji $count',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isChosen ? AppColors.accent.withValues(alpha: 0.2) : surface,
            border: Border.all(
              color: isChosen ? AppColors.accent : Colors.transparent,
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emojiForDisplay(emoji), style: emojiStyle(fontSize: 13)),
              if (count > 1) ...[
                const SizedBox(width: 4),
                Text(
                  count.toString(),
                  style: AppTypography.timestamp(
                    color: isChosen ? AppColors.accent : textColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
