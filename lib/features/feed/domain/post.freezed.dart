// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'post.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Post {

 String get id; String get channelId; int get messageId; String get channelTitle; String? get channelUsername; String? get channelAvatarUrl; String? get channelAvatarColor; bool get isChannelVerified; String? get text; List<MediaItem> get media; DateTime get publishedAt; int get viewCount; int get replyCount; int get forwardCount; Map<String, int> get reactions; bool get isBookmarked; bool get isRead; String? get linkPreviewUrl; String? get linkPreviewTitle; String? get linkPreviewDescription; String? get linkPreviewImageUrl; String? get forwardedFromTitle; String? get forwardedFromUsername; List<TextEntity> get entities; Poll? get poll;
/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PostCopyWith<Post> get copyWith => _$PostCopyWithImpl<Post>(this as Post, _$identity);

  /// Serializes this Post to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Post&&(identical(other.id, id) || other.id == id)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.channelTitle, channelTitle) || other.channelTitle == channelTitle)&&(identical(other.channelUsername, channelUsername) || other.channelUsername == channelUsername)&&(identical(other.channelAvatarUrl, channelAvatarUrl) || other.channelAvatarUrl == channelAvatarUrl)&&(identical(other.channelAvatarColor, channelAvatarColor) || other.channelAvatarColor == channelAvatarColor)&&(identical(other.isChannelVerified, isChannelVerified) || other.isChannelVerified == isChannelVerified)&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other.media, media)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt)&&(identical(other.viewCount, viewCount) || other.viewCount == viewCount)&&(identical(other.replyCount, replyCount) || other.replyCount == replyCount)&&(identical(other.forwardCount, forwardCount) || other.forwardCount == forwardCount)&&const DeepCollectionEquality().equals(other.reactions, reactions)&&(identical(other.isBookmarked, isBookmarked) || other.isBookmarked == isBookmarked)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&(identical(other.linkPreviewUrl, linkPreviewUrl) || other.linkPreviewUrl == linkPreviewUrl)&&(identical(other.linkPreviewTitle, linkPreviewTitle) || other.linkPreviewTitle == linkPreviewTitle)&&(identical(other.linkPreviewDescription, linkPreviewDescription) || other.linkPreviewDescription == linkPreviewDescription)&&(identical(other.linkPreviewImageUrl, linkPreviewImageUrl) || other.linkPreviewImageUrl == linkPreviewImageUrl)&&(identical(other.forwardedFromTitle, forwardedFromTitle) || other.forwardedFromTitle == forwardedFromTitle)&&(identical(other.forwardedFromUsername, forwardedFromUsername) || other.forwardedFromUsername == forwardedFromUsername)&&const DeepCollectionEquality().equals(other.entities, entities)&&(identical(other.poll, poll) || other.poll == poll));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,channelId,messageId,channelTitle,channelUsername,channelAvatarUrl,channelAvatarColor,isChannelVerified,text,const DeepCollectionEquality().hash(media),publishedAt,viewCount,replyCount,forwardCount,const DeepCollectionEquality().hash(reactions),isBookmarked,isRead,linkPreviewUrl,linkPreviewTitle,linkPreviewDescription,linkPreviewImageUrl,forwardedFromTitle,forwardedFromUsername,const DeepCollectionEquality().hash(entities),poll]);

@override
String toString() {
  return 'Post(id: $id, channelId: $channelId, messageId: $messageId, channelTitle: $channelTitle, channelUsername: $channelUsername, channelAvatarUrl: $channelAvatarUrl, channelAvatarColor: $channelAvatarColor, isChannelVerified: $isChannelVerified, text: $text, media: $media, publishedAt: $publishedAt, viewCount: $viewCount, replyCount: $replyCount, forwardCount: $forwardCount, reactions: $reactions, isBookmarked: $isBookmarked, isRead: $isRead, linkPreviewUrl: $linkPreviewUrl, linkPreviewTitle: $linkPreviewTitle, linkPreviewDescription: $linkPreviewDescription, linkPreviewImageUrl: $linkPreviewImageUrl, forwardedFromTitle: $forwardedFromTitle, forwardedFromUsername: $forwardedFromUsername, entities: $entities, poll: $poll)';
}


}

/// @nodoc
abstract mixin class $PostCopyWith<$Res>  {
  factory $PostCopyWith(Post value, $Res Function(Post) _then) = _$PostCopyWithImpl;
@useResult
$Res call({
 String id, String channelId, int messageId, String channelTitle, String? channelUsername, String? channelAvatarUrl, String? channelAvatarColor, bool isChannelVerified, String? text, List<MediaItem> media, DateTime publishedAt, int viewCount, int replyCount, int forwardCount, Map<String, int> reactions, bool isBookmarked, bool isRead, String? linkPreviewUrl, String? linkPreviewTitle, String? linkPreviewDescription, String? linkPreviewImageUrl, String? forwardedFromTitle, String? forwardedFromUsername, List<TextEntity> entities, Poll? poll
});


$PollCopyWith<$Res>? get poll;

}
/// @nodoc
class _$PostCopyWithImpl<$Res>
    implements $PostCopyWith<$Res> {
  _$PostCopyWithImpl(this._self, this._then);

  final Post _self;
  final $Res Function(Post) _then;

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? channelId = null,Object? messageId = null,Object? channelTitle = null,Object? channelUsername = freezed,Object? channelAvatarUrl = freezed,Object? channelAvatarColor = freezed,Object? isChannelVerified = null,Object? text = freezed,Object? media = null,Object? publishedAt = null,Object? viewCount = null,Object? replyCount = null,Object? forwardCount = null,Object? reactions = null,Object? isBookmarked = null,Object? isRead = null,Object? linkPreviewUrl = freezed,Object? linkPreviewTitle = freezed,Object? linkPreviewDescription = freezed,Object? linkPreviewImageUrl = freezed,Object? forwardedFromTitle = freezed,Object? forwardedFromUsername = freezed,Object? entities = null,Object? poll = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as int,channelTitle: null == channelTitle ? _self.channelTitle : channelTitle // ignore: cast_nullable_to_non_nullable
as String,channelUsername: freezed == channelUsername ? _self.channelUsername : channelUsername // ignore: cast_nullable_to_non_nullable
as String?,channelAvatarUrl: freezed == channelAvatarUrl ? _self.channelAvatarUrl : channelAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,channelAvatarColor: freezed == channelAvatarColor ? _self.channelAvatarColor : channelAvatarColor // ignore: cast_nullable_to_non_nullable
as String?,isChannelVerified: null == isChannelVerified ? _self.isChannelVerified : isChannelVerified // ignore: cast_nullable_to_non_nullable
as bool,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as List<MediaItem>,publishedAt: null == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime,viewCount: null == viewCount ? _self.viewCount : viewCount // ignore: cast_nullable_to_non_nullable
as int,replyCount: null == replyCount ? _self.replyCount : replyCount // ignore: cast_nullable_to_non_nullable
as int,forwardCount: null == forwardCount ? _self.forwardCount : forwardCount // ignore: cast_nullable_to_non_nullable
as int,reactions: null == reactions ? _self.reactions : reactions // ignore: cast_nullable_to_non_nullable
as Map<String, int>,isBookmarked: null == isBookmarked ? _self.isBookmarked : isBookmarked // ignore: cast_nullable_to_non_nullable
as bool,isRead: null == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool,linkPreviewUrl: freezed == linkPreviewUrl ? _self.linkPreviewUrl : linkPreviewUrl // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewTitle: freezed == linkPreviewTitle ? _self.linkPreviewTitle : linkPreviewTitle // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewDescription: freezed == linkPreviewDescription ? _self.linkPreviewDescription : linkPreviewDescription // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewImageUrl: freezed == linkPreviewImageUrl ? _self.linkPreviewImageUrl : linkPreviewImageUrl // ignore: cast_nullable_to_non_nullable
as String?,forwardedFromTitle: freezed == forwardedFromTitle ? _self.forwardedFromTitle : forwardedFromTitle // ignore: cast_nullable_to_non_nullable
as String?,forwardedFromUsername: freezed == forwardedFromUsername ? _self.forwardedFromUsername : forwardedFromUsername // ignore: cast_nullable_to_non_nullable
as String?,entities: null == entities ? _self.entities : entities // ignore: cast_nullable_to_non_nullable
as List<TextEntity>,poll: freezed == poll ? _self.poll : poll // ignore: cast_nullable_to_non_nullable
as Poll?,
  ));
}
/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PollCopyWith<$Res>? get poll {
    if (_self.poll == null) {
    return null;
  }

  return $PollCopyWith<$Res>(_self.poll!, (value) {
    return _then(_self.copyWith(poll: value));
  });
}
}


/// Adds pattern-matching-related methods to [Post].
extension PostPatterns on Post {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Post value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Post() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Post value)  $default,){
final _that = this;
switch (_that) {
case _Post():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Post value)?  $default,){
final _that = this;
switch (_that) {
case _Post() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String channelId,  int messageId,  String channelTitle,  String? channelUsername,  String? channelAvatarUrl,  String? channelAvatarColor,  bool isChannelVerified,  String? text,  List<MediaItem> media,  DateTime publishedAt,  int viewCount,  int replyCount,  int forwardCount,  Map<String, int> reactions,  bool isBookmarked,  bool isRead,  String? linkPreviewUrl,  String? linkPreviewTitle,  String? linkPreviewDescription,  String? linkPreviewImageUrl,  String? forwardedFromTitle,  String? forwardedFromUsername,  List<TextEntity> entities,  Poll? poll)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Post() when $default != null:
return $default(_that.id,_that.channelId,_that.messageId,_that.channelTitle,_that.channelUsername,_that.channelAvatarUrl,_that.channelAvatarColor,_that.isChannelVerified,_that.text,_that.media,_that.publishedAt,_that.viewCount,_that.replyCount,_that.forwardCount,_that.reactions,_that.isBookmarked,_that.isRead,_that.linkPreviewUrl,_that.linkPreviewTitle,_that.linkPreviewDescription,_that.linkPreviewImageUrl,_that.forwardedFromTitle,_that.forwardedFromUsername,_that.entities,_that.poll);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String channelId,  int messageId,  String channelTitle,  String? channelUsername,  String? channelAvatarUrl,  String? channelAvatarColor,  bool isChannelVerified,  String? text,  List<MediaItem> media,  DateTime publishedAt,  int viewCount,  int replyCount,  int forwardCount,  Map<String, int> reactions,  bool isBookmarked,  bool isRead,  String? linkPreviewUrl,  String? linkPreviewTitle,  String? linkPreviewDescription,  String? linkPreviewImageUrl,  String? forwardedFromTitle,  String? forwardedFromUsername,  List<TextEntity> entities,  Poll? poll)  $default,) {final _that = this;
switch (_that) {
case _Post():
return $default(_that.id,_that.channelId,_that.messageId,_that.channelTitle,_that.channelUsername,_that.channelAvatarUrl,_that.channelAvatarColor,_that.isChannelVerified,_that.text,_that.media,_that.publishedAt,_that.viewCount,_that.replyCount,_that.forwardCount,_that.reactions,_that.isBookmarked,_that.isRead,_that.linkPreviewUrl,_that.linkPreviewTitle,_that.linkPreviewDescription,_that.linkPreviewImageUrl,_that.forwardedFromTitle,_that.forwardedFromUsername,_that.entities,_that.poll);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String channelId,  int messageId,  String channelTitle,  String? channelUsername,  String? channelAvatarUrl,  String? channelAvatarColor,  bool isChannelVerified,  String? text,  List<MediaItem> media,  DateTime publishedAt,  int viewCount,  int replyCount,  int forwardCount,  Map<String, int> reactions,  bool isBookmarked,  bool isRead,  String? linkPreviewUrl,  String? linkPreviewTitle,  String? linkPreviewDescription,  String? linkPreviewImageUrl,  String? forwardedFromTitle,  String? forwardedFromUsername,  List<TextEntity> entities,  Poll? poll)?  $default,) {final _that = this;
switch (_that) {
case _Post() when $default != null:
return $default(_that.id,_that.channelId,_that.messageId,_that.channelTitle,_that.channelUsername,_that.channelAvatarUrl,_that.channelAvatarColor,_that.isChannelVerified,_that.text,_that.media,_that.publishedAt,_that.viewCount,_that.replyCount,_that.forwardCount,_that.reactions,_that.isBookmarked,_that.isRead,_that.linkPreviewUrl,_that.linkPreviewTitle,_that.linkPreviewDescription,_that.linkPreviewImageUrl,_that.forwardedFromTitle,_that.forwardedFromUsername,_that.entities,_that.poll);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Post implements Post {
  const _Post({required this.id, required this.channelId, required this.messageId, required this.channelTitle, this.channelUsername, this.channelAvatarUrl, this.channelAvatarColor, this.isChannelVerified = false, this.text, final  List<MediaItem> media = const [], required this.publishedAt, this.viewCount = 0, this.replyCount = 0, this.forwardCount = 0, final  Map<String, int> reactions = const {}, this.isBookmarked = false, this.isRead = false, this.linkPreviewUrl, this.linkPreviewTitle, this.linkPreviewDescription, this.linkPreviewImageUrl, this.forwardedFromTitle, this.forwardedFromUsername, final  List<TextEntity> entities = const [], this.poll}): _media = media,_reactions = reactions,_entities = entities;
  factory _Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);

@override final  String id;
@override final  String channelId;
@override final  int messageId;
@override final  String channelTitle;
@override final  String? channelUsername;
@override final  String? channelAvatarUrl;
@override final  String? channelAvatarColor;
@override@JsonKey() final  bool isChannelVerified;
@override final  String? text;
 final  List<MediaItem> _media;
@override@JsonKey() List<MediaItem> get media {
  if (_media is EqualUnmodifiableListView) return _media;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_media);
}

@override final  DateTime publishedAt;
@override@JsonKey() final  int viewCount;
@override@JsonKey() final  int replyCount;
@override@JsonKey() final  int forwardCount;
 final  Map<String, int> _reactions;
@override@JsonKey() Map<String, int> get reactions {
  if (_reactions is EqualUnmodifiableMapView) return _reactions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_reactions);
}

@override@JsonKey() final  bool isBookmarked;
@override@JsonKey() final  bool isRead;
@override final  String? linkPreviewUrl;
@override final  String? linkPreviewTitle;
@override final  String? linkPreviewDescription;
@override final  String? linkPreviewImageUrl;
@override final  String? forwardedFromTitle;
@override final  String? forwardedFromUsername;
 final  List<TextEntity> _entities;
@override@JsonKey() List<TextEntity> get entities {
  if (_entities is EqualUnmodifiableListView) return _entities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entities);
}

@override final  Poll? poll;

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PostCopyWith<_Post> get copyWith => __$PostCopyWithImpl<_Post>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PostToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Post&&(identical(other.id, id) || other.id == id)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.channelTitle, channelTitle) || other.channelTitle == channelTitle)&&(identical(other.channelUsername, channelUsername) || other.channelUsername == channelUsername)&&(identical(other.channelAvatarUrl, channelAvatarUrl) || other.channelAvatarUrl == channelAvatarUrl)&&(identical(other.channelAvatarColor, channelAvatarColor) || other.channelAvatarColor == channelAvatarColor)&&(identical(other.isChannelVerified, isChannelVerified) || other.isChannelVerified == isChannelVerified)&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other._media, _media)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt)&&(identical(other.viewCount, viewCount) || other.viewCount == viewCount)&&(identical(other.replyCount, replyCount) || other.replyCount == replyCount)&&(identical(other.forwardCount, forwardCount) || other.forwardCount == forwardCount)&&const DeepCollectionEquality().equals(other._reactions, _reactions)&&(identical(other.isBookmarked, isBookmarked) || other.isBookmarked == isBookmarked)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&(identical(other.linkPreviewUrl, linkPreviewUrl) || other.linkPreviewUrl == linkPreviewUrl)&&(identical(other.linkPreviewTitle, linkPreviewTitle) || other.linkPreviewTitle == linkPreviewTitle)&&(identical(other.linkPreviewDescription, linkPreviewDescription) || other.linkPreviewDescription == linkPreviewDescription)&&(identical(other.linkPreviewImageUrl, linkPreviewImageUrl) || other.linkPreviewImageUrl == linkPreviewImageUrl)&&(identical(other.forwardedFromTitle, forwardedFromTitle) || other.forwardedFromTitle == forwardedFromTitle)&&(identical(other.forwardedFromUsername, forwardedFromUsername) || other.forwardedFromUsername == forwardedFromUsername)&&const DeepCollectionEquality().equals(other._entities, _entities)&&(identical(other.poll, poll) || other.poll == poll));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,channelId,messageId,channelTitle,channelUsername,channelAvatarUrl,channelAvatarColor,isChannelVerified,text,const DeepCollectionEquality().hash(_media),publishedAt,viewCount,replyCount,forwardCount,const DeepCollectionEquality().hash(_reactions),isBookmarked,isRead,linkPreviewUrl,linkPreviewTitle,linkPreviewDescription,linkPreviewImageUrl,forwardedFromTitle,forwardedFromUsername,const DeepCollectionEquality().hash(_entities),poll]);

@override
String toString() {
  return 'Post(id: $id, channelId: $channelId, messageId: $messageId, channelTitle: $channelTitle, channelUsername: $channelUsername, channelAvatarUrl: $channelAvatarUrl, channelAvatarColor: $channelAvatarColor, isChannelVerified: $isChannelVerified, text: $text, media: $media, publishedAt: $publishedAt, viewCount: $viewCount, replyCount: $replyCount, forwardCount: $forwardCount, reactions: $reactions, isBookmarked: $isBookmarked, isRead: $isRead, linkPreviewUrl: $linkPreviewUrl, linkPreviewTitle: $linkPreviewTitle, linkPreviewDescription: $linkPreviewDescription, linkPreviewImageUrl: $linkPreviewImageUrl, forwardedFromTitle: $forwardedFromTitle, forwardedFromUsername: $forwardedFromUsername, entities: $entities, poll: $poll)';
}


}

/// @nodoc
abstract mixin class _$PostCopyWith<$Res> implements $PostCopyWith<$Res> {
  factory _$PostCopyWith(_Post value, $Res Function(_Post) _then) = __$PostCopyWithImpl;
@override @useResult
$Res call({
 String id, String channelId, int messageId, String channelTitle, String? channelUsername, String? channelAvatarUrl, String? channelAvatarColor, bool isChannelVerified, String? text, List<MediaItem> media, DateTime publishedAt, int viewCount, int replyCount, int forwardCount, Map<String, int> reactions, bool isBookmarked, bool isRead, String? linkPreviewUrl, String? linkPreviewTitle, String? linkPreviewDescription, String? linkPreviewImageUrl, String? forwardedFromTitle, String? forwardedFromUsername, List<TextEntity> entities, Poll? poll
});


@override $PollCopyWith<$Res>? get poll;

}
/// @nodoc
class __$PostCopyWithImpl<$Res>
    implements _$PostCopyWith<$Res> {
  __$PostCopyWithImpl(this._self, this._then);

  final _Post _self;
  final $Res Function(_Post) _then;

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? channelId = null,Object? messageId = null,Object? channelTitle = null,Object? channelUsername = freezed,Object? channelAvatarUrl = freezed,Object? channelAvatarColor = freezed,Object? isChannelVerified = null,Object? text = freezed,Object? media = null,Object? publishedAt = null,Object? viewCount = null,Object? replyCount = null,Object? forwardCount = null,Object? reactions = null,Object? isBookmarked = null,Object? isRead = null,Object? linkPreviewUrl = freezed,Object? linkPreviewTitle = freezed,Object? linkPreviewDescription = freezed,Object? linkPreviewImageUrl = freezed,Object? forwardedFromTitle = freezed,Object? forwardedFromUsername = freezed,Object? entities = null,Object? poll = freezed,}) {
  return _then(_Post(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as int,channelTitle: null == channelTitle ? _self.channelTitle : channelTitle // ignore: cast_nullable_to_non_nullable
as String,channelUsername: freezed == channelUsername ? _self.channelUsername : channelUsername // ignore: cast_nullable_to_non_nullable
as String?,channelAvatarUrl: freezed == channelAvatarUrl ? _self.channelAvatarUrl : channelAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,channelAvatarColor: freezed == channelAvatarColor ? _self.channelAvatarColor : channelAvatarColor // ignore: cast_nullable_to_non_nullable
as String?,isChannelVerified: null == isChannelVerified ? _self.isChannelVerified : isChannelVerified // ignore: cast_nullable_to_non_nullable
as bool,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,media: null == media ? _self._media : media // ignore: cast_nullable_to_non_nullable
as List<MediaItem>,publishedAt: null == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime,viewCount: null == viewCount ? _self.viewCount : viewCount // ignore: cast_nullable_to_non_nullable
as int,replyCount: null == replyCount ? _self.replyCount : replyCount // ignore: cast_nullable_to_non_nullable
as int,forwardCount: null == forwardCount ? _self.forwardCount : forwardCount // ignore: cast_nullable_to_non_nullable
as int,reactions: null == reactions ? _self._reactions : reactions // ignore: cast_nullable_to_non_nullable
as Map<String, int>,isBookmarked: null == isBookmarked ? _self.isBookmarked : isBookmarked // ignore: cast_nullable_to_non_nullable
as bool,isRead: null == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool,linkPreviewUrl: freezed == linkPreviewUrl ? _self.linkPreviewUrl : linkPreviewUrl // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewTitle: freezed == linkPreviewTitle ? _self.linkPreviewTitle : linkPreviewTitle // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewDescription: freezed == linkPreviewDescription ? _self.linkPreviewDescription : linkPreviewDescription // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewImageUrl: freezed == linkPreviewImageUrl ? _self.linkPreviewImageUrl : linkPreviewImageUrl // ignore: cast_nullable_to_non_nullable
as String?,forwardedFromTitle: freezed == forwardedFromTitle ? _self.forwardedFromTitle : forwardedFromTitle // ignore: cast_nullable_to_non_nullable
as String?,forwardedFromUsername: freezed == forwardedFromUsername ? _self.forwardedFromUsername : forwardedFromUsername // ignore: cast_nullable_to_non_nullable
as String?,entities: null == entities ? _self._entities : entities // ignore: cast_nullable_to_non_nullable
as List<TextEntity>,poll: freezed == poll ? _self.poll : poll // ignore: cast_nullable_to_non_nullable
as Poll?,
  ));
}

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PollCopyWith<$Res>? get poll {
    if (_self.poll == null) {
    return null;
  }

  return $PollCopyWith<$Res>(_self.poll!, (value) {
    return _then(_self.copyWith(poll: value));
  });
}
}

// dart format on
