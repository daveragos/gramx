import 'package:flutter/services.dart';

import 'package:gramx/core/config/trok_bots.dart';
import 'package:gramx/core/text/composed_text.dart';

/// "@Trok" in a comment or a group message. It goes to Telegram as a mention
/// of [TrokBots.trok], which Telegram's guest mode lets answer in any chat
/// without joining it, and gramX shows it as @Trok again.
abstract final class TrokMention {
  /// What readers see and type.
  static const handle = TrokBots.shown;

  /// What readers may start typing: Trok's name, or one of its bots.
  static final _names = {'trok', ...TrokBots.all};

  /// @trok as a word of its own, not part of an address or a longer name.
  static final _typed = RegExp(r'(?<![\w@])@trok(?!\w)', caseSensitive: false);

  /// The "@" word that ends at the cursor.
  static final _word = RegExp(r'(?<![\w@])@(\w*)$');

  /// [text] with each @Trok naming the bot that calls Trok, as it is sent.
  static String resolve(String text) =>
      text.replaceAll(_typed, '@${TrokBots.trok}');

  /// [resolve] for formatted text, its marks moved to match.
  static ComposedText resolveComposed(ComposedText text) =>
      text.replaceAll(_typed, '@${TrokBots.trok}');

  /// The "@" word being typed in [value] while it could still become @Trok:
  /// "@", "@t", "@Tro" or "@trok" itself. Null otherwise.
  static TextRange? typing(TextEditingValue value) {
    final selection = value.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;
    final cursor = selection.baseOffset;
    final text = value.text;
    // Inside a longer word, the cursor isn't at the end of the mention.
    if (cursor < text.length && RegExp(r'\w').hasMatch(text[cursor])) {
      return null;
    }
    final match = _word.firstMatch(text.substring(0, cursor));
    if (match == null) return null;
    final word = match[1]!.toLowerCase();
    if (!_names.any((name) => name.startsWith(word))) return null;
    return TextRange(start: match.start, end: cursor);
  }

  /// [value] with the "@" word being typed completed to [handle], followed
  /// by one space.
  static TextEditingValue complete(TextEditingValue value) {
    final range = typing(value);
    if (range == null) return value;
    final text = value.text;
    final spaced = range.end < text.length && text[range.end] == ' ';
    return TextEditingValue(
      text: text.replaceRange(
        range.start,
        range.end,
        spaced ? handle : '$handle ',
      ),
      selection: TextSelection.collapsed(
        offset: range.start + handle.length + 1,
      ),
    );
  }
}
