import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';

import 'package:gramx/features/search/presentation/search_screen.dart';

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final channelsAsync = ref.watch(channelsProvider);
    final isDatabaseEmpty = channelsAsync.value?.isEmpty ?? true;
    final isVisible = ref.watch(bottomNavVisibilityProvider) && !isDatabaseEmpty;

    return Scaffold(
      body: navigationShell,
      drawer: const _XDrawer(),
      bottomNavigationBar: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: isVisible
            ? Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor, width: 0.5)),
                ),
                child: BottomNavigationBar(
                  currentIndex: navigationShell.currentIndex,
                  onTap: (index) {
                    ref.read(bottomNavVisibilityProvider.notifier).show();
                    if (index == 1 && navigationShell.currentIndex == 1) {
                      ref.read(searchFocusTriggerProvider.notifier).trigger();
                    }
                    navigationShell.goBranch(
                      index,
                      initialLocation: index == navigationShell.currentIndex,
                    );
                  },
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home_outlined),
                      activeIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.search),
                      activeIcon: Icon(Icons.search),
                      label: 'Search',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.list_alt),
                      activeIcon: Icon(Icons.list_alt),
                      label: 'Channels',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.settings_outlined),
                      activeIcon: Icon(Icons.settings),
                      label: 'Settings',
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _XDrawer extends ConsumerWidget {
  const _XDrawer();

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

    final String displayName = accountAsync.value?.displayName ?? 'Telegram User';
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
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      () {
                        final path = accountAsync.value?.avatarPath;
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
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'R',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        );
                      }(),
                      Icon(Icons.more_vert, color: secondaryColor),
                    ],
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
                        'Channels',
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
                        'Folders',
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
            // Navigation Items
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                GoRouter.of(context).push('/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: const Text('Bookmarks', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                GoRouter.of(context).push('/bookmarks');
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Folders / Lists', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                GoRouter.of(context).push('/folders');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings and Privacy', style: TextStyle(fontWeight: FontWeight.bold)),
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
                'gramX v0.1.0',
                style: TextStyle(color: secondaryColor, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
