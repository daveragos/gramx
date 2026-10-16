import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';

/// Colours Trok's surfaces share, set off from the background in every theme.
abstract class TrokStyle {
  /// Behind the composer, the reader's questions and the cards.
  static Color fill(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Color.alphaBlend(
      theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.09 : 0.06),
      theme.scaffoldBackgroundColor,
    );
  }

  static Color border(ThemeData theme) => theme.brightness == Brightness.dark
      ? AppColors.darkBorder
      : AppColors.lightBorder;

  static Color secondary(ThemeData theme) => theme.brightness == Brightness.dark
      ? AppColors.darkTextSecondary
      : AppColors.lightTextSecondary;

  /// Questions, answers and the space between them.
  static const double gutter = 16;
  static const double bubbleRadius = 20;
}
