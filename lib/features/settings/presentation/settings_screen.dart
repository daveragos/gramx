import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_theme.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(appThemeModeProvider);
    final accountAsync = ref.watch(activeAccountProvider);
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
          // Account section
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
            child: Text('Account', style: AppTypography.subheading(color: secondaryColor)),
          ),
          accountAsync.when(
            loading: () => const ListTile(
              title: Text('Loading connection status...'),
              trailing: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (err, _) => ListTile(
              title: Text('Connection status error: $err'),
            ),
            data: (account) {
              final isLoggedIn = account != null;
              if (isLoggedIn) {
                final usernameText = account.username != null ? ' (@${account.username})' : '';
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.check_circle_outline, color: AppColors.verified),
                      title: Text('Status', style: AppTypography.body(color: primaryColor)),
                      subtitle: Text('Connected as ${account.displayName}$usernameText', style: AppTypography.actionCount(color: secondaryColor)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout, color: AppColors.error),
                      title: const Text('Log Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                      onTap: () => _confirmLogout(context, ref),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: Colors.grey),
                      title: Text('Status', style: AppTypography.body(color: primaryColor)),
                      subtitle: Text('Not Connected', style: AppTypography.actionCount(color: secondaryColor)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.login, color: AppColors.accent),
                      title: const Text('Log In with Telegram', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                      onTap: () {
                        context.push('/auth');
                      },
                    ),
                  ],
                );
              }
            },
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
            title: Text('Architecture', style: AppTypography.body(color: primaryColor)),
            subtitle: Text('Flutter + Riverpod + Drift + TDLib (Active)', style: AppTypography.actionCount(color: secondaryColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out from gramX? This will clear all offline synced feeds and accounts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
      if (context.mounted) {
        context.go('/auth');
      }
    }
  }
}
