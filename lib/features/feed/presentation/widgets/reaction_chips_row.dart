import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gramx/core/text/emoji_presentation.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/time/time_utils.dart';

/// A post's reaction chips (emoji and count), drawn quietly so they don't
/// compete with the action bar. Only the user's own reaction gets the accent;
/// [compact] shrinks them for the feed.
class ReactionChipsRow extends StatelessWidget {
  final Map<String, int> reactions;
  final Set<String> chosen;
  final ValueChanged<String> onTap;
  final bool compact;

  const ReactionChipsRow({
    super.key,
    required this.reactions,
    required this.chosen,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final fill = isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant;

    // Swallows taps so a missed chip doesn't open the post underneath.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (final entry in reactions.entries)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _Chip(
                  emoji: entry.key,
                  count: entry.value,
                  isChosen: chosen.contains(entry.key),
                  fill: fill,
                  textColor: secondary,
                  compact: compact,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTap(entry.key);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool isChosen;
  final Color fill;
  final Color textColor;
  final bool compact;
  final VoidCallback onTap;

  const _Chip({
    required this.emoji,
    required this.count,
    required this.isChosen,
    required this.fill,
    required this.textColor,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);

    return Semantics(
      button: true,
      selected: isChosen,
      label: '$emoji ${TimeUtils.formatCount(count)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 9,
            vertical: compact ? 2 : 4,
          ),
          decoration: BoxDecoration(
            color: isChosen ? AppColors.accent.withValues(alpha: 0.16) : fill,
            borderRadius: radius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emojiForDisplay(emoji),
                style: emojiStyle(fontSize: compact ? 12 : 14),
              ),
              const SizedBox(width: 4),
              Text(
                TimeUtils.formatCount(count),
                style:
                    AppTypography.actionCount(
                      color: isChosen ? AppColors.accent : textColor,
                    ).copyWith(
                      fontSize: compact ? 12 : 13,
                      fontWeight: isChosen ? FontWeight.w700 : FontWeight.w400,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
