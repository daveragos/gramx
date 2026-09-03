// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'poll.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PollOption _$PollOptionFromJson(Map<String, dynamic> json) => _PollOption(
  text: json['text'] as String,
  voterCount: (json['voterCount'] as num).toInt(),
  votePercentage: (json['votePercentage'] as num?)?.toDouble() ?? 0.0,
  isChosen: json['isChosen'] as bool? ?? false,
  isCorrect: json['isCorrect'] as bool? ?? false,
);

Map<String, dynamic> _$PollOptionToJson(_PollOption instance) =>
    <String, dynamic>{
      'text': instance.text,
      'voterCount': instance.voterCount,
      'votePercentage': instance.votePercentage,
      'isChosen': instance.isChosen,
      'isCorrect': instance.isCorrect,
    };

_Poll _$PollFromJson(Map<String, dynamic> json) => _Poll(
  id: json['id'] as String,
  question: json['question'] as String,
  options: (json['options'] as List<dynamic>)
      .map((e) => PollOption.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalVoterCount: (json['totalVoterCount'] as num).toInt(),
  isAnonymous: json['isAnonymous'] as bool,
  isClosed: json['isClosed'] as bool,
  isQuiz: json['isQuiz'] as bool,
  allowsMultipleAnswers: json['allowsMultipleAnswers'] as bool? ?? false,
  correctOptionId: (json['correctOptionId'] as num?)?.toInt(),
  chosenOptionIds:
      (json['chosenOptionIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
);

Map<String, dynamic> _$PollToJson(_Poll instance) => <String, dynamic>{
  'id': instance.id,
  'question': instance.question,
  'options': instance.options,
  'totalVoterCount': instance.totalVoterCount,
  'isAnonymous': instance.isAnonymous,
  'isClosed': instance.isClosed,
  'isQuiz': instance.isQuiz,
  'allowsMultipleAnswers': instance.allowsMultipleAnswers,
  'correctOptionId': instance.correctOptionId,
  'chosenOptionIds': instance.chosenOptionIds,
};
