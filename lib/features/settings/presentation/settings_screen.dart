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
  // Feed Preferences state
  bool _autoPlayVideos = false;

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Settings and privacy', style: AppTypography.heading(color: primaryColor)),
            accountAsync.when(
              data: (acc) => acc != null && acc.username != null
                  ? Text('@${acc.username}', style: AppTypography.actionCount(color: secondaryColor))
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (err, st) => const SizedBox.shrink(),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(height: 1, thickness: 0.5, color: borderColor),
        ),
      ),
      body: ListView(
        children: [
          accountAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
            ),
            error: (err, stack) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('Error loading account: $err', style: const TextStyle(color: AppColors.error)),
            ),
            data: (account) {
              final isLoggedIn = account != null;
              if (isLoggedIn) {
                return InkWell(
                  onTap: () => context.push('/profile'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
                    ),
                    child: Row(
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
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
                                style: AppTypography.displayName(color: primaryColor).copyWith(fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@${account.username ?? 'user'}',
                                style: AppTypography.username(color: secondaryColor),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: secondaryColor),
                      ],
                    ),
                  ),
                );
              }

              return InkWell(
                onTap: () => context.push('/auth'),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.accent,
                        child: Icon(Icons.login_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Log in to Telegram',
                              style: AppTypography.subheading(color: primaryColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Sync your channels, folders, and timeline',
                              style: AppTypography.actionCount(color: secondaryColor),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.accent),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. YOUR ACCOUNT SECTION
          _SectionHeader(title: 'YOUR ACCOUNT', secondaryColor: secondaryColor),
          ListTile(
            leading: Icon(Icons.person_outline, color: primaryColor),
            title: Text('Account Information', style: AppTypography.body(color: primaryColor)),
            subtitle: Text('See your Telegram account details, ID, and phone number', style: AppTypography.actionCount(color: secondaryColor)),
            trailing: Icon(Icons.chevron_right, color: secondaryColor),
            onTap: () => context.push('/profile'),
          ),
          Divider(height: 1, thickness: 0.5, color: borderColor),

          _SectionHeader(title: 'DISPLAY AND SOUND', secondaryColor: secondaryColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
            child: Text(
              'Dark mode appearance',
              style: AppTypography.actionCount(color: secondaryColor),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: _XThemeSegmentTile(
                    title: 'Light',
                    mode: AppThemeMode.light,
                    currentMode: currentTheme,
                    bgColor: AppColors.lightBackground,
                    borderColor: borderColor,
                    tileTextColor: AppColors.lightTextPrimary,
                    onTap: () => ref.read(appThemeModeProvider.notifier).setThemeMode(AppThemeMode.light),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _XThemeSegmentTile(
                    title: 'Lights out',
                    mode: AppThemeMode.dark,
                    currentMode: currentTheme,
                    bgColor: AppColors.darkBackground,
                    borderColor: borderColor,
                    tileTextColor: AppColors.darkTextPrimary,
                    onTap: () => ref.read(appThemeModeProvider.notifier).setThemeMode(AppThemeMode.dark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, thickness: 0.5, color: borderColor),

          // 4. PREFERENCES SECTION
          _SectionHeader(title: 'PREFERENCES', secondaryColor: secondaryColor),
          SwitchListTile(
            secondary: Icon(Icons.play_circle_outline, color: primaryColor),
            title: Text('Auto-play videos', style: AppTypography.body(color: primaryColor)),
            subtitle: Text('Videos play automatically in your feed', style: AppTypography.actionCount(color: secondaryColor)),
            activeThumbColor: AppColors.accent,
            value: _autoPlayVideos,
            onChanged: (val) => setState(() => _autoPlayVideos = val),
          ),
          Divider(height: 1, thickness: 0.5, color: borderColor),

          // 5. DATA AND STORAGE SECTION
          _SectionHeader(title: 'DATA AND STORAGE', secondaryColor: secondaryColor),
          ListTile(
            leading: Icon(Icons.storage_outlined, color: primaryColor),
            title: Text('Media Storage & Cache', style: AppTypography.body(color: primaryColor)),
            subtitle: Text('Manage offline media and data cache', style: AppTypography.actionCount(color: secondaryColor)),
            trailing: const Text('Clear', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 14)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Storage cache cleared.',
                    style: AppTypography.body(color: Colors.white),
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          Divider(height: 1, thickness: 0.5, color: borderColor),

          // 6. ABOUT & SUPPORT SECTION
          _SectionHeader(title: 'ABOUT & SUPPORT', secondaryColor: secondaryColor),
          ListTile(
            leading: Icon(Icons.info_outline, color: primaryColor),
            title: Text('Version', style: AppTypography.body(color: primaryColor)),
            trailing: Text('v0.1.0', style: AppTypography.actionCount(color: secondaryColor)),
          ),
          Divider(height: 1, thickness: 0.5, color: borderColor),
          ListTile(
            leading: Icon(Icons.shield_outlined, color: primaryColor),
            title: Text('Privacy Policy', style: AppTypography.body(color: primaryColor)),
            trailing: Icon(Icons.chevron_right, color: secondaryColor),
            onTap: () {},
          ),
          Divider(height: 1, thickness: 0.5, color: borderColor),
          ListTile(
            leading: Icon(Icons.help_outline, color: primaryColor),
            title: Text('Help Center', style: AppTypography.body(color: primaryColor)),
            trailing: Icon(Icons.chevron_right, color: secondaryColor),
            onTap: () {},
          ),
          Divider(height: 1, thickness: 0.5, color: borderColor),

          accountAsync.when(
            data: (acc) => acc != null
                ? Column(
                    children: [
                      const SizedBox(height: AppSpacing.md),
                      ListTile(
                        leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                        title: const Text(
                          'Log out',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        onTap: () => _confirmLogout(context, ref),
                      ),
                      Divider(height: 1, thickness: 0.5, color: borderColor),
                    ],
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (err, stack) => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out of gramX?'),
        content: const Text('You will need to re-login to access your synced Telegram timeline and channels.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color secondaryColor;

  const _SectionHeader({
    required this.title,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        title,
        style: TextStyle(
          color: secondaryColor,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _XThemeSegmentTile extends StatelessWidget {
  final String title;
  final AppThemeMode mode;
  final AppThemeMode currentMode;
  final Color bgColor;
  final Color borderColor;
  final Color tileTextColor;
  final VoidCallback onTap;

  const _XThemeSegmentTile({
    required this.title,
    required this.mode,
    required this.currentMode,
    required this.bgColor,
    required this.borderColor,
    required this.tileTextColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = mode == currentMode;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accent : borderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.accent : tileTextColor.withValues(alpha: 0.6),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: AppTypography.body(color: isSelected ? AppColors.accent : tileTextColor).copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
