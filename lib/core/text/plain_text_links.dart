import 'package:gramx/features/feed/domain/text_entity.dart';

/// Finds the links in a string nobody sent us entities for.
///
/// Telegram's *messages* carry formatting as `TextEntity` offsets, which is why
/// a post's links are tappable. A channel's **description** does not: TDLib
/// hands `SupergroupFullInfo.description` over as a bare `String`, and `t.me`
/// preview pages give the bio as plain text too. So a bio full of URLs and
/// @handles rendered as grey prose — the one place a reader most wants to tap
/// through, because it is where a channel puts its site, its chat and its
/// owner.
///
/// This re-derives the entities Telegram would have sent. It is deliberately
/// narrow: only the four marks that are unambiguous in free text, and only
/// where a mark can be acted on. Nothing invents a `textUrl`, nothing guesses
/// at bold, and a match that would overlap one already found is skipped rather
/// than nested — [TextEntityRenderer] walks the list in order and a nested
/// entity would make it slice the string at the wrong place.
///
/// Offsets are UTF-16 code units, which is both what Dart's `substring` uses
/// and what TDLib means by an offset, so these entities are interchangeable
/// with real ones.
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

      // Trailing punctuation belongs to the sentence, not to the link.
      // "See https://x.dev." must not resolve the full stop as part of the
      // host, and a link inside brackets must not swallow the bracket.
      if (type == TextEntityType.url) {
        while (end > start && _trailingNoise.contains(text[end - 1])) {
          end--;
        }
      }
      if (end <= start || overlaps(start, end)) continue;

      claimed.add((start: start, end: end));
      found.add(
        TextEntity(offset: start, length: end - start, type: type),
      );
    }
  }

  // Order is the precedence: an address wins over the URL its domain looks
  // like, and both win over the @handle inside them.
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

/// `http(s)://…`, or a bare `www.` host — the two forms a bio actually uses.
///
/// A bare `example.com` is deliberately *not* matched: "reads e.g. as a link"
/// is the failure mode of over-eager linkifiers, and the cost of missing one
/// unprefixed domain is far lower than turning every abbreviation into a
/// dead tap target.
final RegExp _url = RegExp(
  r'(?:https?://|www\.)[^\s<>"]+',
  caseSensitive: false,
);

/// A Telegram username: a letter, then 4–31 more word characters.
///
/// The length floor is Telegram's own — usernames are at least five
/// characters — and it is what keeps "@me" or an email's local part from
/// rendering as a channel that cannot be opened.
final RegExp _mention = RegExp(r'@[A-Za-z][A-Za-z0-9_]{3,31}\b');

final RegExp _hashtag = RegExp(r'#[A-Za-z0-9_]{1,63}\b');
