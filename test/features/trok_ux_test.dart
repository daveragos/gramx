import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';
import 'package:gramx/features/guest/domain/reader_capabilities.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/features/settings/data/app_settings.dart';
import 'package:gramx/features/trok/data/trok_citations.dart';
import 'package:gramx/features/trok/data/trok_client.dart';
import 'package:gramx/features/trok/data/trok_voice.dart';
import 'package:gramx/features/trok/data/trok_wire.dart';
import 'package:gramx/features/trok/domain/trok_models.dart';
import 'package:gramx/features/trok/presentation/trok_controller.dart';
import 'package:gramx/features/trok/presentation/trok_inline_translation.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_composer.dart';

const _persian = 'یک مقاله‌ی جدید آماده کردیم که می‌تونه کمک کنه';
const _english = 'The new release is out and it fixes the crash on start.';
const _amharic = 'አዲሱ ስሪት ወጥቷል እና ሲጀመር የሚፈጠረውን ችግር ያስተካክላል።';

Post post(String text, {String id = '-100_1048576'}) => Post(
  id: id,
  chatId: -100,
  channelId: '-100',
  messageId: 1048576,
  channelTitle: 'Golang Insights',
  text: text,
  publishedAt: DateTime.utc(2026, 10, 21),
);

/// Translates whatever it is asked, and records what happens.
class _Client implements TrokClient {
  final requests = <TrokRequest>[];
  final deleted = <String>[];
  StreamController<TrokEvent>? answer;

  @override
  Stream<TrokEvent> ask(TrokRequest request) {
    requests.add(request);
    return (answer = StreamController<TrokEvent>()).stream;
  }

  @override
  Future<List<TrokConversation>> conversations() async => const [];

  @override
  Future<TrokConversation> conversation(String remoteId) =>
      throw const TrokFailure('not_found', 'Gone');

  @override
  Future<void> deleteConversation(String remoteId) async =>
      deleted.add(remoteId);

  @override
  Future<TrokAllowance> allowance() async =>
      const TrokAllowance(questionsPerDay: 30, usedToday: 0);

  @override
  Future<void> announceMention(int chatId) async {}
}

/// Hears whatever the test says, in the language it was asked for.
class _Voice implements TrokVoice {
  final bool works;
  String? language;
  void Function(String words, bool done)? onWords;
  var stopped = 0;

  _Voice({this.works = true});

  @override
  Future<bool> listen({
    required String language,
    required void Function(String words, bool done) onWords,
  }) async {
    if (!works) return false;
    this.language = language;
    this.onWords = onWords;
    return true;
  }

  @override
  Future<void> stop() async {
    stopped++;
    onWords?.call('', true);
  }
}

void main() {
  group('TrokCitations.number', () {
    const web = TrokWebSource(
      url: 'https://www.example.com/report/',
      title: 'Report',
      site: 'example.com',
    );
    const held = TrokPostSource(
      channelTitle: 'Durov',
      snippet: 'Hi',
      link: 'https://t.me/Durov/42',
    );

    test('numbers each cited source in card order, inside its link', () {
      const text = 'Two outlets report it and Durov said so.';
      final numbered = TrokCitations.number(
        text,
        const [
          TextEntity(offset: 0, length: 3, type: TextEntityType.bold),
          TextEntity(
            offset: 4,
            length: 7,
            type: TextEntityType.textUrl,
            url: 'https://example.com/report',
          ),
          TextEntity(
            offset: 26,
            length: 5,
            type: TextEntityType.textUrl,
            url: 'https://t.me/durov/42',
          ),
        ],
        const [held, web],
      );
      expect(numbered.text, 'Two outlets² report it and Durov¹ said so.');
      final links = numbered.entities
          .where((e) => e.type == TextEntityType.textUrl)
          .map((e) => numbered.text.substring(e.offset, e.offset + e.length));
      expect(links, ['outlets²', 'Durov¹']);
      // Entities before the first number keep their place.
      expect(numbered.entities.first.offset, 0);
      expect(numbered.entities.first.length, 3);
    });

    test('leaves links to nothing in the cards alone', () {
      const text = 'See the docs.';
      final numbered = TrokCitations.number(
        text,
        const [
          TextEntity(
            offset: 4,
            length: 8,
            type: TextEntityType.textUrl,
            url: 'https://elsewhere.org',
          ),
        ],
        const [web],
      );
      expect(numbered.text, text);
    });

    test('writes numbers in superscript', () {
      expect(TrokCitations.superscript(12), '¹²');
    });
  });

  group('translation', () {
    test('is offered for a post not in the reader\'s language', () {
      expect(TrokWire.needsTranslation(_persian, 'en'), isTrue);
      expect(TrokWire.needsTranslation(_english, 'en'), isFalse);
      expect(TrokWire.needsTranslation(_english, 'am'), isTrue);
      expect(TrokWire.needsTranslation(_amharic, 'am'), isFalse);
      expect(TrokWire.needsTranslation('warns', 'en'), isFalse);
      // Short English with few common words is still English.
      expect(
        TrokWire.needsTranslation(
          "Guess who's almost done with todays prompt early ?",
          'en',
        ),
        isFalse,
      );
      // Afaan Oromo, in Latin letters too, is offered.
      expect(
        TrokWire.needsTranslation(
          'Barattoonni yuunivarsiitii hundi galmee isaanii '
              'torban dhufu xumuruu qabu jedhe biiroon barnootaa',
          'en',
        ),
        isTrue,
      );
    });

    test('an Afaan Oromo reader is offered English and Ethiopic posts', () {
      expect(TrokWire.needsTranslation(_english, 'om'), isTrue);
      expect(TrokWire.needsTranslation(_amharic, 'om'), isTrue);
      expect(TrokWire.needsTranslation(_persian, 'om'), isTrue);
      expect(
        TrokWire.needsTranslation(
          'Barattoonni yuunivarsiitii hundi galmee isaanii '
              'torban dhufu xumuruu qabu jedhe biiroon barnootaa',
          'om',
        ),
        isFalse,
      );
      expect(
        TrokWire.translateTarget(post(_english), 'en', answerLanguage: 'om'),
        'om',
      );
    });

    test('an Amharic reader gets Amharic, unless the post is Ethiopic', () {
      expect(
        TrokWire.translateTarget(post(_persian), 'en', answerLanguage: 'am'),
        'am',
      );
      expect(
        TrokWire.translateTarget(post(_amharic), 'en', answerLanguage: 'am'),
        'en',
      );
      expect(TrokWire.translateTarget(post(_persian), 'en'), 'en');
    });

    test('the answer language follows the phone unless chosen', () {
      expect(TrokLanguage.device.code('am'), 'am');
      expect(TrokLanguage.device.code('fr'), 'en');
      expect(TrokLanguage.amharic.code('en'), 'am');
      expect(TrokLanguage.oromo.code('en'), 'om');
      expect(TrokLanguage.device.code('om'), 'om');
      final saved = AppSettings.decode(
        const AppSettings(trokLanguage: TrokLanguage.amharic).encode(),
      );
      expect(saved.trokLanguage, TrokLanguage.amharic);
      expect(AppSettings.decode('{}').trokLanguage, TrokLanguage.device);
    });
  });

  test('a progress step replaces the last, others add on', () {
    var answer = TrokAnswer(id: 'a', startedAt: DateTime.utc(2026));
    final now = DateTime.utc(2026);
    answer = answer.apply(const TrokStep('Sending the video'), now);
    answer = answer.apply(
      const TrokStep('Sending the video · 40%', replacesLast: true),
      now,
    );
    answer = answer.apply(const TrokStep('Reading the post'), now);
    expect(answer.steps, ['Sending the video · 40%', 'Reading the post']);
  });

  group('TrokInlineTranslation', () {
    late _Client client;

    Future<void> pump(WidgetTester tester, Post post) => tester.pumpWidget(
      ProviderScope(
        overrides: [
          trokClientProvider.overrideWithValue(client),
          trokAnswerLanguageProvider.overrideWithValue('en'),
          trokChannelUsernameProvider.overrideWithValue((_) => null),
          readerCapabilitiesProvider.overrideWithValue(
            ReaderCapabilities.signedIn,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TrokInlineTranslation(post: post, style: const TextStyle()),
          ),
        ),
      ),
    );

    setUp(() => client = _Client());

    testWidgets('a post in the reader\'s language offers nothing', (
      tester,
    ) async {
      await pump(tester, post(_english));
      expect(find.text(AppStrings.trokTranslatePost), findsNothing);
    });

    testWidgets('translates in place and keeps History clear', (tester) async {
      await pump(tester, post(_persian));
      await tester.tap(find.text(AppStrings.trokTranslatePost));
      await tester.pump();

      final request = client.requests.single;
      expect(request.action, TrokPostAction.translate);
      expect(request.feed, isEmpty);
      expect(find.text(AppStrings.trokTranslating), findsOneWidget);

      client.answer!
        ..add(
          const TrokStarted(
            conversationId: 'c_9',
            answerId: 'a_9',
            title: 'Translate',
          ),
        )
        ..add(const TrokText('We wrote a new article that can help'));
      await client.answer!.close();
      await tester.pump();
      await tester.pump();

      expect(find.text(AppStrings.trokTranslatedBy), findsOneWidget);
      expect(
        find.textContaining('We wrote a new article', findRichText: true),
        findsOneWidget,
      );
      expect(client.deleted, ['c_9']);

      await tester.tap(find.text(AppStrings.trokHideTranslation));
      await tester.pump();
      expect(find.text(AppStrings.trokShowTranslation), findsOneWidget);

      // Opening it again asks nothing more.
      await tester.tap(find.text(AppStrings.trokShowTranslation));
      await tester.pump();
      expect(client.requests, hasLength(1));
      expect(find.text(AppStrings.trokTranslatedBy), findsOneWidget);
    });

    testWidgets('a failure says so and offers to try again', (tester) async {
      await pump(tester, post(_persian, id: '-100_2097152'));
      await tester.tap(find.text(AppStrings.trokTranslatePost));
      await tester.pump();
      client.answer!.addError(const TrokFailure('rate_limited', 'Back soon.'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Back soon.'), findsOneWidget);
      expect(find.text(AppStrings.trokRetry), findsOneWidget);
    });
  });

  group('asking by voice', () {
    late TextEditingController text;
    late FocusNode focus;

    Future<void> pump(WidgetTester tester, _Voice voice) {
      text = TextEditingController();
      focus = FocusNode();
      addTearDown(text.dispose);
      addTearDown(focus.dispose);
      return tester.pumpWidget(
        ProviderScope(
          overrides: [
            trokClientProvider.overrideWithValue(_Client()),
            trokFeedProvider.overrideWithValue(const []),
            trokChannelUsernameProvider.overrideWithValue((_) => null),
            trokAnswerLanguageProvider.overrideWithValue('am'),
            trokVoiceProvider.overrideWithValue(voice),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TrokComposer(controller: text, focusNode: focus),
            ),
          ),
        ),
      );
    }

    testWidgets('the words heard fill the box, to read before sending', (
      tester,
    ) async {
      final voice = _Voice();
      await pump(tester, voice);
      await tester.tap(find.byTooltip(AppStrings.trokSpeak));
      await tester.pump();

      expect(voice.language, 'am');
      expect(find.text(AppStrings.trokListening), findsOneWidget);

      voice.onWords!('ይህ እውነት ነው', false);
      await tester.pump();
      expect(text.text, 'ይህ እውነት ነው');
      // Still listening: the box isn't sent yet.
      expect(find.byTooltip(AppStrings.trokStopListening), findsOneWidget);

      voice.onWords!('ይህ እውነት ነው?', true);
      await tester.pump();
      expect(text.text, 'ይህ እውነት ነው?');
      expect(find.byTooltip(AppStrings.trokSend), findsOneWidget);
    });

    testWidgets('tapping again stops listening', (tester) async {
      final voice = _Voice();
      await pump(tester, voice);
      await tester.tap(find.byTooltip(AppStrings.trokSpeak));
      await tester.pump();
      await tester.tap(find.byTooltip(AppStrings.trokStopListening));
      await tester.pump();

      expect(voice.stopped, 1);
      expect(find.byTooltip(AppStrings.trokSpeak), findsOneWidget);
    });

    testWidgets('a phone that can\'t listen says so', (tester) async {
      await pump(tester, _Voice(works: false));
      await tester.tap(find.byTooltip(AppStrings.trokSpeak));
      await tester.pump();

      expect(find.text(AppStrings.trokVoiceUnavailable), findsOneWidget);
      expect(find.byTooltip(AppStrings.trokSpeak), findsOneWidget);
    });
  });
}
