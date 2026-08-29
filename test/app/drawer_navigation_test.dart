import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/widgets/app_drawer.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/guest/domain/reader_capabilities.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:handy_tdlib/api.dart' as td;

/// A router with just enough in it for the drawer's two kinds of entry.
///
/// The drawer does two different things: tab entries hand an index back to the
/// shell, and everything else pushes a root route. Testing only the first left
/// the second unexercised, which is how "bookmarks pushes now" could have gone
/// out reaching for a GoRouter that was not there.
GoRouter testRouter(void Function(ShellTab) onSelectTab) => GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/home',
      builder: (context, state) => Scaffold(
        drawer: AppDrawer(onSelectTab: onSelectTab),
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    // Stubs: this test is about where the drawer sends you, not about what
    // is drawn when you get there.
    GoRoute(
      path: '/bookmarks',
      builder: (context, state) => const Scaffold(body: Text('bookmarks')),
    ),
  ],
);

Widget host(void Function(ShellTab) onSelectTab) => ProviderScope(
  // The drawer shows counts and an account, so those providers exist —
  // none of them should reach TDLib or a database to answer a tap.
  overrides: [
    // The drawer hides Saved Messages from a guest, and asking whether this
    // reader is one runs through the auth controller — which builds a real
    // TDLib client. Overridden so the drawer's *navigation* can be tested
    // without one; none of these tests are about capabilities.
    readerCapabilitiesProvider.overrideWith(
      (ref) => ReaderCapabilities.signedIn,
    ),
    channelsProvider.overrideWith((ref) async => const <Channel>[]),
    foldersProvider.overrideWith(
      (ref) => Stream.value(const <td.ChatFolderInfo>[]),
    ),
    activeAccountProvider.overrideWith(
      (ref) => Stream.value(
        Account(
          id: 1,
          telegramUserId: '1',
          displayName: 'Reader',
          isActive: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ),
    ),
  ],
  child: MaterialApp.router(routerConfig: testRouter(onSelectTab)),
);

Future<void> openDrawer(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  // The reported failure: these two closed the drawer and did nothing else.
  // `StatefulNavigationShell.of` searches the widget tree, and the drawer is a
  // sibling of the navigation shell rather than a descendant of it, so the
  // lookup could never have succeeded. The shell hands the action down now.
  group('drawer tab entries', () {
    testWidgets('messages asks the shell to switch', (tester) async {
      final chosen = <ShellTab>[];
      await tester.pumpWidget(host(chosen.add));
      await openDrawer(tester);

      await tester.tap(find.text(AppStrings.messagesTab));
      await tester.pumpAndSettle();

      expect(chosen, [ShellTab.messages]);
    });

    // Bookmarks left the bottom bar when Messages took the fourth slot, so it
    // is a pushed route now rather than a branch. Asking the shell to switch to
    // a tab that no longer exists is exactly the bug the enum is pinned
    // against, so this asserts it does *not* happen.
    testWidgets('bookmarks pushes its route instead of switching tabs', (
      tester,
    ) async {
      final chosen = <ShellTab>[];
      await tester.pumpWidget(host(chosen.add));
      await openDrawer(tester);

      await tester.tap(find.text(AppStrings.drawerBookmarks));
      await tester.pumpAndSettle();

      expect(chosen, isEmpty, reason: 'bookmarks is no longer a tab');
      expect(find.text('bookmarks'), findsOneWidget);
    });

    testWidgets('subscribed channels asks the shell to switch', (tester) async {
      final chosen = <ShellTab>[];
      await tester.pumpWidget(host(chosen.add));
      await openDrawer(tester);

      await tester.tap(find.text(AppStrings.drawerChannels));
      await tester.pumpAndSettle();

      expect(chosen, [ShellTab.channels]);
    });

    testWidgets('and the drawer closes behind them', (tester) async {
      await tester.pumpWidget(host((_) {}));
      await openDrawer(tester);
      expect(find.text(AppStrings.drawerChannels), findsOneWidget);

      await tester.tap(find.text(AppStrings.drawerChannels));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.drawerChannels), findsNothing);
    });
  });
}
