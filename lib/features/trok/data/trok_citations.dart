import 'package:gramx/features/feed/domain/text_entity.dart';
import 'package:gramx/features/trok/domain/trok_models.dart';

/// Ties an answer's citations to its source cards: each link that cites a
/// source gets the source's number, which its card shows too.
abstract final class TrokCitations {
  static const _superscripts = '⁰¹²³⁴⁵⁶⁷⁸⁹';

  /// [text] with a superscript number after each link that cites one of
  /// [sources], counted from 1 in the order the cards show them. The link
  /// takes the number in, so tapping it opens the source too.
  static ({String text, List<TextEntity> entities}) number(
    String text,
    List<TextEntity> entities,
    List<TrokSource> sources,
  ) {
    final numbers = <String, int>{};
    for (final (index, source) in sources.indexed) {
      final key = _keyOfSource(source);
      if (key != null) numbers.putIfAbsent(key, () => index + 1);
    }
    if (numbers.isEmpty) return (text: text, entities: entities);

    // Where each number goes, latest first, so earlier offsets hold.
    final marks = <({int at, String mark})>[];
    for (final entity in entities) {
      if (entity.type != TextEntityType.textUrl) continue;
      final url = entity.url;
      final number = url == null ? null : numbers[_key(url)];
      if (number == null) continue;
      marks.add((at: entity.offset + entity.length, mark: superscript(number)));
    }
    if (marks.isEmpty) return (text: text, entities: entities);
    marks.sort((a, b) => b.at.compareTo(a.at));

    var numbered = text;
    var shifted = [...entities];
    for (final (:at, :mark) in marks) {
      if (at > numbered.length) continue;
      numbered = numbered.replaceRange(at, at, mark);
      shifted = [
        for (final e in shifted)
          if (e.offset >= at)
            e.copyWith(offset: e.offset + mark.length)
          // The link ending here takes its number in.
          else if (e.offset + e.length >= at)
            e.copyWith(length: e.length + mark.length)
          else
            e,
      ];
    }
    return (text: numbered, entities: shifted);
  }

  /// [number] in superscript digits, such as ¹².
  static String superscript(int number) => [
    for (final digit in '$number'.split('')) _superscripts[int.parse(digit)],
  ].join();

  static String? _keyOfSource(TrokSource source) => switch (source) {
    TrokPostSource(:final link?) => _key(link),
    TrokPostSource() => null,
    TrokWebSource(:final url) => _key(url),
  };

  /// [url] as citations and sources both write it: no trailing slash, and
  /// the scheme and site in lowercase. A t.me link is lowercase throughout,
  /// as Telegram usernames are.
  static String _key(String url) {
    var key = url.trim();
    while (key.endsWith('/')) {
      key = key.substring(0, key.length - 1);
    }
    final uri = Uri.tryParse(key);
    if (uri == null || uri.host.isEmpty) return key;
    final host = uri.host.toLowerCase().replaceFirst('www.', '');
    if (host == 't.me') return 't.me${uri.path}'.toLowerCase();
    return '$host${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
  }
}
