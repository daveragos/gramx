import 'package:flutter/foundation.dart';

/// The two shapes a Telegram poll takes.
///
/// A quiz is not a poll with a flag on it — it has exactly one right answer,
/// cannot accept several, and shows the answer back the moment somebody votes.
/// Keeping them as two kinds rather than a bool is what lets [PollDraft.error]
/// say *why* a quiz with no answer marked cannot be sent.
enum PollKind { regular, quiz }

/// Why a poll cannot be sent yet. Null means it can.
///
/// Each case is a sentence the composer shows; none of them is reachable by
/// accident, because the send button is off until this is null.
enum PollDraftError {
  /// No question typed.
  questionEmpty,

  /// Question past Telegram's ceiling.
  questionTooLong,

  /// Fewer than two options carry any text.
  tooFewOptions,

  /// One of the options is past Telegram's per-option ceiling.
  optionTooLong,

  /// Two options say the same thing. Telegram accepts this; a reader cannot.
  duplicateOptions,

  /// A quiz with nothing marked correct.
  quizNeedsAnswer,
}

/// A poll being written, and the rules about when it may be sent.
///
/// Pure and TDLib-free on purpose. Telegram's limits — 1–255 characters of
/// question, two to ten options of 1–100 characters, exactly one right answer
/// on a quiz — are the kind of thing that gets half-remembered at three call
/// sites, and a poll that trips one of them comes back as a flat rejection with
/// no clue which limit it hit. They live here once, and [error] names the one
/// that is currently broken.
///
/// [options] is kept at its full typed length, blanks and all, because it is
/// what the option fields are drawn from. Everything that asks "is this
/// sendable" reads [filledOptions] instead, so a trailing empty row a writer
/// has not used yet never counts against them.
@immutable
class PollDraft {
  /// Telegram's question ceiling for a non-bot account.
  static const int maxQuestionLength = 255;

  /// Telegram's per-option ceiling.
  static const int maxOptionLength = 100;

  static const int minOptions = 2;
  static const int maxOptions = 10;

  /// How many option fields a fresh poll opens with. Telegram's minimum, so
  /// the composer starts at the smallest sendable poll rather than at one row.
  static const int initialOptions = minOptions;

  final String question;

  /// Every option row, in order, including any left blank.
  final List<String> options;

  final PollKind kind;

  /// Whether voters are named. Telegram refuses a non-anonymous poll in a
  /// channel, which is why the composer hides the switch there rather than
  /// offering a setting that would be rejected on send.
  final bool isAnonymous;

  /// Regular polls only — a quiz has one right answer by definition.
  final bool allowsMultipleAnswers;

  /// Index into [filledOptions], not into [options]: the blanks are dropped
  /// before the poll goes, and an index into the typed list would point at the
  /// wrong answer for any poll with a gap in it.
  final int? correctOptionIndex;

  const PollDraft({
    this.question = '',
    this.options = const ['', ''],
    this.kind = PollKind.regular,
    this.isAnonymous = true,
    this.allowsMultipleAnswers = false,
    this.correctOptionIndex,
  });

  bool get isQuiz => kind == PollKind.quiz;

  /// The options that will actually be sent: trimmed, blanks dropped.
  List<String> get filledOptions => [
    for (final option in options)
      if (option.trim().isNotEmpty) option.trim(),
  ];

  /// Whether another option row may be added.
  bool get canAddOption => options.length < maxOptions;

  /// Whether a row may be taken away. Never below Telegram's minimum, so the
  /// remove control disappears rather than producing an unsendable poll.
  bool get canRemoveOption => options.length > minOptions;

  /// The first rule this draft breaks, or null if it breaks none.
  ///
  /// Ordered the way somebody fills the form in — question, then options, then
  /// the quiz answer — so the message shown is about the part they are on
  /// rather than about a field they have not reached.
  PollDraftError? get error {
    final trimmedQuestion = question.trim();
    if (trimmedQuestion.isEmpty) return PollDraftError.questionEmpty;
    if (trimmedQuestion.length > maxQuestionLength) {
      return PollDraftError.questionTooLong;
    }

    final filled = filledOptions;
    if (filled.length < minOptions) return PollDraftError.tooFewOptions;
    if (filled.any((option) => option.length > maxOptionLength)) {
      return PollDraftError.optionTooLong;
    }
    if (filled.toSet().length != filled.length) {
      return PollDraftError.duplicateOptions;
    }

    if (isQuiz) {
      final answer = correctOptionIndex;
      if (answer == null || answer < 0 || answer >= filled.length) {
        return PollDraftError.quizNeedsAnswer;
      }
    }

    return null;
  }

  bool get canSend => error == null;

  /// True once anything has been typed — what a discard confirmation asks.
  bool get isEmpty => question.trim().isEmpty && filledOptions.isEmpty;

  PollDraft withQuestion(String value) => _copy(question: value);

  /// Replaces one option row by position.
  PollDraft withOption(int index, String value) {
    if (index < 0 || index >= options.length) return this;
    final next = [...options];
    next[index] = value;
    return _copy(options: next);
  }

  PollDraft addOption() {
    if (!canAddOption) return this;
    return _copy(options: [...options, '']);
  }

  /// Drops one option row, and the quiz answer with it if that is what it was.
  ///
  /// The answer is an index into [filledOptions], so removing a row above it
  /// shifts it down. Leaving it alone would silently mark a different option
  /// correct — the failure a reader would only notice after voting.
  PollDraft removeOption(int index) {
    if (!canRemoveOption || index < 0 || index >= options.length) return this;

    final removedWasFilled = options[index].trim().isNotEmpty;
    final filledBefore = [
      for (var i = 0; i < index; i++)
        if (options[i].trim().isNotEmpty) i,
    ].length;

    final next = [...options]..removeAt(index);

    var answer = correctOptionIndex;
    if (answer != null && removedWasFilled) {
      if (answer == filledBefore) {
        answer = null;
      } else if (answer > filledBefore) {
        answer = answer - 1;
      }
    }

    return PollDraft(
      question: question,
      options: next,
      kind: kind,
      isAnonymous: isAnonymous,
      allowsMultipleAnswers: allowsMultipleAnswers,
      correctOptionIndex: answer,
    );
  }

  /// Switches between a poll and a quiz.
  ///
  /// A quiz cannot take several answers, so becoming one drops that setting
  /// rather than carrying a flag Telegram would reject. Becoming a regular poll
  /// again drops the right answer, which no longer means anything.
  PollDraft withKind(PollKind value) {
    if (value == kind) return this;
    return PollDraft(
      question: question,
      options: options,
      kind: value,
      isAnonymous: isAnonymous,
      allowsMultipleAnswers: value == PollKind.quiz
          ? false
          : allowsMultipleAnswers,
      correctOptionIndex: value == PollKind.quiz ? correctOptionIndex : null,
    );
  }

  PollDraft withAnonymous(bool value) => _copy(isAnonymous: value);

  PollDraft withMultipleAnswers(bool value) {
    if (isQuiz) return this;
    return _copy(allowsMultipleAnswers: value);
  }

  /// Marks one of [filledOptions] correct. Only means anything on a quiz.
  PollDraft withCorrectOption(int? index) {
    if (!isQuiz) return this;
    return PollDraft(
      question: question,
      options: options,
      kind: kind,
      isAnonymous: isAnonymous,
      allowsMultipleAnswers: allowsMultipleAnswers,
      correctOptionIndex: index,
    );
  }

  PollDraft _copy({
    String? question,
    List<String>? options,
    bool? isAnonymous,
    bool? allowsMultipleAnswers,
  }) {
    return PollDraft(
      question: question ?? this.question,
      options: options ?? this.options,
      kind: kind,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      allowsMultipleAnswers: allowsMultipleAnswers ?? this.allowsMultipleAnswers,
      correctOptionIndex: correctOptionIndex,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PollDraft &&
      other.question == question &&
      listEquals(other.options, options) &&
      other.kind == kind &&
      other.isAnonymous == isAnonymous &&
      other.allowsMultipleAnswers == allowsMultipleAnswers &&
      other.correctOptionIndex == correctOptionIndex;

  @override
  int get hashCode => Object.hash(
    question,
    Object.hashAll(options),
    kind,
    isAnonymous,
    allowsMultipleAnswers,
    correctOptionIndex,
  );
}
