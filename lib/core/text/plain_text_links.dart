import 'package:gramx/features/feed/domain/text_entity.dart';

/// Finds URLs, emails, @mentions and #hashtags in plain text, such as a
/// channel description (TDLib sends it without entities). Overlapping matches
/// are skipped, since [TextEntityRenderer] expects ordered, non-nested
/// entities. Offsets are UTF-16 code units, as in TDLib.
List<TextEntity> linkifyPlainText(String text) {
  if (text.isEmpty) return const [];

  final found = <TextEntity>[];
  // Ranges already claimed, so "mail@example.com" is one email rather than an
  // email plus an @mention of "example".
  final claimed = <({int start, int end})>[];

  bool overlaps(int start, int end) {
    for (final range in claimed) {
      if (start < range.end && end > range.start) return true;
    }
    return false;
  }

  void scan(RegExp pattern, TextEntityType type) {
    for (final match in pattern.allMatches(text)) {
      final start = match.start;
      var end = match.end;

      // Trailing punctuation and closing brackets belong to the sentence.
      if (type == TextEntityType.url) {
        while (end > start && _trailingNoise.contains(text[end - 1])) {
          end--;
        }
      }
      if (end <= start || overlaps(start, end)) continue;

      claimed.add((start: start, end: end));
      found.add(TextEntity(offset: start, length: end - start, type: type));
    }
  }

  // Order is precedence: an email beats the URL its domain looks like, and
  // both beat the @handle inside them.
  scan(_email, TextEntityType.emailAddress);
  scan(_url, TextEntityType.url);
  scan(_mention, TextEntityType.mention);
  scan(_hashtag, TextEntityType.hashtag);

  found.sort((a, b) => a.offset.compareTo(b.offset));
  return found;
}

const String _trailingNoise = '.,;:!?)]}\'"»…';

final RegExp _email = RegExp(
  r'[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+',
);

/// An `http(s)://` link or a bare `www.` host; bare domains aren't matched.
final RegExp _url = RegExp(
  r'(?:https?://|www\.)[^\s<>"]+',
  caseSensitive: false,
);

/// A Telegram username (at least five characters, so "@me" doesn't match).
final RegExp _mention = RegExp(r'@[A-Za-z][A-Za-z0-9_]{3,31}\b');

final RegExp _hashtag = RegExp(r'#[A-Za-z0-9_]{1,63}\b');
