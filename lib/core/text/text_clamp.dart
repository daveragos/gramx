/// When a block of text is long enough to collapse, shared by post bodies and
/// the quote blocks inside them.
library;

/// How many lines a collapsed post shows before "Show more".
const int kCollapsedPostLines = 10;

/// Roughly how many characters fit in [kCollapsedPostLines] on a phone.
const int kCollapsedPostChars = 480;

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

/// Lines of a quoted passage shown before it collapses. Shorter than a post's
/// limit so a long quote doesn't push the post itself off screen.
const int kCollapsedQuoteLines = 5;
