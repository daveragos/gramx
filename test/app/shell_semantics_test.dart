import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/widgets/shell_branch_stack.dart';

/// Records the keyboard space and height it was laid out with, and counts
/// taps, so a lost state shows as a reset count.
class _Probe extends StatefulWidget {
  final String name;
  final Map<String, ({double inset, double height})> seen;

  const _Probe(this.name, this.seen);

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  int taps = 0;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          widget.seen[widget.name] = (
            inset: inset,
            height: constraints.maxHeight,
          );
          return Column(
            children: [
              TextButton(
                onPressed: () => setState(() => taps++),
                child: Text('${widget.name} $taps'),
              ),
              if (widget.name == 'search') const TextField(),
            ],
          );
        },
      ),
    );
  }
}

void main() {
  // With a screen reader on, a hidden tab resized for the keyboard set off a
  // Flutter bug (flutter/flutter#192724): typing a search resized the hidden
  // Home feed, and building its semantics threw. Hidden tabs now keep their
  // size; the tab on screen still makes room for the keyboard.
  group('ShellBranchStack', () {
    late Map<String, ({double inset, double height})> seen;

    Future<void> pumpShell(WidgetTester tester) async {
      seen = {};
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          StatefulShellRoute(
            navigatorContainerBuilder: ShellBranchStack.containerBuilder,
            builder: (context, state, shell) => Scaffold(
              resizeToAvoidBottomInset: false,
              body: shell,
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: shell.currentIndex,
                onTap: shell.goBranch,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.search),
                    label: 'Search',
                  ),
                ],
              ),
            ),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/home',
                    builder: (_, _) => _Probe('home', seen),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/search',
                    builder: (_, _) => _Probe('search', seen),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    }

    Future<void> keyboard(WidgetTester tester, {required bool up}) async {
      if (up) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      } else {
        tester.view.resetViewInsets();
      }
      await tester.pumpAndSettle();
    }

    testWidgets('keeps the keyboard from a hidden tab', (tester) async {
      addTearDown(tester.view.resetViewInsets);
      await pumpShell(tester);
      final homeHeight = seen['home']!.height;

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      await keyboard(tester, up: true);

      expect(seen['home']!.inset, 0);
      expect(seen['home']!.height, homeHeight);
      // The view's insets are in physical pixels.
      expect(seen['search']!.inset, 900 / tester.view.devicePixelRatio);
      expect(seen['search']!.height, lessThan(homeHeight));
    });

    testWidgets('a tab keeps its state across switches', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.text('home 0'));
      await tester.pump();

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('home 1'), findsOneWidget);
    });

    testWidgets('builds its semantics through a search with a screen reader', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      addTearDown(tester.view.resetViewInsets);
      await pumpShell(tester);

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await keyboard(tester, up: true);
      await keyboard(tester, up: false);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });
}
