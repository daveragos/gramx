import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/compose/presentation/widgets/composer_tools.dart';

void main() {
  // The attach and sticker buttons fold into one chevron while somebody
  // types, so the field gets its width back — and unfold the moment they
  // ask, or the moment the field is empty again.
  group('composerToolsFolded', () {
    test('an empty field shows every tool', () {
      expect(
        composerToolsFolded(hasText: false, expandedByHand: false, toolCount: 2),
        isFalse,
      );
    });

    test('words fold the tools away', () {
      expect(
        composerToolsFolded(hasText: true, expandedByHand: false, toolCount: 2),
        isTrue,
      );
    });

    test('asking for them back wins over the words', () {
      expect(
        composerToolsFolded(hasText: true, expandedByHand: true, toolCount: 2),
        isFalse,
      );
    });

    // A single button folded into a single chevron saves nothing and moves a
    // control for no reason.
    test('one tool is never folded', () {
      expect(
        composerToolsFolded(hasText: true, expandedByHand: false, toolCount: 1),
        isFalse,
      );
    });
  });
}
