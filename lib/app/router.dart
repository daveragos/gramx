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
import 'package:gramx/features/settings/presentation/legal_screen.dart';

// Navigation keys for each branch
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _searchNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'search');
final _channelsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'channels');
final _bookmarksNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'bookmarks');

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
    initialLocation: ShellTab.home.path,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authStep = ref.read(authControllerProvider).step;
      final location = state.matchedLocation;
      final isOnAuth = location == '/auth';

      // The terms and the privacy policy are readable signed out. The sign-in
      // screen links to them, and bouncing someone back to the very screen
      // asking them to agree would be a fine joke and a bad app.
      if (location.startsWith('/legal/')) return null;

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
        return ShellTab.home.path;
      }

      return null; // no redirect needed
    },
    routes: [
      // Branches are declared in ShellTab order and take their paths from it;
      // see app/app_shell.dart. Adding a tab means adding a branch here.
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
                path: ShellTab.home.path,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Search tab
          StatefulShellBranch(
            navigatorKey: _searchNavigatorKey,
            routes: [
              GoRoute(
                path: ShellTab.search.path,
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          // Channels tab
          StatefulShellBranch(
            navigatorKey: _channelsNavigatorKey,
            routes: [
              GoRoute(
                path: ShellTab.channels.path,
                builder: (context, state) => const ChannelsListScreen(),
              ),
            ],
          ),
          // Bookmarks tab
          StatefulShellBranch(
            navigatorKey: _bookmarksNavigatorKey,
            routes: [
              GoRoute(
                path: ShellTab.bookmarks.path,
                builder: (context, state) => const BookmarksScreen(),
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
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/folders',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FoldersScreen(),
      ),
      // Reachable while signed out as well as in: the sign-in screen links
      // here, and nobody should have to agree to something they can't read.
      GoRoute(
        path: '/legal/:document',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => LegalScreen(
          documentId: state.pathParameters['document']!,
        ),
      ),
    ],
  );
});
