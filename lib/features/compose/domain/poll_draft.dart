import 'package:flutter/foundation.dart';

/// The two shapes a Telegram poll takes.
enum PollKind { regular, quiz }

/// Why a poll can't be sent yet. Null means it can.
enum PollDraftError {
  questionEmpty,

  questionTooLong,

  tooFewOptions,

  optionTooLong,

  /// Two options say the same thing. Telegram accepts it; voters can't tell.
  duplicateOptions,

  quizNeedsAnswer,
}

/// A poll being written, and Telegram's rules for when it may be sent.
/// [options] keeps blank rows; validation reads [filledOptions].
@immutable
class PollDraft {
  /// Telegram's question limit for a non-bot account.
  static const int maxQuestionLength = 255;

  static const int maxOptionLength = 100;

  static const int minOptions = 2;
  static const int maxOptions = 10;

  /// How many option fields a fresh poll opens with.
  static const int initialOptions = minOptions;

  final String question;

  /// Every option row, including blanks.
  final List<String> options;

  final PollKind kind;

  /// Whether voters are named. Telegram refuses a non-anonymous poll in a
  /// channel, so the composer hides the switch there.
  final bool isAnonymous;

  /// Regular polls only.
  final bool allowsMultipleAnswers;

  /// Index into [filledOptions], not [options], since blanks are dropped
  /// before sending.
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

  /// The options that will be sent: trimmed, blanks dropped.
  List<String> get filledOptions => [
    for (final option in options)
      if (option.trim().isNotEmpty) option.trim(),
  ];

  bool get canAddOption => options.length < maxOptions;

  /// Never below Telegram's minimum.
  bool get canRemoveOption => options.length > minOptions;

  /// The first rule this draft breaks, or null, checked in form order.
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

  /// True when nothing has been typed, so discarding needs no confirmation.
  bool get isEmpty => question.trim().isEmpty && filledOptions.isEmpty;

  PollDraft withQuestion(String value) => _copy(question: value);

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

  /// Drops one option row, shifting or clearing the quiz answer to match.
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

  /// Switches between a poll and a quiz, dropping settings the new kind
  /// doesn't support.
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

  /// Marks one of [filledOptions] correct. Quiz only.
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
      allowsMultipleAnswers:
          allowsMultipleAnswers ?? this.allowsMultipleAnswers,
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
