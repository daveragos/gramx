import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/app_shell.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/pending_posts_provider.dart';

/// The bottom bar rode up on top of the keyboard.
///
/// The bar is pinned to the bottom of the shell's own `Scaffold` body, so
/// letting that Scaffold shrink for the keyboard carried the bar with it — a
/// tab strip sitting on the keyboard's top edge on every screen with a field
/// in it. The fix is one flag, and it is the sort of flag that gets
/// "tidied away" later by somebody who does not know what it is holding up.
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

  // The bar reserves its own height plus the gesture inset, and the default
  // test window has neither the inset nor the room — so the tab labels
  // overflow a surface that is fine on any real phone. A phone-shaped window
  // is what these assertions are about anyway.
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
    // The messages tab badges itself from the live chat list, which would
    // reach for a TDLib client this test has no use for.
    overrides: [
      unreadChatCountProvider.overrideWith((ref) => 0),
      // The Home icon watches for waiting posts; this test is about the
      // bars, so the real notifier — which listens to the sync service and
      // would drag TDLib into the test — is stood down.
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

    // What a keyboard is, as far as the framework is concerned.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byType(BottomNavigationBar)), before);
  });

  testWidgets('and a branch keeps its own scaffold, which still resizes', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    // The branch's Scaffold is a different one from the shell's, and nothing
    // here has turned its own resizing off — which is what keeps a field being
    // typed into out from under the keyboard.
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
