import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/widgets/app_drawer.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:handy_tdlib/api.dart' as td;

Widget host(void Function(ShellTab) onSelectTab) => ProviderScope(
      // The drawer shows counts and an account, so those providers exist —
      // none of them should reach TDLib or a database to answer a tap.
      overrides: [
        channelsProvider.overrideWith((ref) async => const <Channel>[]),
        foldersProvider
            .overrideWith((ref) => Stream.value(const <td.ChatFolderInfo>[])),
        activeAccountProvider.overrideWith((ref) => Stream.value(Account(
              id: 1,
              telegramUserId: '1',
              displayName: 'Reader',
              isActive: true,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ))),
      ],
      child: MaterialApp(
        home: Scaffold(
          drawer: AppDrawer(onSelectTab: onSelectTab),
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              child: const Text('open'),
            ),
          ),
        ),
      ),
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
    testWidgets('bookmarks asks the shell to switch', (tester) async {
      final chosen = <ShellTab>[];
      await tester.pumpWidget(host(chosen.add));
      await openDrawer(tester);

      await tester.tap(find.text(AppStrings.drawerBookmarks));
      await tester.pumpAndSettle();

      expect(chosen, [ShellTab.bookmarks]);
    });

    testWidgets('subscribed channels asks the shell to switch',
        (tester) async {
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
