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

/// A router for the drawer's two kinds of entry: tab entries hand an index to
/// the shell, and the rest push a root route.
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
    // Stubs: only the destination matters here.
    GoRoute(
      path: '/bookmarks',
      builder: (context, state) => const Scaffold(body: Text('bookmarks')),
    ),
  ],
);

Widget host(void Function(ShellTab) onSelectTab) => ProviderScope(
  // Keep the drawer's providers away from TDLib and the database.
  overrides: [
    // The real provider goes through the auth controller and a TDLib client.
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
  // The drawer is a sibling of the navigation shell, so
  // `StatefulNavigationShell.of` can't find it; the shell passes the action in.
  group('drawer tab entries', () {
    testWidgets('messages asks the shell to switch', (tester) async {
      final chosen = <ShellTab>[];
      await tester.pumpWidget(host(chosen.add));
      await openDrawer(tester);

      await tester.tap(find.text(AppStrings.messagesTab));
      await tester.pumpAndSettle();

      expect(chosen, [ShellTab.messages]);
    });

    // Bookmarks is a pushed route, not a shell branch.
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
