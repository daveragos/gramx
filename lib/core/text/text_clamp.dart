/// When a block of text is long enough to be worth collapsing.
///
/// Shared by the post body and by the quote blocks inside it, so a quote that
/// would swallow the screen collapses on the same rule the post does — and so
/// that rule exists once.
library;

/// How many lines a collapsed post shows before "Show more".
const int kCollapsedPostLines = 10;

/// Roughly how many characters fit in [kCollapsedPostLines] on a phone.
const int kCollapsedPostChars = 480;

/// Whether [text] is long enough to be worth collapsing.
///
/// Deliberately a plain rule over the string rather than a layout measurement:
/// a `TextPainter` pass would have to guess the size of every custom emoji and
/// spoiler in the post, and getting that wrong shows a "Show more" that expands
/// to nothing. Erring towards not clamping is the safe direction — the cost is
/// a slightly long post, not a lying control.
bool shouldClampText(
  String text, {
  int maxLines = kCollapsedPostLines,
  int maxChars = kCollapsedPostChars,
}) {
  if (text.isEmpty) return false;
  if ('\n'.allMatches(text).length >= maxLines) return true;
  return text.length > maxChars;
}

/// Lines of a quoted passage shown before it collapses.
///
/// Shorter than a post's own limit: a quote is context for what follows, and a
/// long one pushed the post that quoted it off the screen entirely.
const int kCollapsedQuoteLines = 5;
