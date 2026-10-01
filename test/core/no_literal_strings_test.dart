import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// No user-facing string literals in widgets; they belong in
/// `core/l10n/app_strings.dart`. A source scan, since rendering can't tell.
void main() {
  /// Widget parameters that put their argument on screen.
  final onScreen = RegExp(
    r"""(\bText\(\s*(const\s+)?|"""
    r"""\b(tooltip|hintText|labelText|semanticLabel|helperText):\s*(const\s+)?)"""
    r"""['"]""",
  );

  /// Files exempt from the rule, each for a stated reason.
  const exempt = <String, String>{
    'lib/core/l10n/app_strings.dart': 'the string table itself',
    'lib/core/l10n/legal_text.dart': 'the legal documents, verbatim',
    // `Text` here is `package:html`'s DOM node, not Flutter's widget.
    'lib/features/guest/data/tme_page_parser.dart': 'html.Text, not a widget',
  };

  test('no user-facing literal outside the string table', () {
    final offenders = <String>[];

    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('.g.dart'))
        .where((f) => !f.path.endsWith('.freezed.dart'))
        .where((f) => !exempt.containsKey(f.path));

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Skip comments.
        if (line.trimLeft().startsWith('//')) continue;
        if (!onScreen.hasMatch(line)) continue;
        offenders.add('${file.path}:${i + 1}  ${line.trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These put a literal on screen. Move the text to AppStrings:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the exemptions still exist', () {
    for (final path in exempt.keys) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason:
            '$path is exempt from the literal scan but is not there — '
            'a stale exemption hides real offenders.',
      );
    }
  });
}
