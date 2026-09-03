import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/chats/data/chat_events.dart';
import 'package:gramx/features/chats/data/chat_message_mapper.dart';
import 'package:gramx/features/chats/data/conversation_state.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';

import '../support/td_fixtures.dart';

ChatMessage mapPoll({
  bool isQuiz = false,
  bool allowMultipleAnswers = false,
  bool isClosed = false,
  int? chosenIndex,
}) => ChatMessageMapper.map(
  TdFixtures.pollMessage(
    id: 100,
    chatId: -1001,
    isQuiz: isQuiz,
    allowMultipleAnswers: allowMultipleAnswers,
    isClosed: isClosed,
    chosenIndex: chosenIndex,
  ),
  users: const {},
  lastReadOutboxMessageId: 0,
);

void main() {
  group('a poll in a conversation', () {
    // The regression this pins: `messagePoll` is content the feed draws in
    // full, so it had no fallback label to borrow, and the bubble mapper had
    // no case for it — the message arrived with no text, no media and no poll,
    // and drew a bubble with nothing inside it.
    test('is not an empty bubble', () {
      final message = mapPoll();

      expect(message.poll, isNotNull);
      expect(message.poll!.question, 'Which one?');
      expect(message.poll!.options.length, 2);
      expect(message.isService, isFalse);
      expect(message.unsupportedKind, isNull);
    });

    test('carries its multiple-answer setting', () {
      expect(mapPoll().poll!.allowsMultipleAnswers, isFalse);
      expect(
        mapPoll(allowMultipleAnswers: true).poll!.allowsMultipleAnswers,
        isTrue,
      );
    });

    test('a quiz says so, and never also takes several answers', () {
      final quiz = mapPoll(isQuiz: true).poll!;
      expect(quiz.isQuiz, isTrue);
      expect(quiz.correctOptionId, 0);
      expect(quiz.allowsMultipleAnswers, isFalse);
    });

    test('a closed poll is still a poll', () {
      expect(mapPoll(isClosed: true).poll!.isClosed, isTrue);
    });

    // Votes land on `updateMessageContent`. The fold used to read only the
    // caption and the media off the new content, so a vote arriving from
    // another client changed nothing on screen.
    test('a vote arriving as a content update reaches the bubble', () {
      final state = ConversationState(
        chatId: -1001,
        messages: [mapPoll()],
      ).apply(
        ChatMessageContentChanged(
          -1001,
          100,
          TdFixtures.pollMessage(
            id: 100,
            chatId: -1001,
            chosenIndex: 1,
          ).content,
        ),
        users: const {},
      );

      expect(state, isNotNull);
      expect(state!.messages.single.poll!.chosenOptionIds, [1]);
      expect(state.messages.single.poll!.totalVoterCount, 1);
    });
  });

  group('voting optimistically', () {
    ConversationState stateWith(ChatMessage message) =>
        ConversationState(chatId: -1001, messages: [message]);

    test('marks the option and adds a voter before the server answers', () {
      final next = stateWith(mapPoll()).withOptimisticVote(100, [0]);

      expect(next, isNotNull);
      final poll = next!.messages.single.poll!;
      expect(poll.chosenOptionIds, [0]);
      expect(poll.totalVoterCount, 1);
      expect(poll.options.first.isChosen, isTrue);
      expect(poll.options.first.voterCount, 1);
      expect(poll.options.first.votePercentage, 100);
      expect(poll.options.last.votePercentage, 0);
    });

    test('several options at once, for a multiple-answer poll', () {
      final next = stateWith(
        mapPoll(allowMultipleAnswers: true),
      ).withOptimisticVote(100, [0, 1]);

      expect(next!.messages.single.poll!.chosenOptionIds, [0, 1]);
    });

    test('a poll already voted in is left alone', () {
      expect(
        stateWith(mapPoll(chosenIndex: 0)).withOptimisticVote(100, [1]),
        isNull,
      );
    });

    test('a closed poll is left alone', () {
      expect(
        stateWith(mapPoll(isClosed: true)).withOptimisticVote(100, [1]),
        isNull,
      );
    });

    test('a message that is not a poll is left alone', () {
      final text = ChatMessageMapper.map(
        TdFixtures.textMessage(id: 100, chatId: -1001),
        users: const {},
        lastReadOutboxMessageId: 0,
      );
      expect(stateWith(text).withOptimisticVote(100, [0]), isNull);
    });

    test('an empty selection does nothing', () {
      expect(stateWith(mapPoll()).withOptimisticVote(100, const []), isNull);
    });
  });
}
