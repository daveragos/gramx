import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/features/activity/presentation/activity_providers.dart';
import 'package:gramx/app/app_shell.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/pending_posts_provider.dart';

/// The shell's `Scaffold` must not resize for the keyboard, or the bottom bar
/// rides up on top of it.
void main() {
  GoRouter shellRouter() => GoRouter(
    initialLocation: ShellTab.home.path,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          for (final tab in ShellTab.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: tab.path,
                  builder: (context, state) =>
                      Scaffold(body: Center(child: Text(tab.label))),
                ),
              ],
            ),
        ],
      ),
    ],
  );

  // A phone-sized window; the default test window is too small for the bar.
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(400, 900);
    view.padding = const FakeViewPadding(bottom: 34);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetDevicePixelRatio();
    view.resetPhysicalSize();
    view.resetPadding();
    view.resetViewInsets();
  });

  Widget host() => ProviderScope(
    // Keep the tab badges away from TDLib.
    overrides: [
      unreadChatCountProvider.overrideWith((ref) => 0),
      activityBadgeProvider.overrideWith((ref) => 0),
      // The shell's button asks; nothing here can post.
      canComposeProvider.overrideWithValue(false),
      pendingPostsProvider.overrideWith(_NoPendingPosts.new),
    ],
    child: MaterialApp.router(routerConfig: shellRouter()),
  );

  testWidgets('the shell does not resize for the keyboard', (tester) async {
    await tester.pumpWidget(host());

    final scaffold = shellScaffoldKey.currentWidget! as Scaffold;
    expect(scaffold.resizeToAvoidBottomInset, isFalse);
  });

  testWidgets('so the bar stays at the bottom when a keyboard opens', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    final before = tester.getRect(find.byType(BottomNavigationBar));

    // A keyboard, as far as the framework is concerned.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byType(BottomNavigationBar)), before);
  });

  testWidgets('and a branch keeps its own scaffold, which still resizes', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    // Branch scaffolds still resize, keeping focused fields above the keyboard.
    final branchScaffolds = tester
        .widgetList<Scaffold>(find.byType(Scaffold))
        .where((s) => s.key != shellScaffoldKey);

    expect(branchScaffolds, isNotEmpty);
    for (final scaffold in branchScaffolds) {
      expect(scaffold.resizeToAvoidBottomInset, isNot(false));
    }
  });
}

class _NoPendingPosts extends PendingPostsNotifier {
  @override
  List<Post> build() => const [];
}
