import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/widgets/app_drawer.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/search/presentation/search_screen.dart';

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

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
      drawer: const AppDrawer(),
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
