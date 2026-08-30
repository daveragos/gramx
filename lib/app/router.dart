import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/app_shell.dart';
import 'package:gramx/features/guest/presentation/guest_channels_screen.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/app/auth_redirect.dart';
import 'package:gramx/app/splash_screen.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/auth/presentation/auth_screen.dart';
import 'package:gramx/features/bookmarks/presentation/bookmarks_screen.dart';
import 'package:gramx/features/channels/presentation/channel_profile_screen.dart';
import 'package:gramx/features/channels/presentation/channels_list_screen.dart';
import 'package:gramx/features/chats/presentation/chats_screen.dart';
import 'package:gramx/features/chats/presentation/conversation_screen.dart';
import 'package:gramx/features/chats/presentation/user_profile_screen.dart';
import 'package:gramx/features/compose/presentation/compose_screen.dart';
import 'package:gramx/features/compose/presentation/widgets/compose_fab.dart';
import 'package:gramx/features/feed/presentation/home_screen.dart';
import 'package:gramx/features/folders/presentation/folders_screen.dart';
import 'package:gramx/features/post_detail/presentation/post_detail_screen.dart';
import 'package:gramx/features/search/presentation/search_screen.dart';
import 'package:gramx/features/settings/presentation/settings_screen.dart';
import 'package:gramx/features/settings/presentation/profile_screen.dart';
import 'package:gramx/features/settings/presentation/legal_screen.dart';
import 'package:gramx/features/settings/presentation/diagnostics_screen.dart';

// Navigation keys for each branch
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _searchNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'search');
final _channelsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'channels');
final _messagesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'messages');

/// Auth-gated router.
///
/// The [redirect] callback checks the current auth step on every navigation:
///  - Loading → stay on current route (no redirect).
///  - Not authenticated → redirect to /auth.
///  - Authenticated + on /auth → redirect to /home.
///
/// [refreshListenable] is a ValueNotifier that fires whenever the auth step
/// changes, causing GoRouter to re-evaluate the redirect callback.
/// How long the app will wait on the splash for the session's state to settle.
///
/// Long enough to cover TDLib's own startup chatter, short enough that a reader
/// who really is signed out is not left looking at nothing. Only ever spent by
/// that reader: reaching `authenticated` leaves the splash immediately.
const Duration authSettleWindow = Duration(milliseconds: 700);

final routerProvider = Provider<GoRouter>((ref) {
  // Seed the notifier with the current auth step.
  final authNotifier = ValueNotifier<AuthStep>(
    ref.read(authControllerProvider).step,
  );

  // Listen (NOT watch) to auth state so the GoRouter instance is stable —
  // we only want to trigger refreshListenable, not rebuild the router.
  //
  // `hasSignedIn` is remembered here rather than derived: once a session has
  // existed in this run, a loading state means it is going away, and the
  // sign-in screen is where that belongs. See authRedirect.
  var hasSignedIn =
      ref.read(authControllerProvider).step == AuthStep.authenticated;

  ref.listen<AuthState>(authControllerProvider, (_, next) {
    if (next.step == AuthStep.authenticated) hasSignedIn = true;
    authNotifier.value = next.step;
  });

  // Entering or leaving guest mode changes which routes are reachable, so the
  // redirect has to be re-evaluated when it flips — otherwise the reader sits
  // on the screen they just left. Merged with the auth notifier rather than
  // folded into it: they are two independent reasons to re-decide.
  final guestNotifier = ValueNotifier<bool>(ref.read(isGuestModeProvider));
  ref.listen<bool>(
    isGuestModeProvider,
    (_, next) => guestNotifier.value = next,
  );

  // Whether the session's state can be believed yet.
  //
  // TDLib announces several authorization states while it starts, and one of
  // them can be a sign-in step it supersedes a moment later — which is what
  // flashed the sign-in screen at a signed-in reader on the way to their feed.
  // Until this flips, the app waits on the splash rather than acting on an
  // answer that is about to change. `authenticated` short-circuits it, so the
  // window is only ever *spent* by somebody who turns out to be signed out.
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
    // Neither the feed nor the sign-in screen: see SplashScreen for why the
    // app opens on a destination that means "not decided yet".
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
          // Messages tab
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
      // Detail routes (outside shell — full screen)
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
      // Guest mode's own screen. Outside the shell, like /folders: it is a
      // place you go to and come back from, not a tab you live in.
      GoRoute(
        path: '/guest/channels',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GuestChannelsScreen(),
      ),
      // Writing a post. Root-level and full screen, like the media viewers:
      // it covers the shell rather than living inside a tab.
      GoRoute(
        path: ComposeFab.route,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ComposeScreen(),
      ),
      GoRoute(
        path: '/auth',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AuthScreen(),
      ),
      // One conversation. Root-level and full screen: it covers the shell the
      // way the post and channel screens do, rather than sitting under the
      // bottom bar with a keyboard over it.
      GoRoute(
        path: '/chat/:chatId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final chatId = int.tryParse(state.pathParameters['chatId'] ?? '');
          // An unparseable id is a malformed link, not a chat. The list is
          // where somebody who followed one should land.
          if (chatId == null) return const ChatsScreen();
          return ConversationScreen(chatId: chatId);
        },
      ),
      // Bookmarks left the bottom bar for the drawer when Messages took its
      // every existing link to it keeps working.
      GoRoute(
        path: '/bookmarks',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BookmarksScreen(),
      ),
      // Somebody else's profile. `/profile` below is the reader's own account
      // and is a different screen entirely; these are two nouns that happen to
      // share a word.
      GoRoute(
        path: '/user/:userId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final userId = int.tryParse(state.pathParameters['userId'] ?? '');
          // A malformed link is not a person. The messages list is where
          // somebody who followed one should land.
          if (userId == null) return const ChatsScreen();
          return UserProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileScreen(),
      ),
      // What the app knows about its own failures. A pushed route rather than a
      // section of Settings: it is a list that can be long, and it is the one
      // screen somebody is sent to rather than one they browse.
      GoRoute(
        path: DiagnosticsScreen.route,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DiagnosticsScreen(),
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
        builder: (context, state) =>
            LegalScreen(documentId: state.pathParameters['document']!),
      ),
    ],
  );
});
