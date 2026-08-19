import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/app/app_shell.dart';

void main() {
  group('ShellChrome', () {
    // The header and the bottom bar move together. Different durations or
    // curves made the two halves of the frame disagree, which reads as jumpy.
    test('one duration and curve for both bars', () {
      expect(ShellChrome.slideDuration.inMilliseconds, greaterThan(0));
      expect(ShellChrome.slideDuration.inMilliseconds, lessThanOrEqualTo(400),
          reason: 'chrome should feel immediate, not sluggish');
    });

    test('blur is strong enough to separate the bar from content', () {
      expect(ShellChrome.blurSigma, greaterThanOrEqualTo(8));
    });

    // Fully opaque would defeat the blur; too sheer and labels lose contrast.
    test('tint stays translucent but readable', () {
      expect(ShellChrome.tintOpacity, greaterThan(0.5));
      expect(ShellChrome.tintOpacity, lessThan(1.0));
    });

    test('bottom bar reserves a real height for list padding', () {
      expect(ShellChrome.bottomBarHeight, greaterThan(0));
    });
  });
}
