import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/data/conversation_rows.dart';

/// The centred date band between two days of messages.
class ChatDateSeparator extends StatelessWidget {
  final DateTime date;
  const ChatDateSeparator({super.key, required this.date});

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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label(date),
            style: AppTypography.timestamp(color: secondary),
          ),
        ),
      ),
    );
  }

  /// "Today", "Yesterday", or a date that omits the year when it is the
  /// current one.
  static String label(DateTime date, {DateTime? now}) {
    final today = ConversationRows.dayOf(now ?? DateTime.now());
    final day = ConversationRows.dayOf(date);
    final difference = today.difference(day).inDays;

    if (difference == 0) return AppStrings.chatToday;
    if (difference == 1) return AppStrings.chatYesterday;
    if (day.year == today.year) return DateFormat('EEE, MMM d').format(day);
    return DateFormat('MMM d, y').format(day);
  }
}

/// The full-width "Unread messages" band above the first unread message.
/// Drawn as a bar rather than a pill so it doesn't look like a date.
class ChatUnreadBand extends StatelessWidget {
  const ChatUnreadBand({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        color: surface,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Text(
          AppStrings.chatUnreadBand,
          textAlign: TextAlign.center,
          style: AppTypography.timestamp(
            color: AppColors.accent,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
