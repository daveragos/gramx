import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/widgets/app_drawer.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';

/// The tabs in the bottom bar, in order.
///
/// This is the single source of truth for tab order: `app/router.dart` declares
/// its branches in this order and takes each route path from [path], so an
/// index can't come to mean two different things.
enum ShellTab {
  home(Icons.home_outlined, Icons.home, 'Home', '/home'),
  search(Icons.search_outlined, Icons.search, 'Search', '/search'),
  channels(Icons.list_alt_outlined, Icons.list_alt, 'Channels', '/channels'),
  bookmarks(Icons.bookmark_border_rounded, Icons.bookmark_rounded, 'Bookmarks',
      '/bookmarks');

  const ShellTab(this.icon, this.activeIcon, this.label, this.path);

  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// The route this tab's branch is rooted at. The router reads it from here so
  /// the tab order and the branch order cannot drift apart.
  final String path;
}

/// Hosts the tab bar and the drawer around whichever branch is showing.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  /// Switches branch, or returns to that branch's root if it is already active
  /// — the standard tab-bar behaviour, and what makes a second tap on Home
  /// mean "take me back to the top".
  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(bottomNavVisibilityProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      body: navigationShell,
      drawer: const AppDrawer(),
      bottomNavigationBar: ClipRect(
        // Collapsing the height rather than sliding keeps the feed from
        // scrolling under a bar that still occupies layout space.
        child: AnimatedAlign(
          alignment: Alignment.topCenter,
          heightFactor: isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor, width: 0.5)),
            ),
            child: BottomNavigationBar(
              currentIndex: navigationShell.currentIndex,
              onTap: _onTap,
              items: [
                for (final tab in ShellTab.values)
                  BottomNavigationBarItem(
                    icon: Icon(tab.icon),
                    activeIcon: Icon(tab.activeIcon),
                    label: tab.label,
                    tooltip: tab.label,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
