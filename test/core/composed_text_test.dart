import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/core/text/composed_text.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';

TextEntity bold(int offset, int length) =>
    TextEntity(offset: offset, length: length, type: TextEntityType.bold);

TextEntity italic(int offset, int length) =>
    TextEntity(offset: offset, length: length, type: TextEntityType.italic);

/// The text each mark covers, to read the expectations at a glance.
List<String> marked(ComposedText composed) => [
  for (final e in composed.entities)
    '${e.type.name}:${composed.text.substring(e.offset, e.offset + e.length)}',
];

void main() {
  group('editing formatted text', () {
    // "big news today", with "news" in bold.
    final base = ComposedText('big news today', [bold(4, 4)]);

    test('typing before a mark moves it along', () {
      expect(marked(base.edited('very big news today', cursor: 5)), [
        'bold:news',
      ]);
    });

    test('typing inside a mark makes the new text part of it', () {
      expect(marked(base.edited('big nexws today', cursor: 7)), ['bold:nexws']);
    });

    test('typing right after a mark stays plain', () {
      expect(marked(base.edited('big news! today', cursor: 9)), ['bold:news']);
    });

    test('typing right before a mark stays plain', () {
      expect(marked(base.edited('big hot news today', cursor: 8)), [
        'bold:news',
      ]);
    });

    test('deleting part of a mark shrinks it', () {
      expect(marked(base.edited('big nes today', cursor: 6)), ['bold:nes']);
    });

    test('deleting all of a mark removes it', () {
      expect(base.edited('big  today', cursor: 4).entities, isEmpty);
    });

    test('the caret places a repeated letter where it was typed', () {
      final repeated = ComposedText('aa b', [bold(0, 2)]);
      // An "a" typed at the start: the text alone reads it as one at the end.
      expect(repeated.edited('aaa b', cursor: 1).entities.single, bold(1, 2));
    });

    test('replacing text that starts inside a mark keeps the rest marked', () {
      expect(marked(base.edited('big nexus today', cursor: 9)), ['bold:nexus']);
    });
  });

  group('putting a format on a selection', () {
    const plain = ComposedText('one two three');

    test('marks the selection', () {
      expect(marked(plain.withFormat(TextEntityType.bold, 4, 7)), ['bold:two']);
    });

    test('joins a mark it overlaps or meets', () {
      final once = plain.withFormat(TextEntityType.bold, 0, 3);
      final twice = once.withFormat(TextEntityType.bold, 3, 7);
      expect(marked(twice), ['bold:one two']);
    });

    test('leaves other kinds of mark as they are', () {
      final both = plain
          .withFormat(TextEntityType.italic, 0, 7)
          .withFormat(TextEntityType.bold, 4, 13);
      expect(marked(both), ['italic:one two', 'bold:two three']);
    });

    test('a link replaces the link already there', () {
      final linked = plain
          .withFormat(TextEntityType.textUrl, 0, 7, url: 'https://a.example')
          .withFormat(TextEntityType.textUrl, 4, 7, url: 'https://b.example');
      expect(marked(linked), ['textUrl:one ', 'textUrl:two']);
      expect(linked.entities.last.url, 'https://b.example');
    });

    test('taking it off the middle splits the mark', () {
      final all = plain.withFormat(TextEntityType.bold, 0, 13);
      expect(marked(all.withoutFormat(TextEntityType.bold, 4, 7)), [
        'bold:one ',
        'bold: three',
      ]);
    });

    test('knows when all of a range carries a format', () {
      final split = ComposedText('one two three', [bold(0, 4), bold(4, 3)]);
      expect(split.has(TextEntityType.bold, 0, 7), isTrue);
      expect(split.has(TextEntityType.bold, 0, 8), isFalse);
      expect(split.has(TextEntityType.italic, 0, 3), isFalse);
    });

    test('plain takes every mark off the range', () {
      final both = ComposedText('one two', [bold(0, 7), italic(4, 3)]);
      expect(marked(both.plain(3, 7)), ['bold:one']);
    });
  });

  group('preparing it to send', () {
    test('trimming moves the marks with the text', () {
      final padded = ComposedText('  hello world \n', [
        bold(2, 5),
        italic(7, 7),
      ]);
      expect(marked(padded.trimmed()), ['bold:hello', 'italic: world']);
    });

    test('trimming whitespace alone leaves nothing', () {
      expect(ComposedText('   ', [bold(0, 3)]).trimmed().isEmpty, isTrue);
    });

    test('a replacement stretches the marks around it', () {
      final text = ComposedText('ask @Trok now, @Trok', [
        bold(0, 9),
        italic(15, 5),
      ]);
      final resolved = text.replaceAll(RegExp('@Trok'), '@trokkai');
      expect(resolved.text, 'ask @trokkai now, @trokkai');
      expect(marked(resolved), ['bold:ask @trokkai', 'italic:@trokkai']);
    });
  });

  test('editing keeps only the marks a client may send', () {
    final editable = ComposedText.editable('see https://x.example now', [
      const TextEntity(offset: 4, length: 17, type: TextEntityType.url),
      bold(0, 3),
      // Runs past the end, as stale marks can.
      italic(20, 30),
    ]);
    expect(marked(editable), ['bold:see']);
  });
}
