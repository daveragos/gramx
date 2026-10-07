import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/widgets/shell_branch_stack.dart';
import 'package:gramx/app/app_shell.dart';
import 'package:gramx/features/guest/presentation/guest_channels_screen.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/app/auth_redirect.dart';
import 'package:gramx/core/navigation/deep_link_handler.dart';
import 'package:gramx/app/splash_screen.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/auth/presentation/auth_screen.dart';
import 'package:gramx/features/bookmarks/presentation/bookmarks_screen.dart';
import 'package:gramx/features/channels/presentation/channel_profile_screen.dart';
import 'package:gramx/features/stats/presentation/channel_stats_screen.dart';
import 'package:gramx/features/stats/presentation/post_stats_screen.dart';
import 'package:gramx/features/channels/presentation/channels_list_screen.dart';
import 'package:gramx/features/chats/presentation/chats_screen.dart';
import 'package:gramx/features/chats/presentation/conversation_screen.dart';
import 'package:gramx/features/chats/presentation/user_profile_screen.dart';
import 'package:gramx/features/compose/presentation/compose_screen.dart';
import 'package:gramx/features/feed/presentation/home_screen.dart';
import 'package:gramx/features/folders/presentation/folders_screen.dart';
import 'package:gramx/features/post_detail/presentation/post_detail_screen.dart';
import 'package:gramx/features/search/presentation/search_screen.dart';
import 'package:gramx/features/settings/presentation/settings_screen.dart';
import 'package:gramx/features/settings/presentation/profile_screen.dart';
import 'package:gramx/features/settings/presentation/legal_screen.dart';
import 'package:gramx/features/activity/presentation/activity_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _searchNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'search');
final _channelsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'channels');
final _activityNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'activity');
final _messagesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'messages');

/// How long the splash waits for TDLib's startup authorization states.
const Duration authSettleWindow = Duration(milliseconds: 700);

/// The app's router. Redirects are decided by [authRedirect].
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ValueNotifier<AuthStep>(
    ref.read(authControllerProvider).step,
  );

  // Listened to, not watched, so the GoRouter instance stays stable.
  var hasSignedIn =
      ref.read(authControllerProvider).step == AuthStep.authenticated;

  ref.listen<AuthState>(authControllerProvider, (_, next) {
    if (next.step == AuthStep.authenticated) hasSignedIn = true;
    authNotifier.value = next.step;
  });

  // Guest mode changes which routes are reachable.
  final guestNotifier = ValueNotifier<bool>(ref.read(isGuestModeProvider));
  ref.listen<bool>(
    isGuestModeProvider,
    (_, next) => guestNotifier.value = next,
  );

  // Flips after [authSettleWindow]; see authRedirect's `isSettled`.
  final settledNotifier = ValueNotifier<bool>(false);
  final settleTimer = Timer(authSettleWindow, () {
    settledNotifier.value = true;
  });

  ref.onDispose(() {
    settleTimer.cancel();
    authNotifier.dispose();
    guestNotifier.dispose();
    settledNotifier.dispose();
  });

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    // See deepLinkFromStrayLocation.
    onException: (context, state, router) {
      final link = deepLinkFromStrayLocation(state.uri);
      if (link != null) {
        ref.read(pendingDeepLinkProvider.notifier).offer(link);
      }
      router.go(ShellTab.home.path);
    },
    initialLocation: SplashScreen.route,
    refreshListenable: Listenable.merge([
      authNotifier,
      guestNotifier,
      settledNotifier,
    ]),
    redirect: (context, state) => authRedirect(
      step: ref.read(authControllerProvider).step,
      location: state.matchedLocation,
      hasSignedIn: hasSignedIn,
      isGuest: ref.read(isGuestModeProvider),
      isSettled: settledNotifier.value,
    ),
    routes: [
      GoRoute(
        path: SplashScreen.route,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SplashScreen(),
      ),
      // Branches must be declared in ShellTab order.
      StatefulShellRoute(
        // Stacked like `indexedStack`, with the keyboard kept from hidden tabs.
        navigatorContainerBuilder: ShellBranchStack.containerBuilder,
        // A fade, since the splash and sign-in screens share the shell's mark.
        pageBuilder: (context, state, navigationShell) => CustomTransitionPage(
          key: state.pageKey,
          child: AppShell(navigationShell: navigationShell),
          transitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                ),
                child: child,
              ),
        ),
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: ShellTab.home.path,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _searchNavigatorKey,
            routes: [
              GoRoute(
                path: ShellTab.search.path,
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _channelsNavigatorKey,
            routes: [
              GoRoute(
                path: ShellTab.channels.path,
                builder: (context, state) => const ChannelsListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _activityNavigatorKey,
            routes: [
              GoRoute(
                path: ShellTab.activity.path,
                builder: (context, state) => const ActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _messagesNavigatorKey,
            routes: [
              GoRoute(
                path: ShellTab.messages.path,
                builder: (context, state) => const ChatsScreen(),
              ),
            ],
          ),
        ],
      ),
      // Full-screen routes outside the shell.
      GoRoute(
        path: '/post/:postId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final postId = state.pathParameters['postId']!;
          final focusReply = state.uri.queryParameters['focusReply'] == 'true';
          return PostDetailScreen(postId: postId, autoFocusReply: focusReply);
        },
      ),
      GoRoute(
        path: ChannelStatsScreen.route,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            ChannelStatsScreen(channelId: state.pathParameters['channelId']!),
      ),
      GoRoute(
        path: PostStatsScreen.route,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            PostStatsScreen(postId: state.pathParameters['postId']!),
      ),
      GoRoute(
        path: '/channel/:channelId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final channelId = state.pathParameters['channelId']!;
          final highlightStr = state.uri.queryParameters['highlight'];
          final highlightMessageId = highlightStr != null
              ? int.tryParse(highlightStr)
              : null;
          return ChannelProfileScreen(
            channelId: channelId,
            highlightMessageId: highlightMessageId,
          );
        },
      ),
      GoRoute(
        path: '/guest/channels',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GuestChannelsScreen(),
      ),
      GoRoute(
        path: ComposeScreen.route,
        parentNavigatorKey: _rootNavigatorKey,
        // Shared text goes in `extra` since it can be long.
        builder: (context, state) =>
            ComposeScreen(initialText: state.extra as String?),
      ),
      GoRoute(
        path: '/auth',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/chat/:chatId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final chatId = int.tryParse(state.pathParameters['chatId'] ?? '');
          // A malformed link falls back to the chat list.
          if (chatId == null) return const ChatsScreen();
          return ConversationScreen(chatId: chatId);
        },
      ),
      GoRoute(
        path: '/bookmarks',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BookmarksScreen(),
      ),
      // Another user's profile. `/profile` below is the user's own account.
      GoRoute(
        path: '/user/:userId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final userId = int.tryParse(state.pathParameters['userId'] ?? '');
          // A malformed link falls back to the chat list.
          if (userId == null) return const ChatsScreen();
          return UserProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileScreen(),
      ),
      // Reached from the drawer and the bell in the feed header.
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
      // Reachable while signed out; the sign-in screen links here.
      GoRoute(
        path: '/legal/:document',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            LegalScreen(documentId: state.pathParameters['document']!),
      ),
    ],
  );
});
