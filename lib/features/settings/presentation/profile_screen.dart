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
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: AppTypography.heading(color: primaryColor)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(height: 1, thickness: 0.5, color: borderColor),
        ),
      ),
      body: accountAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.error))),
        data: (account) {
          final isLoggedIn = account != null;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Banner Backdrop
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.grid_view_rounded,
                          color: isDark ? Colors.white10 : Colors.black12,
                          size: 48,
                        ),
                      ),
                    ),

                    // Avatar Overlapping Banner
                    Positioned(
                      left: AppSpacing.lg,
                      bottom: -40,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: bgColor, width: 4),
                        ),
                        child: () {
                          final path = account?.avatarPath;
                          if (path != null && path.isNotEmpty) {
                            final file = File(path);
                            if (file.existsSync()) {
                              return CircleAvatar(
                                radius: 40,
                                backgroundImage: FileImage(file),
                              );
                            }
                          }
                          return CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.accent,
                            child: Text(
                              isLoggedIn && (account.displayName?.isNotEmpty ?? false)
                                  ? account.displayName![0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                            ),
                          );
                        }(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 52),

                // 2. Profile Details & Handle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLoggedIn ? (account.displayName ?? 'Telegram User') : 'Guest User',
                        style: AppTypography.heading(color: primaryColor).copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 2),
                      if (isLoggedIn && account.username != null)
                        Text(
                          '@${account.username}',
                          style: AppTypography.username(color: secondaryColor).copyWith(fontSize: 15),
                        )
                      else
                        Text(
                          '@guest',
                          style: AppTypography.username(color: secondaryColor).copyWith(fontSize: 15),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                Divider(height: 1, thickness: 0.5, color: borderColor),

                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    top: AppSpacing.lg,
                    bottom: AppSpacing.xs,
                  ),
                  child: Text(
                    'ACCOUNT DETAILS',
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),

                if (isLoggedIn) ...[
                  ListTile(
                    leading: Icon(Icons.phone_outlined, color: primaryColor),
                    title: Text('Phone Number', style: AppTypography.body(color: primaryColor)),
                    subtitle: Text(account.phoneNumber ?? 'Not provided', style: AppTypography.actionCount(color: secondaryColor)),
                  ),
                  Divider(height: 1, thickness: 0.5, color: borderColor),
                  ListTile(
                    leading: Icon(Icons.badge_outlined, color: primaryColor),
                    title: Text('Telegram ID', style: AppTypography.body(color: primaryColor)),
                    subtitle: Text(account.telegramUserId, style: AppTypography.actionCount(color: secondaryColor)),
                  ),
                  Divider(height: 1, thickness: 0.5, color: borderColor),
                ] else ...[
                  ListTile(
                    leading: Icon(Icons.info_outline, color: primaryColor),
                    title: Text('Status', style: AppTypography.body(color: primaryColor)),
                    subtitle: Text('Offline / Not Logged In', style: AppTypography.actionCount(color: secondaryColor)),
                  ),
                  Divider(height: 1, thickness: 0.5, color: borderColor),
                ],

                const SizedBox(height: AppSpacing.xl),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: isLoggedIn
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: () => _confirmLogout(context, ref),
                          child: const Text('Log out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: () {
                            context.push('/auth');
                          },
                          child: const Text('Log in with Telegram', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                ),
                const SizedBox(height: AppSpacing.xl),
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
