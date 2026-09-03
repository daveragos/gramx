// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'poll.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PollOption {

 String get text; int get voterCount; double get votePercentage; bool get isChosen; bool get isCorrect;
/// Create a copy of PollOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PollOptionCopyWith<PollOption> get copyWith => _$PollOptionCopyWithImpl<PollOption>(this as PollOption, _$identity);

  /// Serializes this PollOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PollOption&&(identical(other.text, text) || other.text == text)&&(identical(other.voterCount, voterCount) || other.voterCount == voterCount)&&(identical(other.votePercentage, votePercentage) || other.votePercentage == votePercentage)&&(identical(other.isChosen, isChosen) || other.isChosen == isChosen)&&(identical(other.isCorrect, isCorrect) || other.isCorrect == isCorrect));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,voterCount,votePercentage,isChosen,isCorrect);

@override
String toString() {
  return 'PollOption(text: $text, voterCount: $voterCount, votePercentage: $votePercentage, isChosen: $isChosen, isCorrect: $isCorrect)';
}


}

/// @nodoc
abstract mixin class $PollOptionCopyWith<$Res>  {
  factory $PollOptionCopyWith(PollOption value, $Res Function(PollOption) _then) = _$PollOptionCopyWithImpl;
@useResult
$Res call({
 String text, int voterCount, double votePercentage, bool isChosen, bool isCorrect
});




}
/// @nodoc
class _$PollOptionCopyWithImpl<$Res>
    implements $PollOptionCopyWith<$Res> {
  _$PollOptionCopyWithImpl(this._self, this._then);

  final PollOption _self;
  final $Res Function(PollOption) _then;

/// Create a copy of PollOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,Object? voterCount = null,Object? votePercentage = null,Object? isChosen = null,Object? isCorrect = null,}) {
  return _then(_self.copyWith(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,voterCount: null == voterCount ? _self.voterCount : voterCount // ignore: cast_nullable_to_non_nullable
as int,votePercentage: null == votePercentage ? _self.votePercentage : votePercentage // ignore: cast_nullable_to_non_nullable
as double,isChosen: null == isChosen ? _self.isChosen : isChosen // ignore: cast_nullable_to_non_nullable
as bool,isCorrect: null == isCorrect ? _self.isCorrect : isCorrect // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PollOption].
extension PollOptionPatterns on PollOption {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PollOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PollOption() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PollOption value)  $default,){
final _that = this;
switch (_that) {
case _PollOption():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PollOption value)?  $default,){
final _that = this;
switch (_that) {
case _PollOption() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String text,  int voterCount,  double votePercentage,  bool isChosen,  bool isCorrect)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PollOption() when $default != null:
return $default(_that.text,_that.voterCount,_that.votePercentage,_that.isChosen,_that.isCorrect);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String text,  int voterCount,  double votePercentage,  bool isChosen,  bool isCorrect)  $default,) {final _that = this;
switch (_that) {
case _PollOption():
return $default(_that.text,_that.voterCount,_that.votePercentage,_that.isChosen,_that.isCorrect);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String text,  int voterCount,  double votePercentage,  bool isChosen,  bool isCorrect)?  $default,) {final _that = this;
switch (_that) {
case _PollOption() when $default != null:
return $default(_that.text,_that.voterCount,_that.votePercentage,_that.isChosen,_that.isCorrect);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PollOption implements PollOption {
  const _PollOption({required this.text, required this.voterCount, this.votePercentage = 0.0, this.isChosen = false, this.isCorrect = false});
  factory _PollOption.fromJson(Map<String, dynamic> json) => _$PollOptionFromJson(json);

@override final  String text;
@override final  int voterCount;
@override@JsonKey() final  double votePercentage;
@override@JsonKey() final  bool isChosen;
@override@JsonKey() final  bool isCorrect;

/// Create a copy of PollOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PollOptionCopyWith<_PollOption> get copyWith => __$PollOptionCopyWithImpl<_PollOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PollOptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PollOption&&(identical(other.text, text) || other.text == text)&&(identical(other.voterCount, voterCount) || other.voterCount == voterCount)&&(identical(other.votePercentage, votePercentage) || other.votePercentage == votePercentage)&&(identical(other.isChosen, isChosen) || other.isChosen == isChosen)&&(identical(other.isCorrect, isCorrect) || other.isCorrect == isCorrect));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,voterCount,votePercentage,isChosen,isCorrect);

@override
String toString() {
  return 'PollOption(text: $text, voterCount: $voterCount, votePercentage: $votePercentage, isChosen: $isChosen, isCorrect: $isCorrect)';
}


}

/// @nodoc
abstract mixin class _$PollOptionCopyWith<$Res> implements $PollOptionCopyWith<$Res> {
  factory _$PollOptionCopyWith(_PollOption value, $Res Function(_PollOption) _then) = __$PollOptionCopyWithImpl;
@override @useResult
$Res call({
 String text, int voterCount, double votePercentage, bool isChosen, bool isCorrect
});




}
/// @nodoc
class __$PollOptionCopyWithImpl<$Res>
    implements _$PollOptionCopyWith<$Res> {
  __$PollOptionCopyWithImpl(this._self, this._then);

  final _PollOption _self;
  final $Res Function(_PollOption) _then;

/// Create a copy of PollOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? voterCount = null,Object? votePercentage = null,Object? isChosen = null,Object? isCorrect = null,}) {
  return _then(_PollOption(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,voterCount: null == voterCount ? _self.voterCount : voterCount // ignore: cast_nullable_to_non_nullable
as int,votePercentage: null == votePercentage ? _self.votePercentage : votePercentage // ignore: cast_nullable_to_non_nullable
as double,isChosen: null == isChosen ? _self.isChosen : isChosen // ignore: cast_nullable_to_non_nullable
as bool,isCorrect: null == isCorrect ? _self.isCorrect : isCorrect // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$Poll {

 String get id; String get question; List<PollOption> get options; int get totalVoterCount; bool get isAnonymous; bool get isClosed; bool get isQuiz;/// Whether a voter may pick more than one option. Regular polls only —
/// a quiz has exactly one right answer, so Telegram never sets both.
 bool get allowsMultipleAnswers; int? get correctOptionId; List<int> get chosenOptionIds;
/// Create a copy of Poll
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PollCopyWith<Poll> get copyWith => _$PollCopyWithImpl<Poll>(this as Poll, _$identity);

  /// Serializes this Poll to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Poll&&(identical(other.id, id) || other.id == id)&&(identical(other.question, question) || other.question == question)&&const DeepCollectionEquality().equals(other.options, options)&&(identical(other.totalVoterCount, totalVoterCount) || other.totalVoterCount == totalVoterCount)&&(identical(other.isAnonymous, isAnonymous) || other.isAnonymous == isAnonymous)&&(identical(other.isClosed, isClosed) || other.isClosed == isClosed)&&(identical(other.isQuiz, isQuiz) || other.isQuiz == isQuiz)&&(identical(other.allowsMultipleAnswers, allowsMultipleAnswers) || other.allowsMultipleAnswers == allowsMultipleAnswers)&&(identical(other.correctOptionId, correctOptionId) || other.correctOptionId == correctOptionId)&&const DeepCollectionEquality().equals(other.chosenOptionIds, chosenOptionIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,question,const DeepCollectionEquality().hash(options),totalVoterCount,isAnonymous,isClosed,isQuiz,allowsMultipleAnswers,correctOptionId,const DeepCollectionEquality().hash(chosenOptionIds));

@override
String toString() {
  return 'Poll(id: $id, question: $question, options: $options, totalVoterCount: $totalVoterCount, isAnonymous: $isAnonymous, isClosed: $isClosed, isQuiz: $isQuiz, allowsMultipleAnswers: $allowsMultipleAnswers, correctOptionId: $correctOptionId, chosenOptionIds: $chosenOptionIds)';
}


}

/// @nodoc
abstract mixin class $PollCopyWith<$Res>  {
  factory $PollCopyWith(Poll value, $Res Function(Poll) _then) = _$PollCopyWithImpl;
@useResult
$Res call({
 String id, String question, List<PollOption> options, int totalVoterCount, bool isAnonymous, bool isClosed, bool isQuiz, bool allowsMultipleAnswers, int? correctOptionId, List<int> chosenOptionIds
});




}
/// @nodoc
class _$PollCopyWithImpl<$Res>
    implements $PollCopyWith<$Res> {
  _$PollCopyWithImpl(this._self, this._then);

  final Poll _self;
  final $Res Function(Poll) _then;

/// Create a copy of Poll
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? question = null,Object? options = null,Object? totalVoterCount = null,Object? isAnonymous = null,Object? isClosed = null,Object? isQuiz = null,Object? allowsMultipleAnswers = null,Object? correctOptionId = freezed,Object? chosenOptionIds = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<PollOption>,totalVoterCount: null == totalVoterCount ? _self.totalVoterCount : totalVoterCount // ignore: cast_nullable_to_non_nullable
as int,isAnonymous: null == isAnonymous ? _self.isAnonymous : isAnonymous // ignore: cast_nullable_to_non_nullable
as bool,isClosed: null == isClosed ? _self.isClosed : isClosed // ignore: cast_nullable_to_non_nullable
as bool,isQuiz: null == isQuiz ? _self.isQuiz : isQuiz // ignore: cast_nullable_to_non_nullable
as bool,allowsMultipleAnswers: null == allowsMultipleAnswers ? _self.allowsMultipleAnswers : allowsMultipleAnswers // ignore: cast_nullable_to_non_nullable
as bool,correctOptionId: freezed == correctOptionId ? _self.correctOptionId : correctOptionId // ignore: cast_nullable_to_non_nullable
as int?,chosenOptionIds: null == chosenOptionIds ? _self.chosenOptionIds : chosenOptionIds // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}

}


/// Adds pattern-matching-related methods to [Poll].
extension PollPatterns on Poll {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Poll value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Poll() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Poll value)  $default,){
final _that = this;
switch (_that) {
case _Poll():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Poll value)?  $default,){
final _that = this;
switch (_that) {
case _Poll() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String question,  List<PollOption> options,  int totalVoterCount,  bool isAnonymous,  bool isClosed,  bool isQuiz,  bool allowsMultipleAnswers,  int? correctOptionId,  List<int> chosenOptionIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Poll() when $default != null:
return $default(_that.id,_that.question,_that.options,_that.totalVoterCount,_that.isAnonymous,_that.isClosed,_that.isQuiz,_that.allowsMultipleAnswers,_that.correctOptionId,_that.chosenOptionIds);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String question,  List<PollOption> options,  int totalVoterCount,  bool isAnonymous,  bool isClosed,  bool isQuiz,  bool allowsMultipleAnswers,  int? correctOptionId,  List<int> chosenOptionIds)  $default,) {final _that = this;
switch (_that) {
case _Poll():
return $default(_that.id,_that.question,_that.options,_that.totalVoterCount,_that.isAnonymous,_that.isClosed,_that.isQuiz,_that.allowsMultipleAnswers,_that.correctOptionId,_that.chosenOptionIds);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String question,  List<PollOption> options,  int totalVoterCount,  bool isAnonymous,  bool isClosed,  bool isQuiz,  bool allowsMultipleAnswers,  int? correctOptionId,  List<int> chosenOptionIds)?  $default,) {final _that = this;
switch (_that) {
case _Poll() when $default != null:
return $default(_that.id,_that.question,_that.options,_that.totalVoterCount,_that.isAnonymous,_that.isClosed,_that.isQuiz,_that.allowsMultipleAnswers,_that.correctOptionId,_that.chosenOptionIds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Poll implements Poll {
  const _Poll({required this.id, required this.question, required final  List<PollOption> options, required this.totalVoterCount, required this.isAnonymous, required this.isClosed, required this.isQuiz, this.allowsMultipleAnswers = false, this.correctOptionId, final  List<int> chosenOptionIds = const []}): _options = options,_chosenOptionIds = chosenOptionIds;
  factory _Poll.fromJson(Map<String, dynamic> json) => _$PollFromJson(json);

@override final  String id;
@override final  String question;
 final  List<PollOption> _options;
@override List<PollOption> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}

@override final  int totalVoterCount;
@override final  bool isAnonymous;
@override final  bool isClosed;
@override final  bool isQuiz;
/// Whether a voter may pick more than one option. Regular polls only —
/// a quiz has exactly one right answer, so Telegram never sets both.
@override@JsonKey() final  bool allowsMultipleAnswers;
@override final  int? correctOptionId;
 final  List<int> _chosenOptionIds;
@override@JsonKey() List<int> get chosenOptionIds {
  if (_chosenOptionIds is EqualUnmodifiableListView) return _chosenOptionIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_chosenOptionIds);
}


/// Create a copy of Poll
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PollCopyWith<_Poll> get copyWith => __$PollCopyWithImpl<_Poll>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PollToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Poll&&(identical(other.id, id) || other.id == id)&&(identical(other.question, question) || other.question == question)&&const DeepCollectionEquality().equals(other._options, _options)&&(identical(other.totalVoterCount, totalVoterCount) || other.totalVoterCount == totalVoterCount)&&(identical(other.isAnonymous, isAnonymous) || other.isAnonymous == isAnonymous)&&(identical(other.isClosed, isClosed) || other.isClosed == isClosed)&&(identical(other.isQuiz, isQuiz) || other.isQuiz == isQuiz)&&(identical(other.allowsMultipleAnswers, allowsMultipleAnswers) || other.allowsMultipleAnswers == allowsMultipleAnswers)&&(identical(other.correctOptionId, correctOptionId) || other.correctOptionId == correctOptionId)&&const DeepCollectionEquality().equals(other._chosenOptionIds, _chosenOptionIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,question,const DeepCollectionEquality().hash(_options),totalVoterCount,isAnonymous,isClosed,isQuiz,allowsMultipleAnswers,correctOptionId,const DeepCollectionEquality().hash(_chosenOptionIds));

@override
String toString() {
  return 'Poll(id: $id, question: $question, options: $options, totalVoterCount: $totalVoterCount, isAnonymous: $isAnonymous, isClosed: $isClosed, isQuiz: $isQuiz, allowsMultipleAnswers: $allowsMultipleAnswers, correctOptionId: $correctOptionId, chosenOptionIds: $chosenOptionIds)';
}


}

/// @nodoc
abstract mixin class _$PollCopyWith<$Res> implements $PollCopyWith<$Res> {
  factory _$PollCopyWith(_Poll value, $Res Function(_Poll) _then) = __$PollCopyWithImpl;
@override @useResult
$Res call({
 String id, String question, List<PollOption> options, int totalVoterCount, bool isAnonymous, bool isClosed, bool isQuiz, bool allowsMultipleAnswers, int? correctOptionId, List<int> chosenOptionIds
});




}
/// @nodoc
class __$PollCopyWithImpl<$Res>
    implements _$PollCopyWith<$Res> {
  __$PollCopyWithImpl(this._self, this._then);

  final _Poll _self;
  final $Res Function(_Poll) _then;

/// Create a copy of Poll
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? question = null,Object? options = null,Object? totalVoterCount = null,Object? isAnonymous = null,Object? isClosed = null,Object? isQuiz = null,Object? allowsMultipleAnswers = null,Object? correctOptionId = freezed,Object? chosenOptionIds = null,}) {
  return _then(_Poll(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<PollOption>,totalVoterCount: null == totalVoterCount ? _self.totalVoterCount : totalVoterCount // ignore: cast_nullable_to_non_nullable
as int,isAnonymous: null == isAnonymous ? _self.isAnonymous : isAnonymous // ignore: cast_nullable_to_non_nullable
as bool,isClosed: null == isClosed ? _self.isClosed : isClosed // ignore: cast_nullable_to_non_nullable
as bool,isQuiz: null == isQuiz ? _self.isQuiz : isQuiz // ignore: cast_nullable_to_non_nullable
as bool,allowsMultipleAnswers: null == allowsMultipleAnswers ? _self.allowsMultipleAnswers : allowsMultipleAnswers // ignore: cast_nullable_to_non_nullable
as bool,correctOptionId: freezed == correctOptionId ? _self.correctOptionId : correctOptionId // ignore: cast_nullable_to_non_nullable
as int?,chosenOptionIds: null == chosenOptionIds ? _self._chosenOptionIds : chosenOptionIds // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}


}

// dart format on
