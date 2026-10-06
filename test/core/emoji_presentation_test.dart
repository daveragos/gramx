import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/core/text/emoji_presentation.dart';

void main() {
  test('the heart Telegram sends is drawn as the red emoji', () {
    expect(emojiForDisplay('❤'), '❤️');
    expect(emojiForDisplay('✍'), '✍️');
  });

  test('a sequence led by an old symbol gets the selector after it', () {
    expect(emojiForDisplay('❤‍\u{1F525}'), '❤️‍\u{1F525}');
  });

  test('emoji that already draw in color are left alone', () {
    expect(emojiForDisplay('\u{1F44D}'), '\u{1F44D}');
    expect(emojiForDisplay('\u{1F525}'), '\u{1F525}');
    expect(emojiForDisplay('❤️'), '❤️');
    expect(emojiForDisplay('1️⃣'), '1️⃣');
    expect(emojiForDisplay(''), '');
  });
}
