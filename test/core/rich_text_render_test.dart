import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/expandable_text.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('a code block renders as a block, with its language and a copy',
      (tester) async {
    await tester.pumpWidget(wrap(
      const TextEntityRenderer(
        text: 'run this:\nflutter test',
        entities: [
          TextEntity(
            offset: 10,
            length: 12,
            type: TextEntityType.codeBlock,
            language: 'bash',
          ),
        ],
      ),
    ));

    expect(find.byType(CodeBlock), findsOneWidget);
    expect(find.text('bash'), findsOneWidget);
    expect(find.byTooltip(AppStrings.codeBlockCopy), findsOneWidget);
  });

  testWidgets('inline code renders as a chip rather than bare text',
      (tester) async {
    await tester.pumpWidget(wrap(
      const TextEntityRenderer(
        text: 'call main() now',
        entities: [
          TextEntity(offset: 5, length: 6, type: TextEntityType.code),
        ],
      ),
    ));

    expect(find.byType(InlineCodeChip), findsOneWidget);
  });

  testWidgets('a block quote renders as a quote', (tester) async {
    await tester.pumpWidget(wrap(
      const TextEntityRenderer(
        text: 'they said this',
        entities: [
          TextEntity(offset: 0, length: 14, type: TextEntityType.blockQuote),
        ],
      ),
    ));

    expect(find.byType(QuoteBlock), findsOneWidget);
  });

  group('ExpandableText', () {
    testWidgets('a short post gets no toggle', (tester) async {
      await tester.pumpWidget(wrap(
        const ExpandableText(
          text: 'Two lines\nonly',
          entities: [],
          style: TextStyle(fontSize: 14),
        ),
      ));

      expect(find.text(AppStrings.postShowMore), findsNothing);
    });

    // A SelectableText with a line limit keeps the rest of the post in its own
    // scroll view, so a collapsed post could be read by scrolling it and the
    // toggle meant nothing.
    testWidgets('a collapsed post cannot be scrolled instead of expanded',
        (tester) async {
      final long = List.generate(30, (i) => 'line $i').join('\n');
      await tester.pumpWidget(wrap(
        ExpandableText(
          text: long,
          entities: const [],
          style: const TextStyle(fontSize: 14),
        ),
      ));

      expect(find.byType(SelectableText), findsNothing);
      expect(
        tester.widget<Text>(find.byType(Text).first).overflow,
        TextOverflow.ellipsis,
      );

      await tester.tap(find.text(AppStrings.postShowMore));
      await tester.pump();

      // Expanded, the whole post is there and selectable again.
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('a long post clamps, and the toggle opens it', (tester) async {
      final long = List.generate(30, (i) => 'line $i').join('\n');
      await tester.pumpWidget(wrap(
        ExpandableText(
          text: long,
          entities: const [],
          style: const TextStyle(fontSize: 14),
        ),
      ));

      expect(find.text(AppStrings.postShowMore), findsOneWidget);

      await tester.tap(find.text(AppStrings.postShowMore));
      await tester.pump();

      expect(find.text(AppStrings.postShowLess), findsOneWidget);
    });
  });
}
