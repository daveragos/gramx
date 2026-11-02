import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/text/composed_text.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';
import 'package:gramx/features/trok/data/trok_client.dart';
import 'package:gramx/features/trok/data/trok_mention.dart';
import 'package:gramx/features/trok/domain/trok_models.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_mention_suggestion.dart';

class _Client implements TrokClient {
  @override
  Stream<TrokEvent> ask(TrokRequest request) => const Stream.empty();

  @override
  Future<List<TrokConversation>> conversations() async => const [];

  @override
  Future<TrokConversation> conversation(String remoteId) =>
      throw const TrokFailure('not_found', 'Gone');

  @override
  Future<void> deleteConversation(String remoteId) async {}

  @override
  Future<TrokAllowance> allowance() async =>
      const TrokAllowance(questionsPerDay: 30, usedToday: 0);

  @override
  Future<void> announceMention(int chatId) async {}
}

TextEditingValue typed(String text, [int? cursor]) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: cursor ?? text.length),
);

void main() {
  group('TrokMention.resolve', () {
    test('@Trok goes to the bot that calls Trok', () {
      expect(
        TrokMention.resolve('@Trok is this true?'),
        '@trokkai is this true?',
      );
      expect(
        TrokMention.resolve('What do you think, @trok?'),
        'What do you think, @trokkai?',
      );
    });

    test('leaves longer names and addresses alone', () {
      for (final text in [
        '@troked out',
        '@trok_fan said so',
        'mail me at me@trok.et',
        'no mention here',
      ]) {
        expect(TrokMention.resolve(text), text);
      }
    });
  });

  group('TrokMention.mentionsGuestBot', () {
    test('sees the guest bot in a resolved message', () {
      for (final text in [
        '@trokkai is this true?',
        'what do you think, @trokkai?',
        TrokMention.resolve('@Trok hi'),
      ]) {
        expect(TrokMention.mentionsGuestBot(text), isTrue, reason: text);
      }
    });

    test('ignores other bots, longer names and addresses', () {
      for (final text in [
        'before resolving @trok stays unseen',
        '@trokagent and @tr0kbot are not the guest bot',
        '@trokkaix is a different name',
        'mail me at me@trokkai.et',
        '@durov said so',
        'no mention here',
      ]) {
        expect(TrokMention.mentionsGuestBot(text), isFalse, reason: text);
      }
    });
  });

  test('a formatted @Trok keeps its formatting', () {
    final resolved = TrokMention.resolveComposed(
      const ComposedText('@Trok is this true?', [
        TextEntity(offset: 0, length: 19, type: TextEntityType.bold),
        TextEntity(offset: 6, length: 7, type: TextEntityType.italic),
      ]),
    );

    expect(resolved.text, '@trokkai is this true?');
    expect(resolved.entities.map((e) => (e.offset, e.length)), [
      (0, 22),
      (9, 7),
    ]);
  });

  group('TrokMention.typing', () {
    test('finds an @ word that could still become @Trok', () {
      for (final text in [
        '@',
        '@t',
        'hey @tr',
        'so @TRO',
        'and @Trok',
        'and @troka',
        'and @tr0k',
        'and @trokagent',
        'and @trokkai',
      ]) {
        expect(TrokMention.typing(typed(text)), isNotNull, reason: text);
      }
    });

    test('ignores other mentions and finished words', () {
      for (final text in [
        '@durov',
        '@trokx',
        'me@t',
        'trok',
        '@Trok ',
        'no at sign',
      ]) {
        expect(TrokMention.typing(typed(text)), isNull, reason: text);
      }
    });

    test('only at the end of the word the cursor is in', () {
      expect(TrokMention.typing(typed('@trokx', 3)), isNull);
      expect(TrokMention.typing(typed('@tr and more', 3)), isNotNull);
    });
  });

  test('completing puts @Trok and one space in place', () {
    final middle = TrokMention.complete(typed('hey @tr and more', 7));
    expect(middle.text, 'hey @Trok and more');
    expect(middle.selection.baseOffset, 'hey @Trok '.length);

    final end = TrokMention.complete(typed('hey @trok'));
    expect(end.text, 'hey @Trok ');
    expect(end.selection.baseOffset, end.text.length);
  });

  testWidgets('a mention of any of Trok\'s bots reads @Trok', (tester) async {
    const text = 'Asked @trokagent and @durov';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TextEntityRenderer(
            selectable: false,
            text: text,
            entities: [
              TextEntity(offset: 6, length: 10, type: TextEntityType.mention),
              TextEntity(offset: 21, length: 6, type: TextEntityType.mention),
            ],
          ),
        ),
      ),
    );
    final drawn = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((rich) => rich.text.toPlainText())
        .join();
    expect(drawn, contains('Asked @Trok and @durov'));
    expect(drawn, isNot(contains('trokagent')));
  });

  testWidgets('the suggestion shows while Trok is typed and completes it', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [trokClientProvider.overrideWithValue(_Client())],
        child: MaterialApp(
          home: Scaffold(body: TrokMentionSuggestion(controller: controller)),
        ),
      ),
    );
    expect(find.text(AppStrings.trokMentionHint), findsNothing);

    controller.value = typed('what is this @tr');
    await tester.pump();
    expect(find.text(AppStrings.trokMentionHint), findsOneWidget);

    await tester.tap(find.text(AppStrings.trokMentionHint));
    await tester.pump();
    expect(controller.text, 'what is this @Trok ');
    expect(find.text(AppStrings.trokMentionHint), findsNothing);
  });
}
