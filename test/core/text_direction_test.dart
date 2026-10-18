import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/core/text/text_direction.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';
import 'package:gramx/features/trok/data/trok_markdown.dart';

const persian = 'سهام سقوط کرد!';
const english = 'Prices fell.';

Widget wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('firstStrongDirection', () {
    test('takes the first letter\'s direction', () {
      expect(firstStrongDirection(persian), TextDirection.rtl);
      expect(firstStrongDirection('שלום'), TextDirection.rtl);
      expect(firstStrongDirection(english), TextDirection.ltr);
      expect(firstStrongDirection('ዝናብ ነገ'), TextDirection.ltr);
      expect(firstStrongDirection('Привет'), TextDirection.ltr);
    });

    test('looks past digits, emoji and punctuation', () {
      expect(firstStrongDirection('🔥 2026: $persian'), TextDirection.rtl);
      expect(firstStrongDirection('١٢٣ ، Hello'), TextDirection.ltr);
      expect(firstStrongDirection('123 🔥 !'), isNull);
    });

    test('a right-to-left mark counts as a letter', () {
      expect(firstStrongDirection('\u200F123'), TextDirection.rtl);
    });

    test('reads only the range asked for', () {
      const text = '$english\n$persian';
      expect(firstStrongDirection(text, 13), TextDirection.rtl);
      expect(firstStrongDirection(text, 0, 12), TextDirection.ltr);
    });
  });

  group('directionIsolates', () {
    test('marks only the lines that run the other way', () {
      expect(directionIsolates('$english\n$persian', TextDirection.ltr), {
        13: '\u2067',
      });
      expect(directionIsolates('$persian\n$english', TextDirection.rtl), {
        15: '\u2066',
      });
      expect(
        directionIsolates('$english\n🔥\n$english', TextDirection.ltr),
        {},
      );
    });

    test('withMarks writes them where they fall', () {
      const text = 'ab\ncd';
      expect(withMarks(text, 0, 5, {3: '|'}), 'ab\n|cd');
      expect(withMarks(text, 3, 5, {3: '|'}), '|cd');
      expect(withMarks(text, 0, 3, {3: '|'}), 'ab\n');
    });
  });

  group('TextEntityRenderer direction', () {
    RenderParagraph paragraph(WidgetTester tester) => tester.renderObject(
      find.descendant(
        of: find.byType(TextEntityRenderer),
        matching: find.byType(RichText),
      ),
    );

    /// The left edge of the character at [index] of what is drawn.
    double leftOf(RenderParagraph p, int index) => p
        .getBoxesForSelection(
          TextSelection(baseOffset: index, extentOffset: index + 1),
        )
        .first
        .left;

    String drawn(RenderParagraph p) => p.text.toPlainText();

    Future<RenderParagraph> render(
      WidgetTester tester,
      String text, {
      List<TextEntity> entities = const [],
    }) async {
      await tester.pumpWidget(
        wrap(
          TextEntityRenderer(text: text, entities: entities, selectable: false),
        ),
      );
      return paragraph(tester);
    }

    testWidgets('a Persian post starts from the right', (tester) async {
      final p = await render(tester, persian);
      expect(p.textDirection, TextDirection.rtl);
      // The exclamation mark ends the sentence, on its left.
      expect(leftOf(p, persian.length - 1), lessThan(leftOf(p, 0)));
    });

    testWidgets('an English post is as it was', (tester) async {
      final p = await render(tester, english);
      expect(p.textDirection, TextDirection.ltr);
      expect(leftOf(p, english.length - 1), greaterThan(leftOf(p, 0)));
    });

    testWidgets('a Persian line under English keeps its own order', (
      tester,
    ) async {
      final p = await render(tester, '$english\n$persian');
      expect(p.textDirection, TextDirection.ltr);
      final text = drawn(p);
      final start = text.indexOf('س');
      expect(leftOf(p, text.length - 1), lessThan(leftOf(p, start)));
      expect(leftOf(p, english.length - 1), greaterThan(leftOf(p, 0)));
    });

    testWidgets('an English line under Persian keeps its own order', (
      tester,
    ) async {
      final p = await render(tester, '$persian\n$english');
      expect(p.textDirection, TextDirection.rtl);
      final text = drawn(p);
      final start = text.indexOf('P');
      expect(leftOf(p, text.length - 1), greaterThan(leftOf(p, start)));
      expect(leftOf(p, persian.length - 1), lessThan(leftOf(p, 0)));
    });

    testWidgets('formatting in a marked line covers the same words', (
      tester,
    ) async {
      const text = '$english\n$persian';
      final p = await render(
        tester,
        text,
        entities: const [
          TextEntity(offset: 13, length: 4, type: TextEntityType.bold),
        ],
      );
      final bold = <String>[];
      p.text.visitChildren((span) {
        if (span is TextSpan && span.style?.fontWeight == FontWeight.bold) {
          bold.add(span.text!);
        }
        return true;
      });
      expect(bold, ['\u2067سهام']);
      expect(drawn(p).replaceAll('\u2067', ''), text);
    });

    testWidgets('Trok\'s bullets sit on the right of a Persian list', (
      tester,
    ) async {
      final (text, entities) = TrokMarkdown.format(
        '- سهام سقوط کرد\n- قیمت نفت بالا رفت',
      );
      final p = await render(tester, text, entities: entities);
      expect(p.textDirection, TextDirection.rtl);
      final drawnText = drawn(p);
      for (final line in [0, drawnText.indexOf('\n') + 1]) {
        expect(drawnText[line], '•');
        expect(leftOf(p, line), greaterThan(leftOf(p, line + 2)));
      }
    });

    testWidgets('a short Persian line can reach the right edge', (
      tester,
    ) async {
      Future<double> widthOf(String text, {required bool fullWidth}) async {
        await tester.pumpWidget(
          wrap(
            TextEntityRenderer(
              text: text,
              entities: const [],
              fullWidth: fullWidth,
            ),
          ),
        );
        return tester.getSize(find.byType(TextEntityRenderer)).width;
      }

      final screen =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(await widthOf('سلام', fullWidth: true), screen);
      expect(await widthOf('سلام', fullWidth: false), lessThan(screen));
      // Left-to-right text needs no room it doesn't use.
      expect(await widthOf('Hi', fullWidth: true), lessThan(screen));
    });

    testWidgets('a Persian quote has its bar on the right', (tester) async {
      await tester.pumpWidget(
        wrap(
          const TextEntityRenderer(
            text: persian,
            entities: [
              TextEntity(
                offset: 0,
                length: persian.length,
                type: TextEntityType.blockQuote,
              ),
            ],
          ),
        ),
      );
      final direction = tester.widget<Directionality>(
        find
            .ancestor(
              of: find.text(persian),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(direction.textDirection, TextDirection.rtl);
    });
  });
}
