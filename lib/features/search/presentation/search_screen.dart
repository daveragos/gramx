import 'package:flutter/material.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surfaceColor = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final primaryColor = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const SizedBox(width: AppSpacing.md),
              Icon(Icons.search, color: secondaryColor, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('Search gramX', style: AppTypography.body(color: secondaryColor)),
            ],
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, color: secondaryColor, size: 64),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Search',
              style: AppTypography.heading(color: primaryColor),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Search channels, posts, and hashtags.\nComing in Milestone 5.',
              style: AppTypography.body(color: secondaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
