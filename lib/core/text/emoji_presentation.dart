import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// [emoji] as it should be drawn: in color. Use with [emojiStyle].
///
/// Telegram's reaction keys leave out the variation selector U+FE0F. Without
/// it "❤" and other older symbols draw as plain text glyphs in the text
/// color, so the red heart came out white on a dark theme. Display only:
/// TDLib wants a reaction key exactly as it sent it.
String emojiForDisplay(String emoji) {
  final runes = emoji.runes.toList();
  if (runes.isEmpty || runes.contains(_presentationSelector)) return emoji;

  // Emoji from U+1F000 up already draw in color.
  final first = runes.first;
  if (first >= 0x1F000) return emoji;

  if (runes.length == 1) {
    return String.fromCharCodes([first, _presentationSelector]);
  }
  // A sequence such as heart on fire, ❤ + ZWJ + 🔥.
  if (runes[1] == _zeroWidthJoiner) {
    return String.fromCharCodes([
      first,
      _presentationSelector,
      ...runes.skip(1),
    ]);
  }
  return emoji;
}

const int _presentationSelector = 0xFE0F;
const int _zeroWidthJoiner = 0x200D;

/// The style for text that is only emoji, such as a reaction: the system's
/// color emoji font, ahead of the app's.
///
/// The selector alone isn't enough. Inter has its own plain glyphs for "❤"
/// and similar symbols, and Flutter keeps to the first font with a glyph,
/// selector or not.
TextStyle emojiStyle({double? fontSize}) => TextStyle(
  fontSize: fontSize,
  fontFamily: switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => _appleEmoji,
    _ => _notoEmoji,
  },
  fontFamilyFallback: const [_appleEmoji, _notoEmoji],
);

const String _appleEmoji = 'Apple Color Emoji';
const String _notoEmoji = 'Noto Color Emoji';
