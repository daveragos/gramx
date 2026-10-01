import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/presentation/widgets/full_screen_image_viewer.dart';

void main() {
  // An unzoomed picture must not pan when dragged.
  group('a picture at 1:1', () {
    Widget viewer() => ProviderScope(
      child: MaterialApp(
        home: FullScreenImageViewer(
          items: const [ViewerImage(path: '/nowhere/one.png')],
          initialIndex: 0,
          tag: 'one',
        ),
      ),
    );

    testWidgets('cannot be panned, so a drag is a swipe or a pull-down', (
      tester,
    ) async {
      await tester.pumpWidget(viewer());
      await tester.pump();

      final zoom = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(zoom.panEnabled, isFalse);
    });

    testWidgets('pans again once it is zoomed', (tester) async {
      await tester.pumpWidget(viewer());
      await tester.pump();

      final picture = find.byType(InteractiveViewer);
      await tester.tap(picture);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(picture);
      // Past the double-tap window, so its timer is not left pending.
      await tester.pump(const Duration(milliseconds: 400));

      final zoom = tester.widget<InteractiveViewer>(picture);
      expect(zoom.panEnabled, isTrue);
    });
  });

  // Panning is unbounded while zoomed; on release the picture settles back to
  // cover the screen.
  group('keepCoveringViewport', () {
    const viewport = Size(400, 800);

    Matrix4 at(double scale, double x, double y) => Matrix4.identity()
      ..translateByDouble(x, y, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);

    test('a picture pulled past its left edge comes back to it', () {
      final settled = keepCoveringViewport(at(2, 10, 0), viewport);
      expect(settled.getTranslation().x, 0);
    });

    test('a picture pulled past its right edge comes back to it', () {
      final settled = keepCoveringViewport(at(2, -2000, -50), viewport);
      // At 2× the box is 800 wide, so -400 is as far as it may go.
      expect(settled.getTranslation().x, -400);
      expect(settled.getTranslation().y, -50, reason: 'in bounds, untouched');
    });

    test('a picture within bounds is returned as it is', () {
      final transform = at(3, -100, -300);
      expect(keepCoveringViewport(transform, viewport), same(transform));
    });

    test('at 1:1 the only place is centred', () {
      final settled = keepCoveringViewport(at(1, -30, 40), viewport);
      expect(settled.getTranslation().x, 0);
      expect(settled.getTranslation().y, 0);
    });

    test('the zoom itself is untouched', () {
      final settled = keepCoveringViewport(at(2.5, 50, 50), viewport);
      expect(settled.getMaxScaleOnAxis(), closeTo(2.5, 1e-9));
    });
  });
}
