import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';
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
  var listed = <TrokConversation>[];
  final stored = <String, TrokConversation>{};
  final deleted = <String>[];

  @override
  Stream<TrokEvent> ask(TrokRequest request) {
    requests.add(request);
    final controller = StreamController<TrokEvent>(onCancel: () => cancelled++);
    answer = controller;
    return controller.stream;
  }

  @override
  Future<List<TrokConversation>> conversations() async => listed;

  @override
  Future<TrokConversation> conversation(String remoteId) async =>
      stored[remoteId] ?? (throw const TrokFailure('not_found', 'Gone'));

  @override
  Future<void> deleteConversation(String remoteId) async =>
      deleted.add(remoteId);

  @override
  Future<TrokAllowance> allowance() async =>
      const TrokAllowance(questionsPerDay: 30, usedToday: 0);
}

void main() {
  group('TrokConversation.titleFor', () {
    test('a chat about a post is named by the post, not the question', () {
      final summarize = TrokConversation.titleFor(
        question: AppStrings.trokPostSummarizePrompt,
        post: post('Addis Standard', 7, text: 'Rain tomorrow.\nMore below.'),
      );
      final explain = TrokConversation.titleFor(
        question: AppStrings.trokPostSummarizePrompt,
        post: post('Addis Standard', 8, text: 'Fuel prices go up on Monday.'),
      );

      expect(summarize, 'Rain tomorrow.');
      expect(explain, 'Fuel prices go up on Monday.');
    });

    test('a long opening is cut at a word', () {
      final title = TrokConversation.titleFor(
        question: 'Explain this post',
        post: post('Nasa', 1, text: 'word ' * 30),
      );

      expect(title.length, lessThanOrEqualTo(TrokConversation.titleLength + 1));
      expect(title, endsWith('word…'));
    });

    test('a post with no text is named by its channel', () {
      expect(
        TrokConversation.titleFor(question: 'Explain', post: post('Nasa', 1)),
        'Nasa',
      );
    });

    test('a question about no post is its own title', () {
      expect(TrokConversation.titleFor(question: 'Who won?'), 'Who won?');
    });
  });

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
          trokChannelUsernameProvider.overrideWithValue((_) => null),
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
      expect((answer.sources.single as TrokPostSource).snippet, 'Moon');
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
      expect(state().active!.title, 'Rain tomorrow.');
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

    test('posts go with their channel\'s username', () {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          trokClientProvider.overrideWithValue(client),
          trokFeedProvider.overrideWithValue([post('Nasa', 1)]),
          trokChannelUsernameProvider.overrideWithValue((_) => 'nasa'),
        ],
      );
      trok().askAboutPost(post('Nasa', 2), TrokPostAction.summarize);
      expect(client.requests.last.post!.channelUsername, 'nasa');
      expect(client.requests.last.feed.single.channelUsername, 'nasa');
      // The question still quotes the post as it was.
      final question = state().active!.turns.first as TrokQuestion;
      expect(question.post!.channelUsername, isNull);
    });

    test('think goes with the question', () {
      trok().setThink(true);
      trok().ask('Hard one');
      expect(client.requests.single.think, isTrue);
    });
  });

  group('TrokController with Trok\'s ids', () {
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
          trokChannelUsernameProvider.overrideWithValue((_) => null),
        ],
      );
    });

    tearDown(() => container.dispose());

    Future<void> answerWith(String conversationId, String answerId) async {
      client.answer!.add(
        TrokStarted(
          conversationId: conversationId,
          answerId: answerId,
          title: 'From Trok',
        ),
      );
      await client.answer!.close();
      await pumpEventQueue();
    }

    test('the first event names the conversation for follow-ups', () async {
      trok().ask('First');
      expect(client.requests.single.conversationId, isNull);
      await answerWith('c_1', 'a_1');

      expect(state().active!.remoteId, 'c_1');
      // Trok's title echoes the question; the conversation keeps its own.
      expect(state().active!.title, 'First');
      expect(lastAnswer().remoteId, 'a_1');

      trok().ask('Second');
      expect(client.requests.last.conversationId, 'c_1');
    });

    test('regenerating names the answer it replaces', () async {
      trok().ask('Why?');
      await answerWith('c_1', 'a_1');

      trok().regenerate();
      expect(client.requests.last.conversationId, 'c_1');
      expect(client.requests.last.replaceAnswerId, 'a_1');
    });

    test('Trok\'s reason for failing stays on the answer', () async {
      trok().ask('Hi');
      client.answer!.addError(
        const TrokFailure('rate_limited', 'Back at midnight.'),
      );
      await pumpEventQueue();
      expect(lastAnswer().state, TrokAnswerState.failed);
      expect(lastAnswer().failure!.message, 'Back at midnight.');
      expect(lastAnswer().failure!.canRetry, isFalse);
      expect(state().blocked, isNull);
    });

    test('a blocked reader is no longer offered Trok', () async {
      trok().ask('Hi');
      client.answer!.addError(const TrokFailure('blocked', 'Not for you.'));
      await pumpEventQueue();
      expect(state().blocked!.message, 'Not for you.');
    });

    test('History lists Trok\'s chats and opening one fetches it', () async {
      client
        ..listed = [
          TrokConversation(
            id: 'c_9',
            remoteId: 'c_9',
            title: 'Older',
            updatedAt: DateTime(2026, 10, 1),
            isLoaded: false,
          ),
        ]
        ..stored['c_9'] = TrokConversation(
          id: 'c_9',
          remoteId: 'c_9',
          title: 'Older',
          updatedAt: DateTime(2026, 10, 1),
          turns: [
            const TrokQuestion(id: 'q_1', text: 'Old question'),
            TrokAnswer(
              id: 'a_9',
              remoteId: 'a_9',
              startedAt: DateTime(2026, 10, 1),
              state: TrokAnswerState.done,
              text: 'Old answer',
            ),
          ],
        );

      await trok().refreshHistory();
      expect(state().conversations.single.isLoaded, isFalse);

      trok().open('c_9');
      expect(state().active!.isLoaded, isFalse);
      await pumpEventQueue();
      expect(state().active!.turns, hasLength(2));

      trok().ask('And now?');
      expect(client.requests.last.conversationId, 'c_9');
    });

    test('History keeps a chat it already holds, not a copy', () async {
      trok().ask('Mine');
      await answerWith('c_1', 'a_1');
      client.listed = [
        TrokConversation(
          id: 'c_1',
          remoteId: 'c_1',
          title: 'Mine',
          updatedAt: DateTime.now(),
          isLoaded: false,
        ),
      ];

      await trok().refreshHistory();
      expect(state().conversations, hasLength(1));
      expect(state().conversations.single.turns, hasLength(2));
    });

    test('deleting a chat deletes it on Trok\'s server', () async {
      trok().ask('Bye');
      await answerWith('c_1', 'a_1');
      trok().delete(state().active!.id);
      await pumpEventQueue();
      expect(state().conversations, isEmpty);
      expect(client.deleted, ['c_1']);
    });
  });
}
