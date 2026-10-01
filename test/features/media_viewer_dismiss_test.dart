import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/presentation/widgets/media_viewer_chrome.dart';

void main() {
  // Only a mostly vertical drag closes the viewer, not a slanted page swipe.
  group('what counts as a vertical drag', () {
    const slop = 18.0;
    final isVertical = MostlyVerticalDragGestureRecognizer.isMostlyVertical;

    test('straight down is', () {
      expect(isVertical(const Offset(0, 40), slop), isTrue);
    });

    test('a slanted page swipe is not', () {
      expect(isVertical(const Offset(-60, 30), slop), isFalse);
    });

    test('a true diagonal goes to the page', () {
      expect(isVertical(const Offset(40, 40), slop), isFalse);
    });

    test('short of the slop it is nothing yet', () {
      expect(isVertical(const Offset(0, 10), slop), isFalse);
    });
  });

  group('DragToDismiss', () {
    late PageController pages;

    Widget host() {
      pages = PageController();
      return MaterialApp(
        home: Scaffold(
          body: DragToDismiss(
            child: PageView(
              controller: pages,
              children: const [
                ColoredBox(color: Colors.red, key: Key('one')),
                ColoredBox(color: Colors.blue, key: Key('two')),
              ],
            ),
          ),
        ),
      );
    }

    // The vertical recogniser sees the slop before the page does, so it must
    // not claim this swipe.
    testWidgets('a slanted swipe turns the page and moves nothing else', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      final before = tester.getTopLeft(find.byType(PageView));

      await tester.drag(find.byKey(const Key('one')), const Offset(-450, 60));
      await tester.pumpAndSettle();

      expect(pages.page, 1);
      expect(tester.getTopLeft(find.byType(PageView)), before);
    });

    testWidgets('a pull down follows the finger', (tester) async {
      await tester.pumpWidget(host());
      final before = tester.getTopLeft(find.byType(PageView));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('one'))),
      );
      await gesture.moveBy(const Offset(4, 30));
      await gesture.moveBy(const Offset(2, 30));
      await tester.pump();

      expect(
        tester.getTopLeft(find.byType(PageView)).dy,
        greaterThan(before.dy),
      );
      expect(pages.page, 0);

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
