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

    // "Show more" only appears for posts that are clearly long.
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

  // A collapsed post ends at a word, with "Show more" straight after it.
  group('collapsedLength', () {
    test('cuts a long paragraph at the last word before the limit', () {
      final text = List.filled(100, 'word').join(' ');
      final end = collapsedLength(text);
      expect(end, lessThanOrEqualTo(kCollapsedPostChars));
      expect(text[end], ' ');
      expect(text.substring(0, end).endsWith('word'), isTrue);
    });

    test('stops at the line limit before the length limit', () {
      final text = List.filled(20, 'a').join('\n');
      final shown = text.substring(0, collapsedLength(text, maxLines: 3));
      expect('\n'.allMatches(shown).length, 2);
    });

    test('never splits an emoji', () {
      final text = '${'x' * (kCollapsedPostChars - 1)}😀 and more';
      final shown = text.substring(0, collapsedLength(text));
      expect(shown.endsWith('\uD83D'), isFalse);
    });
  });
}
