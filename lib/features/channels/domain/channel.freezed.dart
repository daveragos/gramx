// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'channel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Channel {

 String get id; int get chatId; String get title; String? get username; String? get description; String? get avatarUrl; int? get avatarFileId; String? get avatarColor; int get subscriberCount; bool get isVerified; bool get isFavorite; bool get isMuted; bool get isHidden; bool get isJoined;/// Whether Telegram offers statistics (`canGetStatistics`), which it does
/// only for admins of large enough channels. Decides whether Analytics is
/// shown. False when full info wasn't fetched, and always for a guest.
 bool get canViewStatistics; DateTime? get lastPostAt;
/// Create a copy of Channel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChannelCopyWith<Channel> get copyWith => _$ChannelCopyWithImpl<Channel>(this as Channel, _$identity);

  /// Serializes this Channel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Channel&&(identical(other.id, id) || other.id == id)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.title, title) || other.title == title)&&(identical(other.username, username) || other.username == username)&&(identical(other.description, description) || other.description == description)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.avatarFileId, avatarFileId) || other.avatarFileId == avatarFileId)&&(identical(other.avatarColor, avatarColor) || other.avatarColor == avatarColor)&&(identical(other.subscriberCount, subscriberCount) || other.subscriberCount == subscriberCount)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.isMuted, isMuted) || other.isMuted == isMuted)&&(identical(other.isHidden, isHidden) || other.isHidden == isHidden)&&(identical(other.isJoined, isJoined) || other.isJoined == isJoined)&&(identical(other.canViewStatistics, canViewStatistics) || other.canViewStatistics == canViewStatistics)&&(identical(other.lastPostAt, lastPostAt) || other.lastPostAt == lastPostAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,chatId,title,username,description,avatarUrl,avatarFileId,avatarColor,subscriberCount,isVerified,isFavorite,isMuted,isHidden,isJoined,canViewStatistics,lastPostAt);

@override
String toString() {
  return 'Channel(id: $id, chatId: $chatId, title: $title, username: $username, description: $description, avatarUrl: $avatarUrl, avatarFileId: $avatarFileId, avatarColor: $avatarColor, subscriberCount: $subscriberCount, isVerified: $isVerified, isFavorite: $isFavorite, isMuted: $isMuted, isHidden: $isHidden, isJoined: $isJoined, canViewStatistics: $canViewStatistics, lastPostAt: $lastPostAt)';
}


}

/// @nodoc
abstract mixin class $ChannelCopyWith<$Res>  {
  factory $ChannelCopyWith(Channel value, $Res Function(Channel) _then) = _$ChannelCopyWithImpl;
@useResult
$Res call({
 String id, int chatId, String title, String? username, String? description, String? avatarUrl, int? avatarFileId, String? avatarColor, int subscriberCount, bool isVerified, bool isFavorite, bool isMuted, bool isHidden, bool isJoined, bool canViewStatistics, DateTime? lastPostAt
});




}
/// @nodoc
class _$ChannelCopyWithImpl<$Res>
    implements $ChannelCopyWith<$Res> {
  _$ChannelCopyWithImpl(this._self, this._then);

  final Channel _self;
  final $Res Function(Channel) _then;

/// Create a copy of Channel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? chatId = null,Object? title = null,Object? username = freezed,Object? description = freezed,Object? avatarUrl = freezed,Object? avatarFileId = freezed,Object? avatarColor = freezed,Object? subscriberCount = null,Object? isVerified = null,Object? isFavorite = null,Object? isMuted = null,Object? isHidden = null,Object? isJoined = null,Object? canViewStatistics = null,Object? lastPostAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,avatarFileId: freezed == avatarFileId ? _self.avatarFileId : avatarFileId // ignore: cast_nullable_to_non_nullable
as int?,avatarColor: freezed == avatarColor ? _self.avatarColor : avatarColor // ignore: cast_nullable_to_non_nullable
as String?,subscriberCount: null == subscriberCount ? _self.subscriberCount : subscriberCount // ignore: cast_nullable_to_non_nullable
as int,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,isHidden: null == isHidden ? _self.isHidden : isHidden // ignore: cast_nullable_to_non_nullable
as bool,isJoined: null == isJoined ? _self.isJoined : isJoined // ignore: cast_nullable_to_non_nullable
as bool,canViewStatistics: null == canViewStatistics ? _self.canViewStatistics : canViewStatistics // ignore: cast_nullable_to_non_nullable
as bool,lastPostAt: freezed == lastPostAt ? _self.lastPostAt : lastPostAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Channel].
extension ChannelPatterns on Channel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Channel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Channel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Channel value)  $default,){
final _that = this;
switch (_that) {
case _Channel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Channel value)?  $default,){
final _that = this;
switch (_that) {
case _Channel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int chatId,  String title,  String? username,  String? description,  String? avatarUrl,  int? avatarFileId,  String? avatarColor,  int subscriberCount,  bool isVerified,  bool isFavorite,  bool isMuted,  bool isHidden,  bool isJoined,  bool canViewStatistics,  DateTime? lastPostAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Channel() when $default != null:
return $default(_that.id,_that.chatId,_that.title,_that.username,_that.description,_that.avatarUrl,_that.avatarFileId,_that.avatarColor,_that.subscriberCount,_that.isVerified,_that.isFavorite,_that.isMuted,_that.isHidden,_that.isJoined,_that.canViewStatistics,_that.lastPostAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int chatId,  String title,  String? username,  String? description,  String? avatarUrl,  int? avatarFileId,  String? avatarColor,  int subscriberCount,  bool isVerified,  bool isFavorite,  bool isMuted,  bool isHidden,  bool isJoined,  bool canViewStatistics,  DateTime? lastPostAt)  $default,) {final _that = this;
switch (_that) {
case _Channel():
return $default(_that.id,_that.chatId,_that.title,_that.username,_that.description,_that.avatarUrl,_that.avatarFileId,_that.avatarColor,_that.subscriberCount,_that.isVerified,_that.isFavorite,_that.isMuted,_that.isHidden,_that.isJoined,_that.canViewStatistics,_that.lastPostAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int chatId,  String title,  String? username,  String? description,  String? avatarUrl,  int? avatarFileId,  String? avatarColor,  int subscriberCount,  bool isVerified,  bool isFavorite,  bool isMuted,  bool isHidden,  bool isJoined,  bool canViewStatistics,  DateTime? lastPostAt)?  $default,) {final _that = this;
switch (_that) {
case _Channel() when $default != null:
return $default(_that.id,_that.chatId,_that.title,_that.username,_that.description,_that.avatarUrl,_that.avatarFileId,_that.avatarColor,_that.subscriberCount,_that.isVerified,_that.isFavorite,_that.isMuted,_that.isHidden,_that.isJoined,_that.canViewStatistics,_that.lastPostAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Channel implements Channel {
  const _Channel({required this.id, required this.chatId, required this.title, this.username, this.description, this.avatarUrl, this.avatarFileId, this.avatarColor, this.subscriberCount = 0, this.isVerified = false, this.isFavorite = false, this.isMuted = false, this.isHidden = false, this.isJoined = true, this.canViewStatistics = false, this.lastPostAt});
  factory _Channel.fromJson(Map<String, dynamic> json) => _$ChannelFromJson(json);

@override final  String id;
@override final  int chatId;
@override final  String title;
@override final  String? username;
@override final  String? description;
@override final  String? avatarUrl;
@override final  int? avatarFileId;
@override final  String? avatarColor;
@override@JsonKey() final  int subscriberCount;
@override@JsonKey() final  bool isVerified;
@override@JsonKey() final  bool isFavorite;
@override@JsonKey() final  bool isMuted;
@override@JsonKey() final  bool isHidden;
@override@JsonKey() final  bool isJoined;
/// Whether Telegram offers statistics (`canGetStatistics`), which it does
/// only for admins of large enough channels. Decides whether Analytics is
/// shown. False when full info wasn't fetched, and always for a guest.
@override@JsonKey() final  bool canViewStatistics;
@override final  DateTime? lastPostAt;

/// Create a copy of Channel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChannelCopyWith<_Channel> get copyWith => __$ChannelCopyWithImpl<_Channel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChannelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Channel&&(identical(other.id, id) || other.id == id)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.title, title) || other.title == title)&&(identical(other.username, username) || other.username == username)&&(identical(other.description, description) || other.description == description)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.avatarFileId, avatarFileId) || other.avatarFileId == avatarFileId)&&(identical(other.avatarColor, avatarColor) || other.avatarColor == avatarColor)&&(identical(other.subscriberCount, subscriberCount) || other.subscriberCount == subscriberCount)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.isMuted, isMuted) || other.isMuted == isMuted)&&(identical(other.isHidden, isHidden) || other.isHidden == isHidden)&&(identical(other.isJoined, isJoined) || other.isJoined == isJoined)&&(identical(other.canViewStatistics, canViewStatistics) || other.canViewStatistics == canViewStatistics)&&(identical(other.lastPostAt, lastPostAt) || other.lastPostAt == lastPostAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,chatId,title,username,description,avatarUrl,avatarFileId,avatarColor,subscriberCount,isVerified,isFavorite,isMuted,isHidden,isJoined,canViewStatistics,lastPostAt);

@override
String toString() {
  return 'Channel(id: $id, chatId: $chatId, title: $title, username: $username, description: $description, avatarUrl: $avatarUrl, avatarFileId: $avatarFileId, avatarColor: $avatarColor, subscriberCount: $subscriberCount, isVerified: $isVerified, isFavorite: $isFavorite, isMuted: $isMuted, isHidden: $isHidden, isJoined: $isJoined, canViewStatistics: $canViewStatistics, lastPostAt: $lastPostAt)';
}


}

/// @nodoc
abstract mixin class _$ChannelCopyWith<$Res> implements $ChannelCopyWith<$Res> {
  factory _$ChannelCopyWith(_Channel value, $Res Function(_Channel) _then) = __$ChannelCopyWithImpl;
@override @useResult
$Res call({
 String id, int chatId, String title, String? username, String? description, String? avatarUrl, int? avatarFileId, String? avatarColor, int subscriberCount, bool isVerified, bool isFavorite, bool isMuted, bool isHidden, bool isJoined, bool canViewStatistics, DateTime? lastPostAt
});




}
/// @nodoc
class __$ChannelCopyWithImpl<$Res>
    implements _$ChannelCopyWith<$Res> {
  __$ChannelCopyWithImpl(this._self, this._then);

  final _Channel _self;
  final $Res Function(_Channel) _then;

/// Create a copy of Channel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? chatId = null,Object? title = null,Object? username = freezed,Object? description = freezed,Object? avatarUrl = freezed,Object? avatarFileId = freezed,Object? avatarColor = freezed,Object? subscriberCount = null,Object? isVerified = null,Object? isFavorite = null,Object? isMuted = null,Object? isHidden = null,Object? isJoined = null,Object? canViewStatistics = null,Object? lastPostAt = freezed,}) {
  return _then(_Channel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,avatarFileId: freezed == avatarFileId ? _self.avatarFileId : avatarFileId // ignore: cast_nullable_to_non_nullable
as int?,avatarColor: freezed == avatarColor ? _self.avatarColor : avatarColor // ignore: cast_nullable_to_non_nullable
as String?,subscriberCount: null == subscriberCount ? _self.subscriberCount : subscriberCount // ignore: cast_nullable_to_non_nullable
as int,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,isHidden: null == isHidden ? _self.isHidden : isHidden // ignore: cast_nullable_to_non_nullable
as bool,isJoined: null == isJoined ? _self.isJoined : isJoined // ignore: cast_nullable_to_non_nullable
as bool,canViewStatistics: null == canViewStatistics ? _self.canViewStatistics : canViewStatistics // ignore: cast_nullable_to_non_nullable
as bool,lastPostAt: freezed == lastPostAt ? _self.lastPostAt : lastPostAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
