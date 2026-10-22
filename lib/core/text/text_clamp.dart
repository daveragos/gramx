/// When a block of text is long enough to collapse, shared by post bodies and
/// the quote blocks inside them.
library;

/// How many lines a collapsed post shows before "Show more".
const int kCollapsedPostLines = 10;

/// How long a post may be before it collapses, as on X.
const int kCollapsedPostChars = 280;

/// Whether [text] is long enough to collapse. A string rule rather than a
/// layout measurement, which custom emoji and spoilers make unreliable.
bool shouldClampText(
  String text, {
  int maxLines = kCollapsedPostLines,
  int maxChars = kCollapsedPostChars,
}) {
  if (text.isEmpty) return false;
  if ('\n'.allMatches(text).length >= maxLines) return true;
  return text.length > maxChars;
}

/// How much of [text] a collapsed post shows: up to its [maxLines]th line
/// break, and no more than [maxChars], ending at a word where it can.
int collapsedLength(
  String text, {
  int maxLines = kCollapsedPostLines,
  int maxChars = kCollapsedPostChars,
}) {
  var end = text.length < maxChars ? text.length : maxChars;
  var breaks = 0;
  for (var i = 0; i < end; i++) {
    if (text.codeUnitAt(i) == 0x0A && ++breaks == maxLines) {
      end = i;
      break;
    }
  }
  if (end < text.length && text.codeUnitAt(end) != 0x0A) {
    // Back to the last space, unless that would leave little.
    final space = text.lastIndexOf(RegExp(r'\s'), end);
    if (space > end ~/ 2) end = space;
  }
  // Never between the halves of a surrogate pair.
  if (end > 0 && end < text.length) {
    final unit = text.codeUnitAt(end - 1);
    if (unit >= 0xD800 && unit <= 0xDBFF) end--;
  }
  return end;
}

/// Lines of a quoted passage shown before it collapses. Shorter than a post's
/// limit so a long quote doesn't push the post itself off screen.
const int kCollapsedQuoteLines = 5;
