import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/presentation/widgets/media_viewer_chrome.dart';

void main() {
  Widget host(Widget child) => ProviderScope(child: MaterialApp(home: child));

  group('MediaPageDots', () {
    // A single image has nothing to page through, so dots would be noise.
    testWidgets('draws nothing for a single item', (tester) async {
      await tester.pumpWidget(host(const MediaPageDots(count: 1, index: 0)));
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('draws one dot per item in an album', (tester) async {
      await tester.pumpWidget(host(const MediaPageDots(count: 4, index: 2)));
      expect(find.byType(Container), findsNWidgets(4));
    });
  });

  group('MediaViewerChrome', () {
    testWidgets('always offers a way back', (tester) async {
      await tester.pumpWidget(host(const MediaViewerChrome(child: SizedBox())));

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    // Without a post there is no identity or action bar to show — the viewer
    // must still work rather than assuming one is always present.
    testWidgets('works with no post attached', (tester) async {
      await tester.pumpWidget(
        host(const MediaViewerChrome(child: SizedBox(key: Key('media')))),
      );

      expect(find.byKey(const Key('media')), findsOneWidget);
    });

    testWidgets('hiding the chrome keeps the media visible', (tester) async {
      await tester.pumpWidget(
        host(
          const MediaViewerChrome(
            showChrome: false,
            child: SizedBox(key: Key('media')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('media')), findsOneWidget);
    });

    // "Open with" was a filled black chip pinned over the top-right
    // corner of every picture — the same weight as the back button, for
    // something that is a thing you *can* do with a photo rather than the
    // thing you came here for. It belongs in the action bar at the bottom.
    group('the open-with control', () {
      testWidgets('is absent while the file is still arriving', (tester) async {
        await tester.pumpWidget(
          host(const MediaViewerChrome(child: SizedBox())),
        );

        expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);
      });

      // A viewer opened without a post has no action bar to carry it, so this
      // one case still rides in the top row — as a bare icon, not a chip.
      testWidgets('rides in the top row only when there is no post', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            const MediaViewerChrome(
              localPath: '/tmp/photo.jpg',
              child: SizedBox(),
            ),
          ),
        );

        final icon = find.byIcon(Icons.open_in_new_rounded);
        expect(icon, findsOneWidget);
        // Same size as the action bar's own icons, not the 22pt of a chip.
        expect(tester.widget<Icon>(icon).size, 18);
      });
    });
  });
}
