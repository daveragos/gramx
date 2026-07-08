import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_theme.dart';
import 'package:gramx/app/theme/app_typography.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(appThemeModeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final primaryColor = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: AppTypography.heading(color: primaryColor)),
      ),
      body: ListView(
        children: [
          // Display section
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
            child: Text('Display', style: AppTypography.subheading(color: secondaryColor)),
          ),
          RadioListTile<AppThemeMode>(
            title: Text('Light', style: AppTypography.body(color: primaryColor)),
            value: AppThemeMode.light,
            groupValue: currentTheme,
            activeColor: AppColors.accent,
            onChanged: (value) => ref.read(appThemeModeProvider.notifier).setThemeMode(value!),
          ),
          RadioListTile<AppThemeMode>(
            title: Text('Dim', style: AppTypography.body(color: primaryColor)),
            subtitle: Text('Blue-tinted dark theme', style: AppTypography.actionCount(color: secondaryColor)),
            value: AppThemeMode.dim,
            groupValue: currentTheme,
            activeColor: AppColors.accent,
            onChanged: (value) => ref.read(appThemeModeProvider.notifier).setThemeMode(value!),
          ),
          RadioListTile<AppThemeMode>(
            title: Text('Lights out', style: AppTypography.body(color: primaryColor)),
            subtitle: Text('Pure black background', style: AppTypography.actionCount(color: secondaryColor)),
            value: AppThemeMode.dark,
            groupValue: currentTheme,
            activeColor: AppColors.accent,
            onChanged: (value) => ref.read(appThemeModeProvider.notifier).setThemeMode(value!),
          ),
          const Divider(),
          // About section
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
            child: Text('About', style: AppTypography.subheading(color: secondaryColor)),
          ),
          ListTile(
            title: Text('Version', style: AppTypography.body(color: primaryColor)),
            subtitle: Text('gramX v0.1.0', style: AppTypography.actionCount(color: secondaryColor)),
          ),
          ListTile(
            title: Text('Status', style: AppTypography.body(color: primaryColor)),
            subtitle: Text('Milestone 1 — Demo Mode', style: AppTypography.actionCount(color: secondaryColor)),
          ),
          ListTile(
            title: Text('Architecture', style: AppTypography.body(color: primaryColor)),
            subtitle: Text('Flutter + Riverpod + Drift + TDLib (pending)', style: AppTypography.actionCount(color: secondaryColor)),
          ),
        ],
      ),
    );
  }
}
