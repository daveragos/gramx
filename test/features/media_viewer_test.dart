import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/presentation/widgets/media_viewer_chrome.dart';

void main() {
  Widget host(Widget child) => ProviderScope(child: MaterialApp(home: child));

  group('MediaPageDots', () {
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

    // Without a post there is no identity or action bar to show.
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

    // "Open with" lives in the bottom action bar.
    group('the open-with control', () {
      testWidgets('is absent while the file is still arriving', (tester) async {
        await tester.pumpWidget(
          host(const MediaViewerChrome(child: SizedBox())),
        );

        expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);
      });

      // Without a post there is no action bar, so it sits in the top row as a
      // bare icon.
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
        // Same size as the action bar's icons.
        expect(tester.widget<Icon>(icon).size, 18);
      });
    });
  });
}
