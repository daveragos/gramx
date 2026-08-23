import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/widgets/drawer_nav_item.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';

class AppDrawer extends ConsumerWidget {
  /// Switches to a bottom-bar tab.
  ///
  /// Supplied by the shell rather than looked up here:
  /// `StatefulNavigationShell.of` searches the widget tree, and the drawer is a
  /// *sibling* of the navigation shell, not a descendant. The lookup could
  /// never succeed, so "Saved messages" and "Subscribed channels" closed the
  /// drawer and did nothing else.
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

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The avatar opens the profile, which is what tapping your
                  // own face means everywhere else. The "⋮" that used to sit
                  // opposite it did nothing at all, so it is gone.
                  ChannelAvatar(
                    title: displayName,
                    avatarPath: accountAsync.value?.avatarPath,
                    radius: 24,
                    onTap: () {
                      Navigator.pop(context);
                      GoRouter.of(context).push('/profile');
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    username,
                    style: TextStyle(
                      fontSize: 14,
                      color: secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        channelsCount.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppStrings.drawerChannelsCount,
                        style: TextStyle(
                          fontSize: 14,
                          color: secondaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        foldersCount.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppStrings.drawerFoldersCount,
                        style: TextStyle(
                          fontSize: 14,
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            DrawerNavItem(
              icon: Icons.person_outline_rounded,
              title: AppStrings.drawerProfile,
              onTap: () {
                Navigator.pop(context);
                GoRouter.of(context).push('/profile');
              },
            ),
            // Tabs switch branches rather than pushing. Pushing a branch route
            // onto the root stack leaves the shell's indexed stack behind and
            // throws away that tab's scroll position.
            DrawerNavItem(
              icon: Icons.bookmark_border_rounded,
              title: AppStrings.drawerBookmarks,
              onTap: () => _goToTab(context, ShellTab.bookmarks),
            ),
            DrawerNavItem(
              icon: Icons.list_alt_rounded,
              title: AppStrings.drawerChannels,
              onTap: () => _goToTab(context, ShellTab.channels),
            ),
            DrawerNavItem(
              icon: Icons.folder_outlined,
              title: AppStrings.drawerFolders,
              onTap: () {
                Navigator.pop(context);
                GoRouter.of(context).push('/folders');
              },
            ),
            DrawerNavItem(
              icon: Icons.settings_outlined,
              title: AppStrings.drawerSettings,
              onTap: () {
                Navigator.pop(context);
                GoRouter.of(context).push('/settings');
              },
            ),
            const Spacer(),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                AppStrings.appVersionLabel(),
                style: TextStyle(color: secondaryColor, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
