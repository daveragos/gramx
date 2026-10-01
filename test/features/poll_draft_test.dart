import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/compose/data/compose_repository.dart';
import 'package:gramx/features/compose/domain/poll_draft.dart';
import 'package:handy_tdlib/api.dart' as td;

/// A valid draft. Each test breaks one rule of it.
PollDraft valid() =>
    const PollDraft(question: 'Best colour?', options: ['Red', 'Blue']);

void main() {
  group('PollDraft', () {
    test('a question and two options is sendable', () {
      expect(valid().error, isNull);
      expect(valid().canSend, isTrue);
    });

    test('a poll with no question cannot be sent', () {
      expect(valid().withQuestion('   ').error, PollDraftError.questionEmpty);
    });

    test('a question past Telegram\'s ceiling is named as such', () {
      final long = 'x' * (PollDraft.maxQuestionLength + 1);
      expect(valid().withQuestion(long).error, PollDraftError.questionTooLong);
    });

    test('blank option rows do not count towards the minimum', () {
      final draft = valid().addOption().withOption(1, '  ');
      expect(draft.options.length, 3);
      expect(draft.filledOptions, ['Red']);
      expect(draft.error, PollDraftError.tooFewOptions);
    });

    test('an option past the per-option ceiling is named as such', () {
      final long = 'x' * (PollDraft.maxOptionLength + 1);
      expect(valid().withOption(1, long).error, PollDraftError.optionTooLong);
    });

    test('two options saying the same thing is refused', () {
      expect(
        valid().withOption(1, 'Red').error,
        PollDraftError.duplicateOptions,
      );
    });

    test('options are trimmed before they are compared', () {
      expect(
        valid().withOption(1, '  Red  ').error,
        PollDraftError.duplicateOptions,
      );
    });

    test('a quiz with nothing marked correct cannot be sent', () {
      final quiz = valid().withKind(PollKind.quiz);
      expect(quiz.error, PollDraftError.quizNeedsAnswer);
      expect(quiz.withCorrectOption(1).error, isNull);
    });

    test('a quiz cannot also take several answers', () {
      final quiz = valid().withMultipleAnswers(true).withKind(PollKind.quiz);
      expect(quiz.allowsMultipleAnswers, isFalse);
      expect(quiz.withMultipleAnswers(true).allowsMultipleAnswers, isFalse);
    });

    test('turning a quiz back into a poll drops the right answer', () {
      final back = valid()
          .withKind(PollKind.quiz)
          .withCorrectOption(0)
          .withKind(PollKind.regular);
      expect(back.correctOptionIndex, isNull);
    });

    test('cannot grow past Telegram\'s ten options', () {
      var draft = valid();
      while (draft.canAddOption) {
        draft = draft.addOption();
      }
      expect(draft.options.length, PollDraft.maxOptions);
      expect(draft.addOption().options.length, PollDraft.maxOptions);
    });

    test('cannot shrink below two options', () {
      final draft = valid();
      expect(draft.canRemoveOption, isFalse);
      expect(draft.removeOption(0).options.length, PollDraft.minOptions);
    });

    // Without the shift, a different option would silently become correct.
    test('removing a row above the right answer moves the answer with it', () {
      final quiz = const PollDraft(
        question: 'Which?',
        options: ['A', 'B', 'C'],
      ).withKind(PollKind.quiz).withCorrectOption(2);

      final after = quiz.removeOption(0);
      expect(after.filledOptions, ['B', 'C']);
      expect(after.correctOptionIndex, 1);
    });

    test('removing the right answer itself clears it', () {
      final quiz = const PollDraft(
        question: 'Which?',
        options: ['A', 'B', 'C'],
      ).withKind(PollKind.quiz).withCorrectOption(0);

      final after = quiz.removeOption(0);
      expect(after.correctOptionIndex, isNull);
      expect(after.error, PollDraftError.quizNeedsAnswer);
    });
  });

  group('poll content for TDLib', () {
    test('a regular poll carries its multiple-answer setting', () {
      final content =
          ComposeMessages.pollContent(valid().withMultipleAnswers(true))
              as td.InputMessagePoll;

      expect(content.question.text, 'Best colour?');
      expect([for (final o in content.options) o.text], ['Red', 'Blue']);
      expect(content.isAnonymous, isTrue);
      expect((content.type as td.PollTypeRegular).allowMultipleAnswers, isTrue);
    });

    test(
      'a quiz carries the index of the filled option, not the typed one',
      () {
        // The blank row makes the typed index and the sent index differ.
        final quiz = const PollDraft(
          question: 'Which?',
          options: ['A', '', 'C'],
        ).withKind(PollKind.quiz).withCorrectOption(1);

        final content =
            ComposeMessages.pollContent(quiz) as td.InputMessagePoll;
        expect([for (final o in content.options) o.text], ['A', 'C']);
        expect((content.type as td.PollTypeQuiz).correctOptionId, 1);
      },
    );

    test('the bot-only fields are left at zero', () {
      final content =
          ComposeMessages.pollContent(valid()) as td.InputMessagePoll;
      expect(content.openPeriod, 0);
      expect(content.closeDate, 0);
      expect(content.isClosed, isFalse);
    });
  });
}
