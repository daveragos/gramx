import 'package:gramx/features/feed/domain/text_entity.dart';

/// Trok's answers as Telegram formatted text.
///
/// Trok writes the Markdown a phone shows well: paragraphs, `**bold**`,
/// `*italic*`, `` `code` ``, fenced code, links, `- ` bullets, `1.` lists and
/// `## ` headings. Telegram text has no headings or list markup, so a heading
/// becomes a bold line and a bullet a "•". Entities never overlap, because
/// the renderer draws one mark per span: a link inside bold text is a link.
abstract final class TrokMarkdown {
  /// [markdown] as text and entities.
  ///
  /// [resolve] turns a link's target into the address it opens, or null to
  /// leave the words unlinked; by default only web links are kept. With
  /// [partial], the text is still arriving, so marks left open at its end
  /// apply to the rest instead of showing as typed.
  static (String, List<TextEntity>) format(
    String markdown, {
    String? Function(String target)? resolve,
    bool partial = false,
  }) {
    final out = _Out();
    final inline = _Inline(resolve ?? webOnly);
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');

    var blankBefore = false;
    void startLine() {
      if (out.isEmpty) return;
      out.write(blankBefore ? '\n\n' : '\n');
      blankBefore = false;
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();
      final last = i == lines.length - 1;

      final fence = _fenceStart.firstMatch(line);
      if (fence != null) {
        var end = i + 1;
        while (end < lines.length && !_fenceEnd.hasMatch(lines[end])) {
          end++;
        }
        final closed = end < lines.length;
        if (closed || partial) {
          final code = lines.sublist(i + 1, end).join('\n');
          if (code.trim().isNotEmpty) {
            startLine();
            out.mark(
              code,
              TextEntityType.codeBlock,
              language: (fence[1] ?? '').isEmpty ? null : fence[1],
            );
          }
          i = end;
          continue;
        }
      }

      if (line.trim().isEmpty || _rule.hasMatch(line)) {
        blankBefore = !out.isEmpty;
        continue;
      }
      startLine();
      final tail = partial && last;

      final heading = _heading.firstMatch(line);
      if (heading != null) {
        out.runs(_Inline.within(inline.parse(heading[1]!, tail), bold: true));
        continue;
      }
      final bullet = _bullet.firstMatch(line);
      if (bullet != null) {
        out.write('${'   ' * (bullet[1]!.length ~/ 2)}• ');
        out.runs(inline.parse(bullet[2]!, tail));
        continue;
      }
      final numbered = _numbered.firstMatch(line);
      if (numbered != null) {
        out.write('${'   ' * (numbered[1]!.length ~/ 2)}${numbered[2]}. ');
        out.runs(inline.parse(numbered[3]!, tail));
        continue;
      }
      final quote = _quote.firstMatch(line);
      out.runs(inline.parse(quote == null ? line : quote[1]!, tail));
    }
    return (out.text, out.entities);
  }

  /// Keeps links to the web and to Telegram, and drops anything else.
  static String? webOnly(String target) {
    final uri = Uri.tryParse(target);
    if (uri == null) return null;
    return const {'http', 'https', 'tg'}.contains(uri.scheme) ? target : null;
  }

  static final _fenceStart = RegExp(r'^\s{0,3}```\s*([\w+#.-]*)\s*$');
  static final _fenceEnd = RegExp(r'^\s{0,3}```\s*$');
  static final _rule = RegExp(r'^\s{0,3}([-*_])(\s*\1){2,}\s*$');
  static final _heading = RegExp(r'^\s{0,3}#{1,6}\s+(.*?)(\s+#+)?\s*$');
  static final _bullet = RegExp(r'^(\s*)[-*+]\s+(.*)$');
  static final _numbered = RegExp(r'^(\s*)(\d{1,3})[.)]\s+(.*)$');
  static final _quote = RegExp(r'^\s{0,3}>\s?(.*)$');
}

/// A stretch of text with at most one mark.
class _Run {
  final String text;
  final TextEntityType? type;
  final String? url;

  const _Run(this.text, [this.type, this.url]);
}

class _Out {
  final _buffer = StringBuffer();
  final entities = <TextEntity>[];

  bool get isEmpty => _buffer.isEmpty;
  String get text => _buffer.toString();

  void write(String s) => _buffer.write(s);

  void mark(String s, TextEntityType type, {String? url, String? language}) {
    if (s.isEmpty) return;
    entities.add(
      TextEntity(
        offset: _buffer.length,
        length: s.length,
        type: type,
        url: url,
        language: language,
      ),
    );
    _buffer.write(s);
  }

  void runs(List<_Run> runs) {
    // Neighbours with the same mark become one entity.
    final merged = <_Run>[];
    for (final run in runs) {
      final previous = merged.lastOrNull;
      if (previous != null &&
          previous.type == run.type &&
          previous.url == run.url) {
        merged[merged.length - 1] = _Run(
          previous.text + run.text,
          run.type,
          run.url,
        );
      } else if (run.text.isNotEmpty) {
        merged.add(run);
      }
    }
    for (final run in merged) {
      final type = run.type;
      type == null ? write(run.text) : mark(run.text, type, url: run.url);
    }
  }
}

/// Emphasis, code and links within one line.
class _Inline {
  final String? Function(String target) resolve;

  _Inline(this.resolve);

  /// [runs] inside bold or italic. Links and code keep their own mark, and
  /// bold wins over italic.
  static List<_Run> within(List<_Run> runs, {required bool bold}) => [
    for (final r in runs)
      switch (r.type) {
        null => _Run(
          r.text,
          bold ? TextEntityType.bold : TextEntityType.italic,
        ),
        TextEntityType.italic when bold => _Run(r.text, TextEntityType.bold),
        _ => r,
      },
  ];

  /// [s] as runs. [tail] says [s] ends where the text stops arriving.
  List<_Run> parse(String s, bool tail) {
    final runs = <_Run>[];
    final plain = StringBuffer();
    void flush() {
      if (plain.isEmpty) return;
      runs.add(_Run(plain.toString()));
      plain.clear();
    }

    var i = 0;
    while (i < s.length) {
      final c = s[i];

      if (c == r'\' && i + 1 < s.length && _escapable.contains(s[i + 1])) {
        plain.write(s[i + 1]);
        i += 2;
        continue;
      }

      if (c == '`') {
        final end = s.indexOf('`', i + 1);
        if (end > i + 1 || (end < 0 && tail)) {
          flush();
          final code = s.substring(i + 1, end < 0 ? s.length : end);
          runs.add(_Run(code, TextEntityType.code));
          i = end < 0 ? s.length : end + 1;
          continue;
        }
      }

      // A mark that has just arrived, with nothing after it yet.
      if (tail && (c == '*' || c == '_') && s.substring(i).trim() == c * 2) {
        break;
      }
      if (tail && c == '*' && i == s.length - 1) break;

      if (s.startsWith('**', i) || s.startsWith('__', i)) {
        final marker = s.substring(i, i + 2);
        final end = s.indexOf(marker, i + 2);
        if (end > i + 2 || (end < 0 && tail && i + 2 < s.length)) {
          flush();
          final inner = s.substring(i + 2, end < 0 ? s.length : end);
          runs.addAll(within(parse(inner, end < 0), bold: true));
          i = end < 0 ? s.length : end + 2;
          continue;
        }
      }

      if ((c == '*' || c == '_') && _opensItalic(s, i)) {
        final end = _italicEnd(s, i);
        if (end > i + 1 || (end < 0 && tail && c == '*')) {
          flush();
          final inner = s.substring(i + 1, end < 0 ? s.length : end);
          runs.addAll(within(parse(inner, end < 0), bold: false));
          i = end < 0 ? s.length : end + 1;
          continue;
        }
      }

      if (c == '[') {
        final link = _link(s, i, tail);
        if (link != null) {
          flush();
          final (run, next) = link;
          if (run.text.isNotEmpty) runs.add(run);
          i = next;
          continue;
        }
      }

      if (c == 'h' && (i == 0 || !_isWordChar(s[i - 1]))) {
        final url = _bareUrl.matchAsPrefix(s, i)?[0];
        if (url != null) {
          final trimmed = url.replaceFirst(_trailingPunctuation, '');
          flush();
          runs.add(_Run(trimmed, TextEntityType.url));
          i += trimmed.length;
          continue;
        }
      }

      plain.write(c);
      i++;
    }
    flush();
    return runs;
  }

  /// A link at [start], as its run and the index after it, or null when
  /// the bracket is only a bracket.
  (_Run, int)? _link(String s, int start, bool tail) {
    final close = _closing(s, start, '[', ']');
    if (close < 0) {
      // A label still being written.
      if (!tail) return null;
      return (_Run(_plainText(s.substring(start + 1))), s.length);
    }
    final label = _plainText(s.substring(start + 1, close));
    if (close + 1 >= s.length) {
      return tail ? (_Run(label), s.length) : null;
    }
    if (s[close + 1] != '(') return null;

    final paren = _closing(s, close + 1, '(', ')');
    if (paren < 0) return tail ? (_Run(label), s.length) : null;

    // `(target "title")` or `(<target>)`.
    var target = s.substring(close + 2, paren).trim();
    final space = target.indexOf(RegExp(r'\s'));
    if (space > 0) target = target.substring(0, space);
    if (target.startsWith('<') && target.endsWith('>')) {
      target = target.substring(1, target.length - 1);
    }
    final url = target.isEmpty ? null : resolve(target);
    final text = label.isEmpty ? (url ?? '') : label;
    return (
      url == null ? _Run(text) : _Run(text, TextEntityType.textUrl, url),
      paren + 1,
    );
  }

  /// The words of [s] without their marks, for a link's label.
  String _plainText(String s) =>
      parse(s, false).map((r) => r.text).join().trim();

  /// The index of the bracket closing the one at [open], allowing pairs
  /// inside, or -1.
  static int _closing(String s, int open, String opening, String closing) {
    var depth = 0;
    for (var i = open; i < s.length; i++) {
      final c = s[i];
      if (c == r'\') {
        i++;
      } else if (c == opening) {
        depth++;
      } else if (c == closing && --depth == 0) {
        return i;
      }
    }
    return -1;
  }

  /// A single `*` or `_` that opens emphasis: followed by a letter rather
  /// than a space, and for `_`, not inside a word such as snake_case.
  static bool _opensItalic(String s, int i) {
    if (i + 1 >= s.length || _isSpace(s[i + 1])) return false;
    if (s[i] == '_' && i > 0 && _isWordChar(s[i - 1])) return false;
    return true;
  }

  static int _italicEnd(String s, int i) {
    final marker = s[i];
    var end = s.indexOf(marker, i + 1);
    while (end >= 0) {
      final closes =
          !_isSpace(s[end - 1]) &&
          (marker != '_' || end + 1 >= s.length || !_isWordChar(s[end + 1]));
      if (closes) return end;
      end = s.indexOf(marker, end + 1);
    }
    return -1;
  }

  static bool _isSpace(String c) => c.trim().isEmpty;

  static bool _isWordChar(String c) => _wordChar.hasMatch(c);

  static final _wordChar = RegExp(r'[\p{L}\p{N}_]', unicode: true);
  static final _bareUrl = RegExp(r'https?://[^\s<>()\[\]]+');
  static final _trailingPunctuation = RegExp(r'''[.,;:!?'"*_]+$''');
  static const _escapable = r'\`*_[]()#+-.!>~|{}';
}
