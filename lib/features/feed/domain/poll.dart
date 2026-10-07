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

    /// Whether a voter may pick more than one option. Never set on a quiz.
    @Default(false) bool allowsMultipleAnswers,
    int? correctOptionId,
    @Default([]) List<int> chosenOptionIds,
  }) = _Poll;

  factory Poll.fromJson(Map<String, dynamic> json) => _$PollFromJson(json);
}

/// [poll] as it looks once [optionIds] are voted for, until Telegram sends
/// the real counts.
Poll pollWithVote(Poll poll, List<int> optionIds) {
  final total = poll.totalVoterCount + 1;
  return poll.copyWith(
    totalVoterCount: total,
    chosenOptionIds: {...poll.chosenOptionIds, ...optionIds}.toList(),
    options: [
      for (final (index, option) in poll.options.indexed)
        if (optionIds.contains(index))
          option.copyWith(
            voterCount: option.voterCount + 1,
            votePercentage: (option.voterCount + 1) / total * 100,
            isChosen: true,
          )
        else
          option.copyWith(votePercentage: option.voterCount / total * 100),
    ],
  );
}
