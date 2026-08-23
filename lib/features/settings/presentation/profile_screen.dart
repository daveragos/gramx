import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/l10n/app_strings.dart';
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
        title: Text(AppStrings.profileTitle,
            style: AppTypography.heading(color: primaryColor)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(height: 1, thickness: 0.5, color: borderColor),
        ),
      ),
      body: accountAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (err, _) => Center(
          child: Text(AppStrings.profileError(err),
              style: const TextStyle(color: AppColors.error)),
        ),
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
                        isLoggedIn
                            ? (account.displayName ??
                                AppStrings.drawerAccountFallback)
                            : AppStrings.profileGuestName,
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
                          AppStrings.profileGuestHandle,
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
                    AppStrings.profileSectionDetails,
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),

                if (isLoggedIn) ...[
                  // Both details are the kind of thing you copy into a support
                  // form, so tapping copies rather than doing nothing.
                  _CopyableDetail(
                    icon: Icons.phone_outlined,
                    label: AppStrings.profilePhone,
                    value: account.phoneNumber,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                  ),
                  Divider(height: 1, thickness: 0.5, color: borderColor),
                  _CopyableDetail(
                    icon: Icons.badge_outlined,
                    label: AppStrings.profileTelegramId,
                    value: account.telegramUserId,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                  ),
                  Divider(height: 1, thickness: 0.5, color: borderColor),
                  ListTile(
                    leading: Icon(Icons.settings_outlined, color: primaryColor),
                    title: Text(AppStrings.profileOpenSettings,
                        style: AppTypography.body(color: primaryColor)),
                    subtitle: Text(AppStrings.profileOpenSettingsBody,
                        style:
                            AppTypography.actionCount(color: secondaryColor)),
                    trailing: Icon(Icons.chevron_right, color: secondaryColor),
                    onTap: () => context.push('/settings'),
                  ),
                  Divider(height: 1, thickness: 0.5, color: borderColor),
                ] else ...[
                  ListTile(
                    leading: Icon(Icons.info_outline, color: primaryColor),
                    title: Text(AppStrings.profileStatus,
                        style: AppTypography.body(color: primaryColor)),
                    subtitle: Text(AppStrings.profileStatusOffline,
                        style:
                            AppTypography.actionCount(color: secondaryColor)),
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
                          child: const Text(AppStrings.settingsLogOut,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
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
                          child: const Text(AppStrings.profileLogIn,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
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
        title: const Text(AppStrings.settingsLogOutTitle),
        content: const Text(AppStrings.settingsLogOutBody),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.settingsCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.settingsLogOut,
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.bold)),
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

/// An account detail that can be copied.
///
/// These rows are the only place the reader can get at their own Telegram id or
/// phone number, and reading a number off a screen to type it somewhere else is
/// a bad time — so the row does something when tapped.
class _CopyableDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color primaryColor;
  final Color secondaryColor;

  const _CopyableDetail({
    required this.icon,
    required this.label,
    required this.value,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final shown = value?.isNotEmpty == true
        ? value!
        : AppStrings.profileNotProvided;
    final canCopy = value?.isNotEmpty == true;

    return ListTile(
      leading: Icon(icon, color: primaryColor),
      title: Text(label, style: AppTypography.body(color: primaryColor)),
      subtitle:
          Text(shown, style: AppTypography.actionCount(color: secondaryColor)),
      trailing:
          canCopy ? Icon(Icons.copy_rounded, size: 18, color: secondaryColor) : null,
      onTap: canCopy
          ? () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: value!));
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(AppStrings.profileCopied),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          : null,
    );
  }
}
