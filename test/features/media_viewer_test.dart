import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/presentation/widgets/media_viewer_chrome.dart';

void main() {
  Widget host(Widget child) => ProviderScope(
        child: MaterialApp(home: child),
      );

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
      await tester.pumpWidget(host(
        const MediaViewerChrome(child: SizedBox()),
      ));

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    // Without a post there is no identity or action bar to show — the viewer
    // must still work rather than assuming one is always present.
    testWidgets('works with no post attached', (tester) async {
      await tester.pumpWidget(host(
        const MediaViewerChrome(child: SizedBox(key: Key('media'))),
      ));

      expect(find.byKey(const Key('media')), findsOneWidget);
    });

    testWidgets('hiding the chrome keeps the media visible', (tester) async {
      await tester.pumpWidget(host(
        const MediaViewerChrome(
          showChrome: false,
          child: SizedBox(key: Key('media')),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('media')), findsOneWidget);
    });
  });
}
