import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/core/widgets/expandable_text.dart';

void main() {
  group('shouldClampText', () {
    test('a short post is never clamped', () {
      expect(shouldClampText('A single line.'), isFalse);
    });

    test('an empty post has nothing to expand', () {
      expect(shouldClampText(''), isFalse);
    });

    // A "Show more" that reveals one extra line is a control that lies about
    // what it does, so the thresholds sit where a post is genuinely long.
    test('a post just under the line limit stays whole', () {
      final text = List.filled(kCollapsedPostLines - 1, 'line').join('\n');
      expect(shouldClampText(text), isFalse);
    });

    test('a post past the line limit clamps', () {
      final text = List.filled(kCollapsedPostLines + 2, 'line').join('\n');
      expect(shouldClampText(text), isTrue);
    });

    test('one very long paragraph clamps on length', () {
      expect(shouldClampText('x' * (kCollapsedPostChars + 1)), isTrue);
      expect(shouldClampText('x' * kCollapsedPostChars), isFalse);
    });

    test('the limits are configurable per surface', () {
      // The media viewer's caption clamps much sooner than a feed card.
      expect(shouldClampText('a\nb\nc\nd', maxLines: 3), isTrue);
    });
  });
}
