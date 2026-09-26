import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The hard rule: no user-facing string as a literal
/// in a widget. It belongs in `core/l10n/app_strings.dart`.
///
/// The rule was written down and then broken twelve times, in some of the most
/// visible places in the app — the sign-in screen, the QR page, three error
/// screens that printed a raw exception at the reader. It broke quietly because
/// nothing was checking, so this checks.
///
/// Deliberately a source scan rather than a widget test: the fault is a literal
/// reaching a build method at all, which no rendering test can see.
void main() {
  /// Widget parameters that put their argument on screen.
  ///
  /// `Text(` is the obvious one. The rest are the places a literal hid last
  /// time — a hint, a label, a tooltip are all read by somebody.
  final onScreen = RegExp(
    r"""(\bText\(\s*(const\s+)?|"""
    r"""\b(tooltip|hintText|labelText|semanticLabel|helperText):\s*(const\s+)?)"""
    r"""['"]""",
  );

  /// Files exempt from the rule, each for a stated reason.
  const exempt = <String, String>{
    // The one place strings are *supposed* to be literals.
    'lib/core/l10n/app_strings.dart': 'the string table itself',
    'lib/core/l10n/legal_text.dart': 'the legal documents, verbatim',
    // `Text` here is `package:html`'s DOM text node, not Flutter's widget —
    // the name collides and the scan cannot tell them apart.
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
        // A doc comment describing a string is not a string on screen.
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
        reason: '$path is exempt from the literal scan but is not there — '
            'a stale exemption hides real offenders.',
      );
    }
  });
}
