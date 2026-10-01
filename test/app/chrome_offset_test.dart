import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';

void main() {
  group('applyScrollDelta', () {
    // The header moves with the content instead of snapping at a threshold.
    test('moves one-to-one with the scroll', () {
      final next = applyScrollDelta(
        current: const ChromeOffset(),
        delta: 30,
        extent: 120,
        pixels: 200,
      );

      expect(next.hidden, closeTo(0.25, 0.0001));
      expect(
        next.animate,
        isFalse,
        reason: 'a drag must follow the thumb, not tween behind it',
      );
    });

    test('scrolling back up brings it back by the same amount', () {
      var offset = const ChromeOffset(hidden: 0.5);
      offset = applyScrollDelta(
        current: offset,
        delta: -30,
        extent: 120,
        pixels: 200,
      );

      expect(offset.hidden, closeTo(0.25, 0.0001));
    });

    test('never travels past its own height in either direction', () {
      final gone = applyScrollDelta(
        current: const ChromeOffset(hidden: 0.9),
        delta: 500,
        extent: 120,
        pixels: 900,
      );
      expect(gone.hidden, 1.0);

      final back = applyScrollDelta(
        current: const ChromeOffset(hidden: 0.1),
        delta: -500,
        extent: 120,
        pixels: 900,
      );
      expect(back.hidden, 0.0);
    });

    test('the top of the list always shows the chrome', () {
      final next = applyScrollDelta(
        current: const ChromeOffset(hidden: 1),
        delta: 40,
        extent: 120,
        pixels: -12,
      );

      expect(next.hidden, 0.0);
    });

    test('a zero extent leaves the offset alone', () {
      const current = ChromeOffset(hidden: 0.4);
      expect(
        applyScrollDelta(
          current: current,
          delta: 20,
          extent: 0,
          pixels: 100,
        ).hidden,
        0.4,
      );
    });
  });

  group('settleChrome', () {
    test('finishes the direction it was already going', () {
      expect(settleChrome(const ChromeOffset(hidden: 0.6)).hidden, 1.0);
      expect(settleChrome(const ChromeOffset(hidden: 0.4)).hidden, 0.0);
    });

    test('a settle is animated, so the gap is covered rather than jumped', () {
      expect(settleChrome(const ChromeOffset(hidden: 0.6)).animate, isTrue);
    });

    test('already at rest, nothing to animate', () {
      expect(settleChrome(const ChromeOffset()).animate, isFalse);
      expect(settleChrome(const ChromeOffset(hidden: 1)).animate, isFalse);
    });
  });

  group('chromeTiedOpacity', () {
    // The "N new posts" pill leaves as soon as the header starts to.
    test('fully visible while the header is', () {
      expect(chromeTiedOpacity(0), 1.0);
    });

    test('gone by the time the header is half retired', () {
      expect(chromeTiedOpacity(0.5), 0.0);
      expect(chromeTiedOpacity(1), 0.0);
    });

    test('fades rather than blinking out', () {
      expect(chromeTiedOpacity(0.25), closeTo(0.5, 0.0001));
    });
  });

  group('tabIsMoving', () {
    // Each tab reserves space for the header, so it must return as a swipe
    // starts.
    test('a drag counts from the first pixel', () {
      expect(
        tabIsMoving(position: 0.04, index: 0, indexIsChanging: false),
        isTrue,
      );
    });

    test('an animated switch counts', () {
      expect(
        tabIsMoving(position: 1.0, index: 1, indexIsChanging: true),
        isTrue,
      );
    });

    test('a tab at rest does not', () {
      expect(
        tabIsMoving(position: 2.0, index: 2, indexIsChanging: false),
        isFalse,
      );
    });

    test('floating-point noise at rest does not', () {
      expect(
        tabIsMoving(position: 1.000001, index: 1, indexIsChanging: false),
        isFalse,
      );
    });

    test('a drag backwards counts too', () {
      expect(
        tabIsMoving(position: 1.9, index: 2, indexIsChanging: false),
        isTrue,
      );
    });
  });

  group('ChromeOffset', () {
    // The "N new posts" pill and the semantics layer only need a yes/no.
    test('counts as hidden once it is more gone than not', () {
      expect(const ChromeOffset(hidden: 0.49).isHidden, isFalse);
      expect(const ChromeOffset(hidden: 0.5).isHidden, isTrue);
    });

    test(
      'equal offsets compare equal, so the notifier can skip no-op writes',
      () {
        expect(
          const ChromeOffset(hidden: 0.3),
          equals(const ChromeOffset(hidden: 0.3)),
        );
        expect(
          const ChromeOffset(hidden: 0.3),
          isNot(equals(const ChromeOffset(hidden: 0.3, animate: true))),
        );
      },
    );
  });
}
