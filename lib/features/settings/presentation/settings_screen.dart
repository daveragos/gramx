import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_theme.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Feed Preferences stubs state
  bool _autoPlayVideos = false;
  bool _smartReadTracking = false;
  bool _snapScrolling = false;

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(appThemeModeProvider);
    final accountAsync = ref.watch(activeAccountProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final primaryColor = theme.colorScheme.onSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: AppTypography.heading(color: primaryColor)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          // 1. Account Section Card
          accountAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('Error: $err', style: TextStyle(color: AppColors.error)),
            ),
            data: (account) {
              final isLoggedIn = account != null;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                ),
                child: isLoggedIn
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              () {
                                final path = account.avatarPath;
                                if (path != null && path.isNotEmpty) {
                                  final file = File(path);
                                  if (file.existsSync()) {
                                    return CircleAvatar(
                                      radius: 24,
                                      backgroundImage: FileImage(file),
                                    );
                                  }
                                }
                                return CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.accent,
                                  child: Text(
                                    account.displayName?.isNotEmpty ?? false
                                        ? account.displayName![0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                );
                              }(),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      account.displayName ?? 'Telegram User',
                                      style: AppTypography.displayName(color: primaryColor),
                                    ),
                                    if (account.username != null)
                                      Text(
                                        '@${account.username}',
                                        style: AppTypography.username(color: secondaryColor),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Divider(height: 1),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Phone Number', style: AppTypography.actionCount(color: secondaryColor)),
                                  const SizedBox(height: 2),
                                  Text(account.phoneNumber ?? 'Not provided', style: AppTypography.body(color: primaryColor)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Telegram ID', style: AppTypography.actionCount(color: secondaryColor)),
                                  const SizedBox(height: 2),
                                  Text(account.telegramUserId, style: AppTypography.body(color: primaryColor)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _confirmLogout(context, ref),
                            child: const Text(
                              'Log out from gramX',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Connect to Telegram',
                            style: AppTypography.subheading(color: primaryColor),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Log in with your phone number or QR code to sync your channel folders and post timeline.',
                            style: AppTypography.body(color: secondaryColor),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            onPressed: () => context.push('/auth'),
                            child: const Text('Log In with Telegram', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // 2. Appearance Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text('Appearance', style: AppTypography.subheading(color: secondaryColor)),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: _ThemePreviewCard(
                    title: 'Light',
                    mode: AppThemeMode.light,
                    currentMode: currentTheme,
                    previewColor: AppColors.lightBackground,
                    onTap: () => ref.read(appThemeModeProvider.notifier).setThemeMode(AppThemeMode.light),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _ThemePreviewCard(
                    title: 'Dim',
                    mode: AppThemeMode.dim,
                    currentMode: currentTheme,
                    previewColor: AppColors.dimBackground,
                    onTap: () => ref.read(appThemeModeProvider.notifier).setThemeMode(AppThemeMode.dim),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _ThemePreviewCard(
                    title: 'Dark',
                    mode: AppThemeMode.dark,
                    currentMode: currentTheme,
                    previewColor: AppColors.darkBackground,
                    onTap: () => ref.read(appThemeModeProvider.notifier).setThemeMode(AppThemeMode.dark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // 3. Feed Preferences Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text('Feed Preferences', style: AppTypography.subheading(color: secondaryColor)),
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            title: Text('Auto-play videos', style: AppTypography.body(color: primaryColor)),
            subtitle: Text('Play videos automatically in feed', style: AppTypography.actionCount(color: secondaryColor)),
            value: _autoPlayVideos,
            onChanged: (val) => setState(() => _autoPlayVideos = val),
          ),
          SwitchListTile(
            title: Text('Smart read tracking', style: AppTypography.body(color: primaryColor)),
            subtitle: Text('Mark posts as read based on viewing time', style: AppTypography.actionCount(color: secondaryColor)),
            value: _smartReadTracking,
            onChanged: (val) => setState(() => _smartReadTracking = val),
          ),
          SwitchListTile(
            title: Text('Snap scrolling', style: AppTypography.body(color: primaryColor)),
            subtitle: Text('Posts snap into view when scrolling', style: AppTypography.actionCount(color: secondaryColor)),
            value: _snapScrolling,
            onChanged: (val) => setState(() => _snapScrolling = val),
          ),
          const SizedBox(height: AppSpacing.xl),

          // 4. Storage & Data Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text('Storage & Data', style: AppTypography.subheading(color: secondaryColor)),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: 0.5),
              borderRadius: BorderRadius.circular(12),
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Local Storage Cache', style: AppTypography.body(color: primaryColor)),
                    Text('Calculating...', style: AppTypography.actionCount(color: secondaryColor)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const LinearProgressIndicator(
                  value: 0.0,
                  backgroundColor: Colors.grey,
                  color: AppColors.accent,
                  minHeight: 6,
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  leading: const Icon(Icons.delete_outline, color: AppColors.error),
                  title: const Text('Clear cache', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Storage clearing will be fully wired up in Phase 6.',
                          style: AppTypography.body(color: Colors.white),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // 5. About Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text('About & Support', style: AppTypography.subheading(color: secondaryColor)),
          ),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            title: Text('Version', style: AppTypography.body(color: primaryColor)),
            trailing: Text('v0.1.0', style: AppTypography.actionCount(color: secondaryColor)),
          ),
          ListTile(
            title: Text('Privacy Policy', style: AppTypography.body(color: primaryColor)),
            trailing: Icon(Icons.chevron_right, color: secondaryColor),
            onTap: () {},
          ),
          ListTile(
            title: Text('Help Center', style: AppTypography.body(color: primaryColor)),
            trailing: Icon(Icons.chevron_right, color: secondaryColor),
            onTap: () {},
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

class _ThemePreviewCard extends StatelessWidget {
  final String title;
  final AppThemeMode mode;
  final AppThemeMode currentMode;
  final Color previewColor;
  final VoidCallback onTap;

  const _ThemePreviewCard({
    required this.title,
    required this.mode,
    required this.currentMode,
    required this.previewColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = mode == currentMode;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.onSurface;
    final isDarkTheme = theme.brightness == Brightness.dark;
    final customBorderColor = isDarkTheme ? AppColors.darkBorder : AppColors.lightBorder;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.accent : customBorderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12),
          color: theme.brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview Swatch Box
            Container(
              height: 40,
              width: 60,
              decoration: BoxDecoration(
                color: previewColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: customBorderColor, width: 0.5),
              ),
              child: Center(
                child: Container(
                  height: 3,
                  width: 20,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: AppTypography.body(color: primaryColor).copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              const Icon(
                Icons.check_circle,
                color: AppColors.accent,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
