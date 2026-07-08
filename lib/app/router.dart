import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/app_shell.dart';
import 'package:gramx/features/auth/presentation/auth_screen.dart';
import 'package:gramx/features/channels/presentation/channel_profile_screen.dart';
import 'package:gramx/features/feed/presentation/home_screen.dart';
import 'package:gramx/features/post_detail/presentation/post_detail_screen.dart';
import 'package:gramx/features/search/presentation/search_screen.dart';
import 'package:gramx/features/settings/presentation/settings_screen.dart';
import 'package:gramx/features/settings/presentation/profile_screen.dart';

// Channels list screen (placeholder for the "Channels" tab)
class _ChannelsListScreen extends StatelessWidget {
  const _ChannelsListScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Channels',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, color: theme.iconTheme.color, size: 64),
            const SizedBox(height: 16),
            Text(
              'Channels',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your subscribed channels will appear here\nafter Telegram login.',
              style: TextStyle(
                fontSize: 15,
                color: theme.iconTheme.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Navigation keys for each branch
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _searchNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'search');
final _channelsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'channels');
final _settingsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'settings');

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        // Home tab
        StatefulShellBranch(
          navigatorKey: _homeNavigatorKey,
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        // Search tab
        StatefulShellBranch(
          navigatorKey: _searchNavigatorKey,
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchScreen(),
            ),
          ],
        ),
        // Channels tab
        StatefulShellBranch(
          navigatorKey: _channelsNavigatorKey,
          routes: [
            GoRoute(
              path: '/channels',
              builder: (context, state) => const _ChannelsListScreen(),
            ),
          ],
        ),
        // Settings tab
        StatefulShellBranch(
          navigatorKey: _settingsNavigatorKey,
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    // Detail routes (outside shell — full screen)
    GoRoute(
      path: '/post/:postId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final postId = state.pathParameters['postId']!;
        return PostDetailScreen(postId: postId);
      },
    ),
    GoRoute(
      path: '/channel/:channelId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final channelId = state.pathParameters['channelId']!;
        return ChannelProfileScreen(channelId: channelId);
      },
    ),
    GoRoute(
      path: '/auth',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/profile',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
);
