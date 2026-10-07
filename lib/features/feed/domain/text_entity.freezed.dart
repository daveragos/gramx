// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'text_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TextEntity {

 int get offset; int get length; TextEntityType get type; String? get url;// for textUrl
 String? get customEmojiId;// for customEmoji
 String? get language;// for a fenced code block
 int? get userId;
/// Create a copy of TextEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TextEntityCopyWith<TextEntity> get copyWith => _$TextEntityCopyWithImpl<TextEntity>(this as TextEntity, _$identity);

  /// Serializes this TextEntity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TextEntity&&(identical(other.offset, offset) || other.offset == offset)&&(identical(other.length, length) || other.length == length)&&(identical(other.type, type) || other.type == type)&&(identical(other.url, url) || other.url == url)&&(identical(other.customEmojiId, customEmojiId) || other.customEmojiId == customEmojiId)&&(identical(other.language, language) || other.language == language)&&(identical(other.userId, userId) || other.userId == userId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,offset,length,type,url,customEmojiId,language,userId);

@override
String toString() {
  return 'TextEntity(offset: $offset, length: $length, type: $type, url: $url, customEmojiId: $customEmojiId, language: $language, userId: $userId)';
}


}

/// @nodoc
abstract mixin class $TextEntityCopyWith<$Res>  {
  factory $TextEntityCopyWith(TextEntity value, $Res Function(TextEntity) _then) = _$TextEntityCopyWithImpl;
@useResult
$Res call({
 int offset, int length, TextEntityType type, String? url, String? customEmojiId, String? language, int? userId
});




}
/// @nodoc
class _$TextEntityCopyWithImpl<$Res>
    implements $TextEntityCopyWith<$Res> {
  _$TextEntityCopyWithImpl(this._self, this._then);

  final TextEntity _self;
  final $Res Function(TextEntity) _then;

/// Create a copy of TextEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? offset = null,Object? length = null,Object? type = null,Object? url = freezed,Object? customEmojiId = freezed,Object? language = freezed,Object? userId = freezed,}) {
  return _then(_self.copyWith(
offset: null == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int,length: null == length ? _self.length : length // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as TextEntityType,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,customEmojiId: freezed == customEmojiId ? _self.customEmojiId : customEmojiId // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [TextEntity].
extension TextEntityPatterns on TextEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TextEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TextEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TextEntity value)  $default,){
final _that = this;
switch (_that) {
case _TextEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TextEntity value)?  $default,){
final _that = this;
switch (_that) {
case _TextEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int offset,  int length,  TextEntityType type,  String? url,  String? customEmojiId,  String? language,  int? userId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TextEntity() when $default != null:
return $default(_that.offset,_that.length,_that.type,_that.url,_that.customEmojiId,_that.language,_that.userId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int offset,  int length,  TextEntityType type,  String? url,  String? customEmojiId,  String? language,  int? userId)  $default,) {final _that = this;
switch (_that) {
case _TextEntity():
return $default(_that.offset,_that.length,_that.type,_that.url,_that.customEmojiId,_that.language,_that.userId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int offset,  int length,  TextEntityType type,  String? url,  String? customEmojiId,  String? language,  int? userId)?  $default,) {final _that = this;
switch (_that) {
case _TextEntity() when $default != null:
return $default(_that.offset,_that.length,_that.type,_that.url,_that.customEmojiId,_that.language,_that.userId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TextEntity implements TextEntity {
  const _TextEntity({required this.offset, required this.length, required this.type, this.url, this.customEmojiId, this.language, this.userId});
  factory _TextEntity.fromJson(Map<String, dynamic> json) => _$TextEntityFromJson(json);

@override final  int offset;
@override final  int length;
@override final  TextEntityType type;
@override final  String? url;
// for textUrl
@override final  String? customEmojiId;
// for customEmoji
@override final  String? language;
// for a fenced code block
@override final  int? userId;

/// Create a copy of TextEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TextEntityCopyWith<_TextEntity> get copyWith => __$TextEntityCopyWithImpl<_TextEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TextEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TextEntity&&(identical(other.offset, offset) || other.offset == offset)&&(identical(other.length, length) || other.length == length)&&(identical(other.type, type) || other.type == type)&&(identical(other.url, url) || other.url == url)&&(identical(other.customEmojiId, customEmojiId) || other.customEmojiId == customEmojiId)&&(identical(other.language, language) || other.language == language)&&(identical(other.userId, userId) || other.userId == userId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,offset,length,type,url,customEmojiId,language,userId);

@override
String toString() {
  return 'TextEntity(offset: $offset, length: $length, type: $type, url: $url, customEmojiId: $customEmojiId, language: $language, userId: $userId)';
}


}

/// @nodoc
abstract mixin class _$TextEntityCopyWith<$Res> implements $TextEntityCopyWith<$Res> {
  factory _$TextEntityCopyWith(_TextEntity value, $Res Function(_TextEntity) _then) = __$TextEntityCopyWithImpl;
@override @useResult
$Res call({
 int offset, int length, TextEntityType type, String? url, String? customEmojiId, String? language, int? userId
});




}
/// @nodoc
class __$TextEntityCopyWithImpl<$Res>
    implements _$TextEntityCopyWith<$Res> {
  __$TextEntityCopyWithImpl(this._self, this._then);

  final _TextEntity _self;
  final $Res Function(_TextEntity) _then;

/// Create a copy of TextEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? offset = null,Object? length = null,Object? type = null,Object? url = freezed,Object? customEmojiId = freezed,Object? language = freezed,Object? userId = freezed,}) {
  return _then(_TextEntity(
offset: null == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int,length: null == length ? _self.length : length // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as TextEntityType,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,customEmojiId: freezed == customEmojiId ? _self.customEmojiId : customEmojiId // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
