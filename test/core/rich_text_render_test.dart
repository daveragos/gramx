import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/core/navigation/deep_link_handler.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/expandable_text.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';

Widget wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('a code block renders as a block, with its language and a copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
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
      ),
    );

    expect(find.byType(CodeBlock), findsOneWidget);
    expect(find.text('bash'), findsOneWidget);
    expect(find.byTooltip(AppStrings.codeBlockCopy), findsOneWidget);
  });

  testWidgets('inline code renders as a chip rather than bare text', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const TextEntityRenderer(
          text: 'call main() now',
          entities: [
            TextEntity(offset: 5, length: 6, type: TextEntityType.code),
          ],
        ),
      ),
    );

    expect(find.byType(InlineCodeChip), findsOneWidget);
  });

  testWidgets('a block quote renders as a quote', (tester) async {
    await tester.pumpWidget(
      wrap(
        const TextEntityRenderer(
          text: 'they said this',
          entities: [
            TextEntity(offset: 0, length: 14, type: TextEntityType.blockQuote),
          ],
        ),
      ),
    );

    expect(find.byType(QuoteBlock), findsOneWidget);
  });

  group('QuoteBlock', () {
    // A quote is a widget inside the paragraph, so the post's own "Show more"
    // can't clamp it.
    testWidgets('a long quote collapses, and the toggle opens it', (
      tester,
    ) async {
      final long = List.generate(30, (i) => 'quoted line $i').join('\n');
      await tester.pumpWidget(
        wrap(
          TextEntityRenderer(
            text: long,
            entities: [
              TextEntity(
                offset: 0,
                length: long.length,
                type: TextEntityType.blockQuote,
              ),
            ],
          ),
        ),
      );

      final collapsed = tester.widget<Text>(
        find
            .descendant(
              of: find.byType(QuoteBlock),
              matching: find.byType(Text),
            )
            .first,
      );
      expect(collapsed.maxLines, kCollapsedQuoteLines);
      expect(find.text(AppStrings.postShowMore), findsOneWidget);

      await tester.tap(find.text(AppStrings.postShowMore));
      await tester.pump();

      final expanded = tester.widget<Text>(
        find
            .descendant(
              of: find.byType(QuoteBlock),
              matching: find.byType(Text),
            )
            .first,
      );
      expect(expanded.maxLines, isNull);
      expect(find.text(AppStrings.postShowLess), findsOneWidget);
    });

    testWidgets('a short quote gets no toggle', (tester) async {
      await tester.pumpWidget(
        wrap(
          const TextEntityRenderer(
            text: 'they said this',
            entities: [
              TextEntity(
                offset: 0,
                length: 14,
                type: TextEntityType.blockQuote,
              ),
            ],
          ),
        ),
      );

      expect(find.byType(QuoteBlock), findsOneWidget);
      expect(find.text(AppStrings.postShowMore), findsNothing);
    });
  });

  group('ExpandableText', () {
    testWidgets('a short post gets no toggle', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ExpandableText(
            text: 'Two lines\nonly',
            entities: [],
            style: TextStyle(fontSize: 14),
          ),
        ),
      );

      expect(find.text(AppStrings.postShowMore), findsNothing);
    });

    // A SelectableText with a line limit scrolls internally instead of
    // clipping.
    testWidgets('a collapsed post cannot be scrolled instead of expanded', (
      tester,
    ) async {
      final long = List.generate(30, (i) => 'line $i').join('\n');
      await tester.pumpWidget(
        wrap(
          ExpandableText(
            text: long,
            entities: const [],
            style: const TextStyle(fontSize: 14),
          ),
        ),
      );

      expect(find.byType(SelectableText), findsNothing);
      expect(
        tester.widget<Text>(find.byType(Text).first).overflow,
        TextOverflow.ellipsis,
      );

      await tester.tap(find.text(AppStrings.postShowMore));
      await tester.pump();

      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('a long post clamps, and the toggle opens it', (tester) async {
      final long = List.generate(30, (i) => 'line $i').join('\n');
      await tester.pumpWidget(
        wrap(
          ExpandableText(
            text: long,
            entities: const [],
            style: const TextStyle(fontSize: 14),
          ),
        ),
      );

      expect(find.text(AppStrings.postShowMore), findsOneWidget);

      await tester.tap(find.text(AppStrings.postShowMore));
      await tester.pump();

      expect(find.text(AppStrings.postShowLess), findsOneWidget);
    });
  });

  group('taps on people and links', () {
    // Bots name people by id, which drew coloured and did nothing.
    testWidgets('a mention by id opens the person', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: TextEntityRenderer(
                text: '7493358198',
                selectable: false,
                entities: [
                  TextEntity(
                    offset: 0,
                    length: 10,
                    type: TextEntityType.mentionName,
                    userId: 7493358198,
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/user/:userId',
            builder: (_, state) =>
                Text('profile ${state.pathParameters['userId']}'),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.tap(find.text('7493358198'));
      await tester.pumpAndSettle();

      expect(find.text('profile 7493358198'), findsOneWidget);
    });

    // A link to a message opened only its group or channel.
    testWidgets('a Telegram link goes where a link from outside would', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [isGuestModeProvider.overrideWithValue(false)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: wrap(
            const TextEntityRenderer(
              text: 'here',
              selectable: false,
              entities: [
                TextEntity(
                  offset: 0,
                  length: 4,
                  type: TextEntityType.textUrl,
                  url: 'https://t.me/flutter_ethiopia/3',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('here'));
      await tester.pump();

      expect(
        container.read(pendingDeepLinkProvider),
        Uri.parse('https://t.me/flutter_ethiopia/3'),
      );
    });
  });
}
