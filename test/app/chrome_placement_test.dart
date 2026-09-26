import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/core/widgets/loading_skeleton.dart';

/// Two screens that had a piece of furniture on the wrong
/// side of the chrome boundary.
///
/// The rule both of them broke is the same one: anything drawn at a *fixed*
/// offset from the top of the body stays put when the header slides away, and
/// what is left behind it is a band of nothing. If it should leave with the
/// header, it belongs to the header.
void main() {
  /// Drives the chrome all the way off, the way scrolling down does.
  void retireChrome(WidgetTester tester) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChromeScaffold)),
    );
    container
        .read(chromeOffsetProvider.notifier)
        .onScroll(delta: 400, extent: 100, pixels: 400);
  }

  group('a strip that belongs to the header leaves with it', () {
    Widget harness() => ProviderScope(
      child: MaterialApp(
        home: ChromeScaffold(
          header: const ChromeHeaderRow(title: 'Messages'),
          headerBottomHeight: 56,
          headerBottom: const SizedBox(height: 56, child: Text('search')),
          body: (context, top, bottom) => ListView.builder(
            padding: EdgeInsets.only(top: top, bottom: bottom),
            itemCount: 40,
            itemBuilder: (_, i) => SizedBox(height: 60, child: Text('row $i')),
          ),
        ),
      ),
    );

    testWidgets('starts on screen, above the first row', (tester) async {
      await tester.pumpWidget(harness());

      expect(find.text('search'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('row 0')).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.text('search')).dy),
      );
    });

    // The bug: the field sat in the body under a fixed `SizedBox(topPadding)`,
    // so retiring the chrome took the title row, the bottom bar and the button
    // away and left the field alone under an empty band.
    testWidgets('travels off with the title row rather than staying put', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      final before = tester.getTopLeft(find.text('search')).dy;

      retireChrome(tester);
      await tester.pumpAndSettle();

      final after = tester.getTopLeft(find.text('search')).dy;
      expect(after, lessThan(before));
      // Gone, not merely nudged: it has cleared the top of the screen.
      expect(after, lessThan(0));
    });
  });

  group('the first-load skeleton keeps the header', () {
    testWidgets('draws the real header over a shimmering body', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ChromeScaffold(
              observeScroll: false,
              headerBottomHeight: 46,
              header: const ChromeHeaderRow(title: 'gramX', centerTitle: true),
              headerBottom: const FolderTabsSkeleton(),
              body: (context, top, bottom) => FeedSkeleton(
                padding: EdgeInsets.only(top: top, bottom: bottom),
              ),
            ),
          ),
        ),
      );

      // The wordmark is real from the first frame; only what is genuinely
      // unknown — which folders this account has — is a placeholder.
      expect(find.text('gramX'), findsOneWidget);
      expect(find.byType(FolderTabsSkeleton), findsOneWidget);
      expect(find.byType(PostSkeleton), findsWidgets);
    });

    testWidgets('and the first card starts below it', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ChromeScaffold(
              observeScroll: false,
              headerBottomHeight: 46,
              header: const ChromeHeaderRow(title: 'gramX', centerTitle: true),
              headerBottom: const FolderTabsSkeleton(),
              body: (context, top, bottom) => FeedSkeleton(
                padding: EdgeInsets.only(top: top, bottom: bottom),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.byType(PostSkeleton).first).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.text('gramX')).dy),
      );
    });
  });
}
