import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/drawer_nav_item.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/channels/presentation/channels_list_screen.dart';
import 'package:gramx/features/chats/presentation/open_saved_messages.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_mark.dart';

class AppDrawer extends ConsumerWidget {
  /// Switches to a bottom-bar tab. Passed in by the shell because the drawer
  /// is a sibling of the navigation shell, so `StatefulNavigationShell.of`
  /// cannot find it.
  final void Function(ShellTab tab) onSelectTab;

  const AppDrawer({super.key, required this.onSelectTab});

  void _goToTab(BuildContext context, ShellTab tab) {
    Navigator.pop(context);
    onSelectTab(tab);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final primaryColor = theme.colorScheme.onSurface;

    final accountAsync = ref.watch(activeAccountProvider);
    final channelsAsync = ref.watch(channelsProvider);
    final foldersAsync = ref.watch(foldersProvider);

    final String displayName =
        accountAsync.value?.displayName ?? AppStrings.drawerAccountFallback;
    final String username = accountAsync.value?.username != null
        ? '@${accountAsync.value!.username}'
        : '';
    final int channelsCount = channelsAsync.value?.length ?? 0;
    final int foldersCount = foldersAsync.value?.length ?? 0;

    final nameStyle = AppTypography.displayName(
      color: primaryColor,
    ).copyWith(fontSize: 23.5);
    final handleStyle = AppTypography.username(
      color: secondaryColor,
    ).copyWith(fontSize: 16.5);
    final countStyle = AppTypography.displayName(color: primaryColor);
    final countLabelStyle = AppTypography.username(color: secondaryColor);

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      // Most of the screen, with square corners.
      width: MediaQuery.sizeOf(context).width * 0.88,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChannelAvatar(
                    title: displayName,
                    avatarPath: accountAsync.value?.avatarPath,
                    radius: 20,
                    onTap: () {
                      Navigator.pop(context);
                      GoRouter.of(context).push('/profile');
                    },
                  ),
                  const SizedBox(height: 16.5),
                  Text(
                    displayName,
                    style: nameStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (username.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(username, style: handleStyle),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(channelsCount.toString(), style: countStyle),
                      const SizedBox(width: 4),
                      Text(
                        AppStrings.drawerChannelsCount,
                        style: countLabelStyle,
                      ),
                      const SizedBox(width: 12),
                      Text(foldersCount.toString(), style: countStyle),
                      const SizedBox(width: 4),
                      Text(
                        AppStrings.drawerFoldersCount,
                        style: countLabelStyle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 0.5),
            // Scrolls so the items fit on short screens.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  DrawerNavItem(
                    icon: Icons.person_outline_rounded,
                    title: AppStrings.drawerProfile,
                    onTap: () {
                      Navigator.pop(context);
                      GoRouter.of(context).push('/profile');
                    },
                  ),
                  // Tabs switch branches rather than pushing, which would lose
                  // the tab's scroll position. Other entries push routes.
                  DrawerNavItem(
                    leading: TrokMark(size: 26, color: primaryColor),
                    title: AppStrings.trokName,
                    onTap: () => _goToTab(context, ShellTab.trok),
                  ),
                  DrawerNavItem(
                    icon: Icons.notifications_none_rounded,
                    title: AppStrings.drawerActivity,
                    onTap: () => _goToTab(context, ShellTab.activity),
                  ),
                  DrawerNavItem(
                    icon: Icons.bookmark_border_rounded,
                    title: AppStrings.drawerBookmarks,
                    onTap: () {
                      Navigator.pop(context);
                      GoRouter.of(context).push('/bookmarks');
                    },
                  ),
                  DrawerNavItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: AppStrings.messagesTab,
                    onTap: () => _goToTab(context, ShellTab.messages),
                  ),
                  // Telegram's notes-to-self chat, which otherwise sorts by
                  // activity in the chat list.
                  if (canOpenSavedMessages(ref))
                    DrawerNavItem(
                      icon: Icons.bookmark_added_outlined,
                      title: AppStrings.drawerSavedMessages,
                      onTap: () {
                        Navigator.pop(context);
                        openSavedMessages(context, ref);
                      },
                    ),
                  DrawerNavItem(
                    icon: Icons.list_alt_rounded,
                    title: AppStrings.drawerChannels,
                    onTap: () {
                      Navigator.pop(context);
                      GoRouter.of(context).push(ChannelsListScreen.route);
                    },
                  ),
                  DrawerNavItem(
                    icon: Icons.folder_outlined,
                    title: AppStrings.drawerFolders,
                    onTap: () {
                      Navigator.pop(context);
                      GoRouter.of(context).push('/folders');
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 0.5),
            const SizedBox(height: 16),
            // The quieter entries at the foot, as on the settings side.
            DrawerNavItem(
              icon: Icons.settings_outlined,
              title: AppStrings.drawerSettings,
              compact: true,
              onTap: () {
                Navigator.pop(context);
                GoRouter.of(context).push('/settings');
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                AppStrings.appVersionLabel(),
                style: AppTypography.actionCount(color: secondaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
