import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/l10n/app_strings.dart';
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
class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// How long a second back press still counts as "I meant it".
  static const Duration _exitWindow = Duration(seconds: 2);

  DateTime? _lastBackPress;

  StatefulNavigationShell get navigationShell => widget.navigationShell;

  /// Back behaviour for the whole shell.
  ///
  /// From any tab other than Home, back returns to Home — leaving the app from
  /// deep in Settings is not what the gesture means. Only from Home does a
  /// second press within [_exitWindow] actually exit.
  void _handleBack() {
    if (navigationShell.currentIndex != ShellTab.home.index) {
      navigationShell.goBranch(ShellTab.home.index);
      return;
    }

    final now = DateTime.now();
    final last = _lastBackPress;
    if (last == null || now.difference(last) > _exitWindow) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.feedPressBackAgain),
          duration: _exitWindow,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    SystemNavigator.pop();
  }

  /// Switches branch, or returns to that branch's root if it is already active
  /// — the standard tab-bar behaviour, and what makes a second tap on Home
  /// mean "take me back to the top".
  void _onTap(int index) {
    final isRetap = index == navigationShell.currentIndex;

    // Re-tapping Home means "take me back to the top of what I'm reading".
    // goBranch alone only resets the branch's route stack.
    if (isRetap && index == ShellTab.home.index) {
      ref
          .read(feedScrollToTopProvider.notifier)
          .request(ref.read(activeFolderProvider));
    }

    navigationShell.goBranch(index, initialLocation: isRetap);
  }

  @override
  Widget build(BuildContext context) {
    final isVisible = ref.watch(chromeVisibleProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
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
      ),
    );
  }
}
