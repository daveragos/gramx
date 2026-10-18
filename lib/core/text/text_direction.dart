import 'package:flutter/widgets.dart';

/// The direction of the first strongly directional character in [text]
/// between [start] and [end]. This is how the Unicode Bidirectional Algorithm
/// picks a paragraph's direction (rule P2), and how Telegram's apps decide
/// which side a message starts from. Null when there is none: digits, emoji
/// and punctuation have no direction of their own.
TextDirection? firstStrongDirection(String text, [int start = 0, int? end]) {
  for (final rune in text.substring(start, end).runes) {
    if (rune == _rlm) return TextDirection.rtl;
    if (rune == _lrm) return TextDirection.ltr;
    if (!_letter.hasMatch(String.fromCharCode(rune))) continue;
    return _isRightToLeft(rune) ? TextDirection.rtl : TextDirection.ltr;
  }
  return null;
}

/// Marks to write before characters of [text] so that each paragraph whose
/// own direction differs from [base] is laid out in its own direction: a
/// left-to-right isolate before an English line in a Persian post, and a
/// right-to-left one before a Persian line in an English post. Keyed by the
/// offset the mark goes before.
///
/// One text widget has one base direction, and keeping a post in one widget
/// keeps selection and clamping whole. An isolate needs no closing mark: a
/// line break ends it (rule X8).
Map<int, String> directionIsolates(String text, TextDirection base) {
  final marks = <int, String>{};
  var start = 0;
  while (start < text.length) {
    var end = text.indexOf('\n', start);
    if (end < 0) end = text.length;
    final direction = firstStrongDirection(text, start, end);
    if (direction != null && direction != base) {
      marks[start] = direction == TextDirection.rtl ? _rli : _lri;
    }
    start = end + 1;
  }
  return marks;
}

/// [text] from [start] to [end] with the [marks] that fall inside it.
String withMarks(String text, int start, int end, Map<int, String> marks) {
  if (marks.isEmpty) return text.substring(start, end);
  final out = StringBuffer();
  var from = start;
  for (final offset in marks.keys) {
    if (offset < start || offset >= end) continue;
    out
      ..write(text.substring(from, offset))
      ..write(marks[offset]);
    from = offset;
  }
  out.write(text.substring(from, end));
  return out.toString();
}

const _lrm = 0x200E;
const _rlm = 0x200F;
const _lri = '\u2066';
const _rli = '\u2067';

final _letter = RegExp(r'\p{L}', unicode: true);

/// Scripts written right to left: Hebrew, Arabic, Syriac, Thaana, N'Ko and
/// their neighbours, with their presentation forms and the historic scripts
/// beyond the Basic Multilingual Plane.
bool _isRightToLeft(int rune) =>
    (rune >= 0x0590 && rune <= 0x08FF) ||
    (rune >= 0xFB1D && rune <= 0xFDFF) ||
    (rune >= 0xFE70 && rune <= 0xFEFF) ||
    (rune >= 0x10800 && rune <= 0x10FFF) ||
    (rune >= 0x1E800 && rune <= 0x1EFFF);
