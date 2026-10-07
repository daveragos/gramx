import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The shell's tabs, stacked as `StatefulShellRoute.indexedStack` stacks
/// them, except that only the tab on screen sees the keyboard.
///
/// A hidden tab is still laid out, and resized for the keyboard along with
/// the one being typed in. With a screen reader on, Flutter 3.47 can lose
/// track of a hidden branch that changes size, and throws building its
/// semantics ("Null check operator used on a null value" in
/// `_updateSemanticsNodeGeometry`; flutter/flutter#192724). Typing a search
/// resized the hidden Home feed and set it off. A hidden tab has no use for
/// the keyboard's space, so it keeps its size.
class ShellBranchStack extends StatelessWidget {
  final int currentIndex;
  final List<Widget> children;

  const ShellBranchStack({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  /// For `StatefulShellRoute(navigatorContainerBuilder:)`.
  static Widget containerBuilder(
    BuildContext context,
    StatefulNavigationShell navigationShell,
    List<Widget> children,
  ) => ShellBranchStack(
    currentIndex: navigationShell.currentIndex,
    children: children,
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final withoutKeyboard = media.removeViewInsets(removeBottom: true);
    return IndexedStack(
      index: currentIndex,
      children: [
        for (var i = 0; i < children.length; i++)
          // Always wrapped, so a tab coming on screen keeps its state.
          MediaQuery(
            data: i == currentIndex ? media : withoutKeyboard,
            child: Offstage(
              offstage: i != currentIndex,
              child: TickerMode(enabled: i == currentIndex, child: children[i]),
            ),
          ),
      ],
    );
  }
}
