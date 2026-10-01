import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/compose/presentation/widgets/composer_tools.dart';

void main() {
  // The attach and sticker buttons fold into one chevron while typing, and
  // unfold on request or when the field is empty.
  group('composerToolsFolded', () {
    test('an empty field shows every tool', () {
      expect(
        composerToolsFolded(
          hasText: false,
          expandedByHand: false,
          toolCount: 2,
        ),
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

    // Folding a single button into a chevron saves no space.
    test('one tool is never folded', () {
      expect(
        composerToolsFolded(hasText: true, expandedByHand: false, toolCount: 1),
        isFalse,
      );
    });
  });
}
