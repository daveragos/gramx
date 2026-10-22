import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/widgets/app_glyphs.dart';
import 'package:gramx/features/activity/presentation/activity_providers.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/pending_posts_provider.dart';

void main() {
  group('Glyph', () {
    testWidgets('draws every glyph, outlined and solid', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              children: [
                for (final glyph in AppGlyphs.values) ...[
                  Glyph(glyph),
                  Glyph(glyph, filled: true),
                ],
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Glyph), findsNWidgets(AppGlyphs.values.length * 2));
    });

    testWidgets('takes its size from the icon theme, like an Icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: IconTheme(
              data: IconThemeData(size: 30),
              child: Glyph(AppGlyphs.reply),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(Glyph)), const Size.square(30));
    });

    testWidgets('is hidden from screen readers, which its control labels', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: Glyph(AppGlyphs.share))),
      );

      expect(
        tester.getSemantics(find.byType(Glyph)),
        isNot(matchesSemantics(label: 'share')),
      );
      handle.dispose();
    });
  });

  group('ShellTabBar', () {
    Widget host({required int current, required ValueChanged<int> onTap}) =>
        ProviderScope(
          // Keep the tab badges away from TDLib.
          overrides: [
            unreadChatCountProvider.overrideWith((ref) => 0),
            activityBadgeProvider.overrideWith((ref) => 0),
            pendingPostsProvider.overrideWith(_NoPendingPosts.new),
          ],
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: ShellTabBar(
                currentIndex: current,
                onTap: onTap,
              ),
            ),
          ),
        );

    // The icons spread to the bar's ends, but each tab still answers in a
    // fifth of the bar.
    testWidgets('a tap anywhere in a tab\'s share goes to that tab', (
      tester,
    ) async {
      final tapped = <int>[];
      await tester.pumpWidget(host(current: 0, onTap: tapped.add));

      final bar = tester.getRect(find.byType(ShellTabBar));
      final share = bar.width / ShellTab.values.length;
      for (final tab in ShellTab.values) {
        // Near the end of the tab's share, away from its icon.
        await tester.tapAt(
          Offset(bar.left + share * (tab.index + 0.9), bar.top + 8),
        );
      }

      expect(tapped, [for (final tab in ShellTab.values) tab.index]);
    });

    testWidgets('names each tab and marks the selected one', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(current: ShellTab.search.index, onTap: (_) {}),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel(ShellTab.search.label)),
        matchesSemantics(
          label: ShellTab.search.label,
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(ShellTab.home.label)),
        matchesSemantics(
          label: ShellTab.home.label,
          isButton: true,
          hasSelectedState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });
  });
}

class _NoPendingPosts extends PendingPostsNotifier {
  @override
  List<Post> build() => const [];
}
