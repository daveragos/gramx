import 'package:freezed_annotation/freezed_annotation.dart';

part 'poll.freezed.dart';
part 'poll.g.dart';

@freezed
abstract class PollOption with _$PollOption {
  const factory PollOption({
    required String text,
    required int voterCount,
    @Default(0.0) double votePercentage,
    @Default(false) bool isChosen,
    @Default(false) bool isCorrect,
  }) = _PollOption;

  factory PollOption.fromJson(Map<String, dynamic> json) =>
      _$PollOptionFromJson(json);
}

@freezed
abstract class Poll with _$Poll {
  const factory Poll({
    required String id,
    required String question,
    required List<PollOption> options,
    required int totalVoterCount,
    required bool isAnonymous,
    required bool isClosed,
    required bool isQuiz,

    /// Whether a voter may pick more than one option. Regular polls only —
    /// a quiz has exactly one right answer, so Telegram never sets both.
    @Default(false) bool allowsMultipleAnswers,
    int? correctOptionId,
    @Default([]) List<int> chosenOptionIds,
  }) = _Poll;

  factory Poll.fromJson(Map<String, dynamic> json) => _$PollFromJson(json);
}
