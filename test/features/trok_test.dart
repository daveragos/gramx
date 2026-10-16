import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';
import 'package:gramx/features/trok/data/preview_trok_client.dart';
import 'package:gramx/features/trok/data/trok_client.dart';
import 'package:gramx/features/trok/domain/trok_models.dart';
import 'package:gramx/features/trok/presentation/trok_controller.dart';

Post post(
  String channel,
  int messageId, {
  String text = '',
  bool read = false,
  DateTime? at,
}) => Post(
  id: '${channel.hashCode}_$messageId',
  chatId: channel.hashCode,
  channelId: '${channel.hashCode}',
  messageId: messageId,
  channelTitle: channel,
  text: text,
  isRead: read,
  publishedAt: at ?? DateTime(2026, 10, 16, 9, messageId),
);

/// Answers from a stream the test drives, and records what it was asked.
class _Client implements TrokClient {
  final requests = <TrokRequest>[];
  StreamController<TrokEvent>? answer;
  var cancelled = 0;

  @override
  Stream<TrokEvent> ask(TrokRequest request) {
    requests.add(request);
    final controller = StreamController<TrokEvent>(onCancel: () => cancelled++);
    answer = controller;
    return controller.stream;
  }
}

void main() {
  group('TrokController', () {
    late _Client client;
    late ProviderContainer container;

    TrokController trok() => container.read(trokControllerProvider.notifier);
    TrokState state() => container.read(trokControllerProvider);
    TrokAnswer lastAnswer() => state().active!.lastAnswer!;

    setUp(() {
      client = _Client();
      container = ProviderContainer(
        overrides: [
          trokClientProvider.overrideWithValue(client),
          trokFeedProvider.overrideWithValue([post('Nasa', 1)]),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('a question starts a conversation with a thinking answer', () {
      trok().ask('  What did I miss?  ');

      final conversation = state().active!;
      expect(conversation.title, 'What did I miss?');
      expect(conversation.turns, hasLength(2));
      expect(
        (conversation.turns.first as TrokQuestion).text,
        'What did I miss?',
      );
      expect(lastAnswer().state, TrokAnswerState.thinking);
      expect(state().isAnswering, isTrue);
      expect(client.requests.single.feed, hasLength(1));
    });

    test('a blank question is not asked', () {
      trok().ask('   ');
      expect(state().conversations, isEmpty);
      expect(client.requests, isEmpty);
    });

    test('steps, text, sources and follow-ups fill the answer', () async {
      trok().ask('Hi');
      client.answer!
        ..add(const TrokStep('Reading'))
        ..add(
          const TrokText('Hello', [
            TextEntity(offset: 0, length: 5, type: TextEntityType.bold),
          ]),
        )
        ..add(TrokSources([TrokSource.fromPost(post('Nasa', 1, text: 'Moon'))]))
        ..add(const TrokFollowUps(['More?']));
      await pumpEventQueue();

      var answer = lastAnswer();
      expect(answer.steps, ['Reading']);
      expect(answer.text, 'Hello');
      expect(answer.entities.single.type, TextEntityType.bold);
      expect(answer.state, TrokAnswerState.streaming);
      expect(answer.thoughtFor, isNotNull);
      expect(answer.sources.single.snippet, 'Moon');
      expect(answer.followUps, ['More?']);

      await client.answer!.close();
      await pumpEventQueue();
      answer = lastAnswer();
      expect(answer.state, TrokAnswerState.done);
      expect(state().isAnswering, isFalse);
    });

    test('stop keeps what arrived and cancels the answer', () async {
      trok().ask('Hi');
      client.answer!.add(const TrokText('Half'));
      await pumpEventQueue();

      trok().stop();
      await pumpEventQueue();
      expect(lastAnswer().state, TrokAnswerState.stopped);
      expect(lastAnswer().text, 'Half');
      expect(client.cancelled, 1);
    });

    test('a failed answer is marked failed', () async {
      trok().ask('Hi');
      client.answer!.addError(StateError('offline'));
      await pumpEventQueue();
      expect(lastAnswer().state, TrokAnswerState.failed);
    });

    test('a follow-up carries the conversation so far', () async {
      trok().ask('First');
      await client.answer!.close();
      await pumpEventQueue();

      trok().ask('Second');
      expect(state().active!.turns, hasLength(4));
      expect(client.requests.last.history, hasLength(2));
      expect(state().conversations, hasLength(1));
    });

    test('regenerate replaces the last answer to the same question', () async {
      trok().ask('Why?');
      client.answer!.add(const TrokText('Because'));
      await client.answer!.close();
      await pumpEventQueue();
      final first = lastAnswer();

      trok().regenerate();
      final turns = state().active!.turns;
      expect(turns, hasLength(2));
      expect(lastAnswer().id, isNot(first.id));
      expect(lastAnswer().state, TrokAnswerState.thinking);
      expect(client.requests.last.prompt, 'Why?');
      expect(client.requests.last.history, isEmpty);
    });

    test('asking about a post starts a new conversation about it', () async {
      trok().ask('Earlier');
      await client.answer!.close();
      await pumpEventQueue();

      final subject = post('Addis Standard', 7, text: 'Rain tomorrow.');
      trok().askAboutPost(subject, TrokPostAction.factCheck);

      expect(state().conversations, hasLength(2));
      final question = state().active!.turns.first as TrokQuestion;
      expect(question.text, AppStrings.trokPostFactCheck);
      expect(question.post, subject);
      expect(state().active!.title, contains('Addis Standard'));
      expect(client.requests.last.post, subject);
      expect(client.requests.last.action, TrokPostAction.factCheck);
      expect(state().draftPost, isNull);
    });

    test('a follow-up stays about the post without quoting it again', () async {
      final subject = post('Addis Standard', 7, text: 'Rain tomorrow.');
      trok().askAboutPost(subject, TrokPostAction.explain);
      await client.answer!.close();
      await pumpEventQueue();

      trok().ask('Why does it matter?');
      final followUp = state().active!.turns[2] as TrokQuestion;
      expect(followUp.post, isNull);
      expect(client.requests.last.post, subject);
      expect(client.requests.last.action, isNull);
    });

    test('a new chat stops the answer and keeps the old one in history', () {
      trok().ask('Hi');
      trok().startNew();
      expect(state().activeId, isNull);
      expect(
        state().conversations.single.lastAnswer!.state,
        TrokAnswerState.stopped,
      );

      trok().open(state().conversations.single.id);
      expect(state().active, isNotNull);
    });

    test('think goes with the question', () {
      trok().setThink(true);
      trok().ask('Hard one');
      expect(client.requests.single.think, isTrue);
    });
  });

  group('PreviewTrokClient', () {
    const client = PreviewTrokClient(
      pace: Duration.zero,
      stepPace: Duration.zero,
    );

    Future<List<TrokEvent>> ask(TrokRequest request) =>
        client.ask(request).toList();

    test('catching up groups unread posts by the busiest channel', () async {
      final events = await ask(
        TrokRequest(
          prompt: AppStrings.trokStarterCatchUpPrompt,
          feed: [
            post('Nasa', 1, text: 'Launch moved to Friday. More soon.'),
            post('Nasa', 2, text: 'Crew is ready.'),
            post('BBC', 3, text: 'Markets rise.'),
            post('Old', 4, text: 'Already read.', read: true),
          ],
        ),
      );

      final text = events.whereType<TrokText>().last;
      expect(text.text, contains('Nasa'));
      expect(text.text, contains('(2 new)'));
      expect(text.text, contains('BBC'));
      expect(text.text, isNot(contains('Already read')));
      expect(text.text.indexOf('Nasa'), lessThan(text.text.indexOf('BBC')));

      final sources = events.whereType<TrokSources>().single.sources;
      expect(sources.map((s) => s.channelTitle), ['Nasa', 'BBC']);
      expect(events.whereType<TrokStep>().first.label, contains('3 unread'));
    });

    test('streams growing text with entities inside it', () async {
      final events = await ask(
        TrokRequest(
          prompt: 'Explain',
          post: post('Nasa', 1, text: 'Launch moved to Friday.'),
          action: TrokPostAction.explain,
        ),
      );
      final texts = events.whereType<TrokText>().toList();
      expect(texts.length, greaterThan(3));
      for (var i = 1; i < texts.length; i++) {
        expect(texts[i].text.startsWith(texts[i - 1].text), isTrue);
      }
      final full = texts.last;
      for (final e in full.entities) {
        expect(e.offset + e.length, lessThanOrEqualTo(full.text.length));
      }
      expect(full.text, contains('Launch moved to Friday.'));
    });

    test('a question finds the posts that mention it', () async {
      final events = await ask(
        TrokRequest(
          prompt: 'Any news about the launch?',
          feed: [
            post('Nasa', 1, text: 'The launch is on Friday.'),
            post('BBC', 2, text: 'Weather today.'),
          ],
        ),
      );
      final sources = events.whereType<TrokSources>().single.sources;
      expect(sources.single.channelTitle, 'Nasa');
    });

    test('common short words do not count as a match', () async {
      final events = await ask(
        TrokRequest(
          prompt: AppStrings.trokPostFactCheck,
          post: post('Shop', 1, text: 'All of your orders are on the way.'),
          action: TrokPostAction.factCheck,
          feed: [
            post('Other', 2, text: 'Are all of your plans for the week set?'),
          ],
        ),
      );
      expect(events.whereType<TrokSources>(), isEmpty);
    });

    test('thinking adds a step', () async {
      final quick = await ask(const TrokRequest(prompt: 'Hello there'));
      final slow = await ask(
        const TrokRequest(prompt: 'Hello there', think: true),
      );
      expect(
        slow.whereType<TrokStep>().length,
        quick.whereType<TrokStep>().length + 1,
      );
    });
  });
}
