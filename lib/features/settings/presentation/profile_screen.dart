import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(activeAccountProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: AppTypography.heading(color: primaryColor)),
      ),
      body: accountAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (account) {
          final isLoggedIn = account != null;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                // Avatar & Profile Header
                Center(
                  child: Column(
                    children: [
                      () {
                        final path = account?.avatarPath;
                        if (path != null && path.isNotEmpty) {
                          final file = File(path);
                          if (file.existsSync()) {
                            return CircleAvatar(
                              radius: 50,
                              backgroundImage: FileImage(file),
                            );
                          }
                        }
                        return CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.accent,
                          child: Text(
                            isLoggedIn && (account.displayName?.isNotEmpty ?? false)
                                ? account.displayName![0].toUpperCase()
                                : 'U',
                            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                          ),
                        );
                      }(),
                      const SizedBox(height: 16),
                      Text(
                        isLoggedIn ? (account.displayName ?? 'Telegram User') : 'Guest User',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isLoggedIn && account.username != null)
                        Text(
                          '@${account.username}',
                          style: TextStyle(
                            fontSize: 16,
                            color: secondaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(),
                // Account details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  child: Text('Account Details', style: AppTypography.subheading(color: secondaryColor)),
                ),
                if (isLoggedIn) ...[
                  ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: Text('Phone Number', style: AppTypography.body(color: primaryColor)),
                    subtitle: Text(account.phoneNumber ?? 'Not provided', style: AppTypography.actionCount(color: secondaryColor)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.fingerprint_outlined),
                    title: Text('Telegram ID', style: AppTypography.body(color: primaryColor)),
                    subtitle: Text(account.telegramUserId, style: AppTypography.actionCount(color: secondaryColor)),
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text('Status', style: AppTypography.body(color: primaryColor)),
                    subtitle: Text('Offline / Not Logged In', style: AppTypography.actionCount(color: secondaryColor)),
                  ),
                ],
                const Divider(),
                const SizedBox(height: 16),
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: isLoggedIn
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: () => _confirmLogout(context, ref),
                          child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: () {
                            context.push('/auth');
                          },
                          child: const Text('Log In with Telegram', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                ),
              ],
            ),
          );
        },
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
