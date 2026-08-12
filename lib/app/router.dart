import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/app_shell.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/auth/presentation/auth_screen.dart';
import 'package:gramx/features/bookmarks/presentation/bookmarks_screen.dart';
import 'package:gramx/features/channels/presentation/channel_profile_screen.dart';
import 'package:gramx/features/channels/presentation/channels_list_screen.dart';
import 'package:gramx/features/feed/presentation/home_screen.dart';
import 'package:gramx/features/folders/presentation/folders_screen.dart';
import 'package:gramx/features/post_detail/presentation/post_detail_screen.dart';
import 'package:gramx/features/search/presentation/search_screen.dart';
import 'package:gramx/features/settings/presentation/settings_screen.dart';
import 'package:gramx/features/settings/presentation/profile_screen.dart';

// Navigation keys for each branch
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _searchNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'search');
final _channelsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'channels');
final _settingsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'settings');

/// Auth-gated router.
///
/// The [redirect] callback checks the current auth step on every navigation:
///  - Loading → stay on current route (no redirect).
///  - Not authenticated → redirect to /auth.
///  - Authenticated + on /auth → redirect to /home.
///
/// [refreshListenable] is a ValueNotifier that fires whenever the auth step
/// changes, causing GoRouter to re-evaluate the redirect callback.
final routerProvider = Provider<GoRouter>((ref) {
  // Seed the notifier with the current auth step.
  final authNotifier = ValueNotifier<AuthStep>(
    ref.read(authControllerProvider).step,
  );

  // Listen (NOT watch) to auth state so the GoRouter instance is stable —
  // we only want to trigger refreshListenable, not rebuild the router.
  ref.listen<AuthState>(authControllerProvider, (_, next) {
    authNotifier.value = next.step;
  });

  ref.onDispose(() => authNotifier.dispose());

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authStep = ref.read(authControllerProvider).step;
      final location = state.matchedLocation;
      final isOnAuth = location == '/auth';

      // While TDLib is still initialising, don't redirect — let the user
      // see whatever is currently rendered (splash / loading).
      if (authStep == AuthStep.loading) {
        return null;
      }

      final isAuthenticated = authStep == AuthStep.authenticated;

      // Not authenticated → force auth screen.
      if (!isAuthenticated && !isOnAuth) {
        return '/auth';
      }

      // Already authenticated but lingering on /auth → go home.
      if (isAuthenticated && isOnAuth) {
        return '/home';
      }

      return null; // no redirect needed
    },
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
                builder: (context, state) => const ChannelsListScreen(),
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
          final focusReply = state.uri.queryParameters['focusReply'] == 'true';
          return PostDetailScreen(
            postId: postId,
            autoFocusReply: focusReply,
          );
        },
      ),
      GoRoute(
        path: '/channel/:channelId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final channelId = state.pathParameters['channelId']!;
          final highlightStr = state.uri.queryParameters['highlight'];
          final highlightMessageId =
              highlightStr != null ? int.tryParse(highlightStr) : null;
          return ChannelProfileScreen(
            channelId: channelId,
            highlightMessageId: highlightMessageId,
          );
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
      GoRoute(
        path: '/bookmarks',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BookmarksScreen(),
      ),
      GoRoute(
        path: '/folders',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FoldersScreen(),
      ),
    ],
  );
});
