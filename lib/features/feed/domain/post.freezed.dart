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

 String get id; int get chatId; String get channelId; int get messageId; int get mediaAlbumId; String get channelTitle; String? get channelUsername; String? get channelAvatarUrl; int? get channelAvatarFileId; String? get channelAvatarColor; bool get isChannelVerified; String? get text; List<MediaItem> get media; DateTime get publishedAt; int get viewCount; int get replyCount; int get forwardCount; Map<String, int> get reactions; Set<String> get chosenReactions; bool get isBookmarked; bool get isRead; String? get linkPreviewUrl; String? get linkPreviewTitle; String? get linkPreviewDescription; String? get linkPreviewImageUrl; int? get linkPreviewFileId; String? get forwardedFromTitle; String? get forwardedFromUsername; String? get forwardedFromChatId;/// The original post's id in its own channel, when Telegram tells us.
/// Lets a forward link to the post itself rather than just the channel.
 int? get forwardedFromMessageId; String? get replyToText; String? get replyToAuthorTitle; int? get replyToMessageId; String? get replyToThumbnailUrl; int? get replyToThumbnailFileId; bool get hasDiscussionGroup; String? get authorSignature;/// Set when Telegram sent content this app cannot draw — the TDLib type
/// name, so the card can offer to open it in Telegram instead of showing a
/// dead sentence.
 String? get unsupportedKind; List<TextEntity> get entities;@JsonKey(fromJson: _pollFromJson, toJson: _pollToJson) Poll? get poll;
/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PostCopyWith<Post> get copyWith => _$PostCopyWithImpl<Post>(this as Post, _$identity);

  /// Serializes this Post to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Post&&(identical(other.id, id) || other.id == id)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.mediaAlbumId, mediaAlbumId) || other.mediaAlbumId == mediaAlbumId)&&(identical(other.channelTitle, channelTitle) || other.channelTitle == channelTitle)&&(identical(other.channelUsername, channelUsername) || other.channelUsername == channelUsername)&&(identical(other.channelAvatarUrl, channelAvatarUrl) || other.channelAvatarUrl == channelAvatarUrl)&&(identical(other.channelAvatarFileId, channelAvatarFileId) || other.channelAvatarFileId == channelAvatarFileId)&&(identical(other.channelAvatarColor, channelAvatarColor) || other.channelAvatarColor == channelAvatarColor)&&(identical(other.isChannelVerified, isChannelVerified) || other.isChannelVerified == isChannelVerified)&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other.media, media)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt)&&(identical(other.viewCount, viewCount) || other.viewCount == viewCount)&&(identical(other.replyCount, replyCount) || other.replyCount == replyCount)&&(identical(other.forwardCount, forwardCount) || other.forwardCount == forwardCount)&&const DeepCollectionEquality().equals(other.reactions, reactions)&&const DeepCollectionEquality().equals(other.chosenReactions, chosenReactions)&&(identical(other.isBookmarked, isBookmarked) || other.isBookmarked == isBookmarked)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&(identical(other.linkPreviewUrl, linkPreviewUrl) || other.linkPreviewUrl == linkPreviewUrl)&&(identical(other.linkPreviewTitle, linkPreviewTitle) || other.linkPreviewTitle == linkPreviewTitle)&&(identical(other.linkPreviewDescription, linkPreviewDescription) || other.linkPreviewDescription == linkPreviewDescription)&&(identical(other.linkPreviewImageUrl, linkPreviewImageUrl) || other.linkPreviewImageUrl == linkPreviewImageUrl)&&(identical(other.linkPreviewFileId, linkPreviewFileId) || other.linkPreviewFileId == linkPreviewFileId)&&(identical(other.forwardedFromTitle, forwardedFromTitle) || other.forwardedFromTitle == forwardedFromTitle)&&(identical(other.forwardedFromUsername, forwardedFromUsername) || other.forwardedFromUsername == forwardedFromUsername)&&(identical(other.forwardedFromChatId, forwardedFromChatId) || other.forwardedFromChatId == forwardedFromChatId)&&(identical(other.forwardedFromMessageId, forwardedFromMessageId) || other.forwardedFromMessageId == forwardedFromMessageId)&&(identical(other.replyToText, replyToText) || other.replyToText == replyToText)&&(identical(other.replyToAuthorTitle, replyToAuthorTitle) || other.replyToAuthorTitle == replyToAuthorTitle)&&(identical(other.replyToMessageId, replyToMessageId) || other.replyToMessageId == replyToMessageId)&&(identical(other.replyToThumbnailUrl, replyToThumbnailUrl) || other.replyToThumbnailUrl == replyToThumbnailUrl)&&(identical(other.replyToThumbnailFileId, replyToThumbnailFileId) || other.replyToThumbnailFileId == replyToThumbnailFileId)&&(identical(other.hasDiscussionGroup, hasDiscussionGroup) || other.hasDiscussionGroup == hasDiscussionGroup)&&(identical(other.authorSignature, authorSignature) || other.authorSignature == authorSignature)&&(identical(other.unsupportedKind, unsupportedKind) || other.unsupportedKind == unsupportedKind)&&const DeepCollectionEquality().equals(other.entities, entities)&&(identical(other.poll, poll) || other.poll == poll));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,chatId,channelId,messageId,mediaAlbumId,channelTitle,channelUsername,channelAvatarUrl,channelAvatarFileId,channelAvatarColor,isChannelVerified,text,const DeepCollectionEquality().hash(media),publishedAt,viewCount,replyCount,forwardCount,const DeepCollectionEquality().hash(reactions),const DeepCollectionEquality().hash(chosenReactions),isBookmarked,isRead,linkPreviewUrl,linkPreviewTitle,linkPreviewDescription,linkPreviewImageUrl,linkPreviewFileId,forwardedFromTitle,forwardedFromUsername,forwardedFromChatId,forwardedFromMessageId,replyToText,replyToAuthorTitle,replyToMessageId,replyToThumbnailUrl,replyToThumbnailFileId,hasDiscussionGroup,authorSignature,unsupportedKind,const DeepCollectionEquality().hash(entities),poll]);

@override
String toString() {
  return 'Post(id: $id, chatId: $chatId, channelId: $channelId, messageId: $messageId, mediaAlbumId: $mediaAlbumId, channelTitle: $channelTitle, channelUsername: $channelUsername, channelAvatarUrl: $channelAvatarUrl, channelAvatarFileId: $channelAvatarFileId, channelAvatarColor: $channelAvatarColor, isChannelVerified: $isChannelVerified, text: $text, media: $media, publishedAt: $publishedAt, viewCount: $viewCount, replyCount: $replyCount, forwardCount: $forwardCount, reactions: $reactions, chosenReactions: $chosenReactions, isBookmarked: $isBookmarked, isRead: $isRead, linkPreviewUrl: $linkPreviewUrl, linkPreviewTitle: $linkPreviewTitle, linkPreviewDescription: $linkPreviewDescription, linkPreviewImageUrl: $linkPreviewImageUrl, linkPreviewFileId: $linkPreviewFileId, forwardedFromTitle: $forwardedFromTitle, forwardedFromUsername: $forwardedFromUsername, forwardedFromChatId: $forwardedFromChatId, forwardedFromMessageId: $forwardedFromMessageId, replyToText: $replyToText, replyToAuthorTitle: $replyToAuthorTitle, replyToMessageId: $replyToMessageId, replyToThumbnailUrl: $replyToThumbnailUrl, replyToThumbnailFileId: $replyToThumbnailFileId, hasDiscussionGroup: $hasDiscussionGroup, authorSignature: $authorSignature, unsupportedKind: $unsupportedKind, entities: $entities, poll: $poll)';
}


}

/// @nodoc
abstract mixin class $PostCopyWith<$Res>  {
  factory $PostCopyWith(Post value, $Res Function(Post) _then) = _$PostCopyWithImpl;
@useResult
$Res call({
 String id, int chatId, String channelId, int messageId, int mediaAlbumId, String channelTitle, String? channelUsername, String? channelAvatarUrl, int? channelAvatarFileId, String? channelAvatarColor, bool isChannelVerified, String? text, List<MediaItem> media, DateTime publishedAt, int viewCount, int replyCount, int forwardCount, Map<String, int> reactions, Set<String> chosenReactions, bool isBookmarked, bool isRead, String? linkPreviewUrl, String? linkPreviewTitle, String? linkPreviewDescription, String? linkPreviewImageUrl, int? linkPreviewFileId, String? forwardedFromTitle, String? forwardedFromUsername, String? forwardedFromChatId, int? forwardedFromMessageId, String? replyToText, String? replyToAuthorTitle, int? replyToMessageId, String? replyToThumbnailUrl, int? replyToThumbnailFileId, bool hasDiscussionGroup, String? authorSignature, String? unsupportedKind, List<TextEntity> entities,@JsonKey(fromJson: _pollFromJson, toJson: _pollToJson) Poll? poll
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? chatId = null,Object? channelId = null,Object? messageId = null,Object? mediaAlbumId = null,Object? channelTitle = null,Object? channelUsername = freezed,Object? channelAvatarUrl = freezed,Object? channelAvatarFileId = freezed,Object? channelAvatarColor = freezed,Object? isChannelVerified = null,Object? text = freezed,Object? media = null,Object? publishedAt = null,Object? viewCount = null,Object? replyCount = null,Object? forwardCount = null,Object? reactions = null,Object? chosenReactions = null,Object? isBookmarked = null,Object? isRead = null,Object? linkPreviewUrl = freezed,Object? linkPreviewTitle = freezed,Object? linkPreviewDescription = freezed,Object? linkPreviewImageUrl = freezed,Object? linkPreviewFileId = freezed,Object? forwardedFromTitle = freezed,Object? forwardedFromUsername = freezed,Object? forwardedFromChatId = freezed,Object? forwardedFromMessageId = freezed,Object? replyToText = freezed,Object? replyToAuthorTitle = freezed,Object? replyToMessageId = freezed,Object? replyToThumbnailUrl = freezed,Object? replyToThumbnailFileId = freezed,Object? hasDiscussionGroup = null,Object? authorSignature = freezed,Object? unsupportedKind = freezed,Object? entities = null,Object? poll = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as int,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as int,mediaAlbumId: null == mediaAlbumId ? _self.mediaAlbumId : mediaAlbumId // ignore: cast_nullable_to_non_nullable
as int,channelTitle: null == channelTitle ? _self.channelTitle : channelTitle // ignore: cast_nullable_to_non_nullable
as String,channelUsername: freezed == channelUsername ? _self.channelUsername : channelUsername // ignore: cast_nullable_to_non_nullable
as String?,channelAvatarUrl: freezed == channelAvatarUrl ? _self.channelAvatarUrl : channelAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,channelAvatarFileId: freezed == channelAvatarFileId ? _self.channelAvatarFileId : channelAvatarFileId // ignore: cast_nullable_to_non_nullable
as int?,channelAvatarColor: freezed == channelAvatarColor ? _self.channelAvatarColor : channelAvatarColor // ignore: cast_nullable_to_non_nullable
as String?,isChannelVerified: null == isChannelVerified ? _self.isChannelVerified : isChannelVerified // ignore: cast_nullable_to_non_nullable
as bool,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as List<MediaItem>,publishedAt: null == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime,viewCount: null == viewCount ? _self.viewCount : viewCount // ignore: cast_nullable_to_non_nullable
as int,replyCount: null == replyCount ? _self.replyCount : replyCount // ignore: cast_nullable_to_non_nullable
as int,forwardCount: null == forwardCount ? _self.forwardCount : forwardCount // ignore: cast_nullable_to_non_nullable
as int,reactions: null == reactions ? _self.reactions : reactions // ignore: cast_nullable_to_non_nullable
as Map<String, int>,chosenReactions: null == chosenReactions ? _self.chosenReactions : chosenReactions // ignore: cast_nullable_to_non_nullable
as Set<String>,isBookmarked: null == isBookmarked ? _self.isBookmarked : isBookmarked // ignore: cast_nullable_to_non_nullable
as bool,isRead: null == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool,linkPreviewUrl: freezed == linkPreviewUrl ? _self.linkPreviewUrl : linkPreviewUrl // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewTitle: freezed == linkPreviewTitle ? _self.linkPreviewTitle : linkPreviewTitle // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewDescription: freezed == linkPreviewDescription ? _self.linkPreviewDescription : linkPreviewDescription // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewImageUrl: freezed == linkPreviewImageUrl ? _self.linkPreviewImageUrl : linkPreviewImageUrl // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewFileId: freezed == linkPreviewFileId ? _self.linkPreviewFileId : linkPreviewFileId // ignore: cast_nullable_to_non_nullable
as int?,forwardedFromTitle: freezed == forwardedFromTitle ? _self.forwardedFromTitle : forwardedFromTitle // ignore: cast_nullable_to_non_nullable
as String?,forwardedFromUsername: freezed == forwardedFromUsername ? _self.forwardedFromUsername : forwardedFromUsername // ignore: cast_nullable_to_non_nullable
as String?,forwardedFromChatId: freezed == forwardedFromChatId ? _self.forwardedFromChatId : forwardedFromChatId // ignore: cast_nullable_to_non_nullable
as String?,forwardedFromMessageId: freezed == forwardedFromMessageId ? _self.forwardedFromMessageId : forwardedFromMessageId // ignore: cast_nullable_to_non_nullable
as int?,replyToText: freezed == replyToText ? _self.replyToText : replyToText // ignore: cast_nullable_to_non_nullable
as String?,replyToAuthorTitle: freezed == replyToAuthorTitle ? _self.replyToAuthorTitle : replyToAuthorTitle // ignore: cast_nullable_to_non_nullable
as String?,replyToMessageId: freezed == replyToMessageId ? _self.replyToMessageId : replyToMessageId // ignore: cast_nullable_to_non_nullable
as int?,replyToThumbnailUrl: freezed == replyToThumbnailUrl ? _self.replyToThumbnailUrl : replyToThumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,replyToThumbnailFileId: freezed == replyToThumbnailFileId ? _self.replyToThumbnailFileId : replyToThumbnailFileId // ignore: cast_nullable_to_non_nullable
as int?,hasDiscussionGroup: null == hasDiscussionGroup ? _self.hasDiscussionGroup : hasDiscussionGroup // ignore: cast_nullable_to_non_nullable
as bool,authorSignature: freezed == authorSignature ? _self.authorSignature : authorSignature // ignore: cast_nullable_to_non_nullable
as String?,unsupportedKind: freezed == unsupportedKind ? _self.unsupportedKind : unsupportedKind // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int chatId,  String channelId,  int messageId,  int mediaAlbumId,  String channelTitle,  String? channelUsername,  String? channelAvatarUrl,  int? channelAvatarFileId,  String? channelAvatarColor,  bool isChannelVerified,  String? text,  List<MediaItem> media,  DateTime publishedAt,  int viewCount,  int replyCount,  int forwardCount,  Map<String, int> reactions,  Set<String> chosenReactions,  bool isBookmarked,  bool isRead,  String? linkPreviewUrl,  String? linkPreviewTitle,  String? linkPreviewDescription,  String? linkPreviewImageUrl,  int? linkPreviewFileId,  String? forwardedFromTitle,  String? forwardedFromUsername,  String? forwardedFromChatId,  int? forwardedFromMessageId,  String? replyToText,  String? replyToAuthorTitle,  int? replyToMessageId,  String? replyToThumbnailUrl,  int? replyToThumbnailFileId,  bool hasDiscussionGroup,  String? authorSignature,  String? unsupportedKind,  List<TextEntity> entities, @JsonKey(fromJson: _pollFromJson, toJson: _pollToJson)  Poll? poll)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Post() when $default != null:
return $default(_that.id,_that.chatId,_that.channelId,_that.messageId,_that.mediaAlbumId,_that.channelTitle,_that.channelUsername,_that.channelAvatarUrl,_that.channelAvatarFileId,_that.channelAvatarColor,_that.isChannelVerified,_that.text,_that.media,_that.publishedAt,_that.viewCount,_that.replyCount,_that.forwardCount,_that.reactions,_that.chosenReactions,_that.isBookmarked,_that.isRead,_that.linkPreviewUrl,_that.linkPreviewTitle,_that.linkPreviewDescription,_that.linkPreviewImageUrl,_that.linkPreviewFileId,_that.forwardedFromTitle,_that.forwardedFromUsername,_that.forwardedFromChatId,_that.forwardedFromMessageId,_that.replyToText,_that.replyToAuthorTitle,_that.replyToMessageId,_that.replyToThumbnailUrl,_that.replyToThumbnailFileId,_that.hasDiscussionGroup,_that.authorSignature,_that.unsupportedKind,_that.entities,_that.poll);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int chatId,  String channelId,  int messageId,  int mediaAlbumId,  String channelTitle,  String? channelUsername,  String? channelAvatarUrl,  int? channelAvatarFileId,  String? channelAvatarColor,  bool isChannelVerified,  String? text,  List<MediaItem> media,  DateTime publishedAt,  int viewCount,  int replyCount,  int forwardCount,  Map<String, int> reactions,  Set<String> chosenReactions,  bool isBookmarked,  bool isRead,  String? linkPreviewUrl,  String? linkPreviewTitle,  String? linkPreviewDescription,  String? linkPreviewImageUrl,  int? linkPreviewFileId,  String? forwardedFromTitle,  String? forwardedFromUsername,  String? forwardedFromChatId,  int? forwardedFromMessageId,  String? replyToText,  String? replyToAuthorTitle,  int? replyToMessageId,  String? replyToThumbnailUrl,  int? replyToThumbnailFileId,  bool hasDiscussionGroup,  String? authorSignature,  String? unsupportedKind,  List<TextEntity> entities, @JsonKey(fromJson: _pollFromJson, toJson: _pollToJson)  Poll? poll)  $default,) {final _that = this;
switch (_that) {
case _Post():
return $default(_that.id,_that.chatId,_that.channelId,_that.messageId,_that.mediaAlbumId,_that.channelTitle,_that.channelUsername,_that.channelAvatarUrl,_that.channelAvatarFileId,_that.channelAvatarColor,_that.isChannelVerified,_that.text,_that.media,_that.publishedAt,_that.viewCount,_that.replyCount,_that.forwardCount,_that.reactions,_that.chosenReactions,_that.isBookmarked,_that.isRead,_that.linkPreviewUrl,_that.linkPreviewTitle,_that.linkPreviewDescription,_that.linkPreviewImageUrl,_that.linkPreviewFileId,_that.forwardedFromTitle,_that.forwardedFromUsername,_that.forwardedFromChatId,_that.forwardedFromMessageId,_that.replyToText,_that.replyToAuthorTitle,_that.replyToMessageId,_that.replyToThumbnailUrl,_that.replyToThumbnailFileId,_that.hasDiscussionGroup,_that.authorSignature,_that.unsupportedKind,_that.entities,_that.poll);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int chatId,  String channelId,  int messageId,  int mediaAlbumId,  String channelTitle,  String? channelUsername,  String? channelAvatarUrl,  int? channelAvatarFileId,  String? channelAvatarColor,  bool isChannelVerified,  String? text,  List<MediaItem> media,  DateTime publishedAt,  int viewCount,  int replyCount,  int forwardCount,  Map<String, int> reactions,  Set<String> chosenReactions,  bool isBookmarked,  bool isRead,  String? linkPreviewUrl,  String? linkPreviewTitle,  String? linkPreviewDescription,  String? linkPreviewImageUrl,  int? linkPreviewFileId,  String? forwardedFromTitle,  String? forwardedFromUsername,  String? forwardedFromChatId,  int? forwardedFromMessageId,  String? replyToText,  String? replyToAuthorTitle,  int? replyToMessageId,  String? replyToThumbnailUrl,  int? replyToThumbnailFileId,  bool hasDiscussionGroup,  String? authorSignature,  String? unsupportedKind,  List<TextEntity> entities, @JsonKey(fromJson: _pollFromJson, toJson: _pollToJson)  Poll? poll)?  $default,) {final _that = this;
switch (_that) {
case _Post() when $default != null:
return $default(_that.id,_that.chatId,_that.channelId,_that.messageId,_that.mediaAlbumId,_that.channelTitle,_that.channelUsername,_that.channelAvatarUrl,_that.channelAvatarFileId,_that.channelAvatarColor,_that.isChannelVerified,_that.text,_that.media,_that.publishedAt,_that.viewCount,_that.replyCount,_that.forwardCount,_that.reactions,_that.chosenReactions,_that.isBookmarked,_that.isRead,_that.linkPreviewUrl,_that.linkPreviewTitle,_that.linkPreviewDescription,_that.linkPreviewImageUrl,_that.linkPreviewFileId,_that.forwardedFromTitle,_that.forwardedFromUsername,_that.forwardedFromChatId,_that.forwardedFromMessageId,_that.replyToText,_that.replyToAuthorTitle,_that.replyToMessageId,_that.replyToThumbnailUrl,_that.replyToThumbnailFileId,_that.hasDiscussionGroup,_that.authorSignature,_that.unsupportedKind,_that.entities,_that.poll);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Post implements Post {
  const _Post({required this.id, required this.chatId, required this.channelId, required this.messageId, this.mediaAlbumId = 0, required this.channelTitle, this.channelUsername, this.channelAvatarUrl, this.channelAvatarFileId, this.channelAvatarColor, this.isChannelVerified = false, this.text, final  List<MediaItem> media = const [], required this.publishedAt, this.viewCount = 0, this.replyCount = 0, this.forwardCount = 0, final  Map<String, int> reactions = const {}, final  Set<String> chosenReactions = const {}, this.isBookmarked = false, this.isRead = false, this.linkPreviewUrl, this.linkPreviewTitle, this.linkPreviewDescription, this.linkPreviewImageUrl, this.linkPreviewFileId, this.forwardedFromTitle, this.forwardedFromUsername, this.forwardedFromChatId, this.forwardedFromMessageId, this.replyToText, this.replyToAuthorTitle, this.replyToMessageId, this.replyToThumbnailUrl, this.replyToThumbnailFileId, this.hasDiscussionGroup = false, this.authorSignature, this.unsupportedKind, final  List<TextEntity> entities = const [], @JsonKey(fromJson: _pollFromJson, toJson: _pollToJson) this.poll}): _media = media,_reactions = reactions,_chosenReactions = chosenReactions,_entities = entities;
  factory _Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);

@override final  String id;
@override final  int chatId;
@override final  String channelId;
@override final  int messageId;
@override@JsonKey() final  int mediaAlbumId;
@override final  String channelTitle;
@override final  String? channelUsername;
@override final  String? channelAvatarUrl;
@override final  int? channelAvatarFileId;
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

 final  Set<String> _chosenReactions;
@override@JsonKey() Set<String> get chosenReactions {
  if (_chosenReactions is EqualUnmodifiableSetView) return _chosenReactions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_chosenReactions);
}

@override@JsonKey() final  bool isBookmarked;
@override@JsonKey() final  bool isRead;
@override final  String? linkPreviewUrl;
@override final  String? linkPreviewTitle;
@override final  String? linkPreviewDescription;
@override final  String? linkPreviewImageUrl;
@override final  int? linkPreviewFileId;
@override final  String? forwardedFromTitle;
@override final  String? forwardedFromUsername;
@override final  String? forwardedFromChatId;
/// The original post's id in its own channel, when Telegram tells us.
/// Lets a forward link to the post itself rather than just the channel.
@override final  int? forwardedFromMessageId;
@override final  String? replyToText;
@override final  String? replyToAuthorTitle;
@override final  int? replyToMessageId;
@override final  String? replyToThumbnailUrl;
@override final  int? replyToThumbnailFileId;
@override@JsonKey() final  bool hasDiscussionGroup;
@override final  String? authorSignature;
/// Set when Telegram sent content this app cannot draw — the TDLib type
/// name, so the card can offer to open it in Telegram instead of showing a
/// dead sentence.
@override final  String? unsupportedKind;
 final  List<TextEntity> _entities;
@override@JsonKey() List<TextEntity> get entities {
  if (_entities is EqualUnmodifiableListView) return _entities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entities);
}

@override@JsonKey(fromJson: _pollFromJson, toJson: _pollToJson) final  Poll? poll;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Post&&(identical(other.id, id) || other.id == id)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.mediaAlbumId, mediaAlbumId) || other.mediaAlbumId == mediaAlbumId)&&(identical(other.channelTitle, channelTitle) || other.channelTitle == channelTitle)&&(identical(other.channelUsername, channelUsername) || other.channelUsername == channelUsername)&&(identical(other.channelAvatarUrl, channelAvatarUrl) || other.channelAvatarUrl == channelAvatarUrl)&&(identical(other.channelAvatarFileId, channelAvatarFileId) || other.channelAvatarFileId == channelAvatarFileId)&&(identical(other.channelAvatarColor, channelAvatarColor) || other.channelAvatarColor == channelAvatarColor)&&(identical(other.isChannelVerified, isChannelVerified) || other.isChannelVerified == isChannelVerified)&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other._media, _media)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt)&&(identical(other.viewCount, viewCount) || other.viewCount == viewCount)&&(identical(other.replyCount, replyCount) || other.replyCount == replyCount)&&(identical(other.forwardCount, forwardCount) || other.forwardCount == forwardCount)&&const DeepCollectionEquality().equals(other._reactions, _reactions)&&const DeepCollectionEquality().equals(other._chosenReactions, _chosenReactions)&&(identical(other.isBookmarked, isBookmarked) || other.isBookmarked == isBookmarked)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&(identical(other.linkPreviewUrl, linkPreviewUrl) || other.linkPreviewUrl == linkPreviewUrl)&&(identical(other.linkPreviewTitle, linkPreviewTitle) || other.linkPreviewTitle == linkPreviewTitle)&&(identical(other.linkPreviewDescription, linkPreviewDescription) || other.linkPreviewDescription == linkPreviewDescription)&&(identical(other.linkPreviewImageUrl, linkPreviewImageUrl) || other.linkPreviewImageUrl == linkPreviewImageUrl)&&(identical(other.linkPreviewFileId, linkPreviewFileId) || other.linkPreviewFileId == linkPreviewFileId)&&(identical(other.forwardedFromTitle, forwardedFromTitle) || other.forwardedFromTitle == forwardedFromTitle)&&(identical(other.forwardedFromUsername, forwardedFromUsername) || other.forwardedFromUsername == forwardedFromUsername)&&(identical(other.forwardedFromChatId, forwardedFromChatId) || other.forwardedFromChatId == forwardedFromChatId)&&(identical(other.forwardedFromMessageId, forwardedFromMessageId) || other.forwardedFromMessageId == forwardedFromMessageId)&&(identical(other.replyToText, replyToText) || other.replyToText == replyToText)&&(identical(other.replyToAuthorTitle, replyToAuthorTitle) || other.replyToAuthorTitle == replyToAuthorTitle)&&(identical(other.replyToMessageId, replyToMessageId) || other.replyToMessageId == replyToMessageId)&&(identical(other.replyToThumbnailUrl, replyToThumbnailUrl) || other.replyToThumbnailUrl == replyToThumbnailUrl)&&(identical(other.replyToThumbnailFileId, replyToThumbnailFileId) || other.replyToThumbnailFileId == replyToThumbnailFileId)&&(identical(other.hasDiscussionGroup, hasDiscussionGroup) || other.hasDiscussionGroup == hasDiscussionGroup)&&(identical(other.authorSignature, authorSignature) || other.authorSignature == authorSignature)&&(identical(other.unsupportedKind, unsupportedKind) || other.unsupportedKind == unsupportedKind)&&const DeepCollectionEquality().equals(other._entities, _entities)&&(identical(other.poll, poll) || other.poll == poll));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,chatId,channelId,messageId,mediaAlbumId,channelTitle,channelUsername,channelAvatarUrl,channelAvatarFileId,channelAvatarColor,isChannelVerified,text,const DeepCollectionEquality().hash(_media),publishedAt,viewCount,replyCount,forwardCount,const DeepCollectionEquality().hash(_reactions),const DeepCollectionEquality().hash(_chosenReactions),isBookmarked,isRead,linkPreviewUrl,linkPreviewTitle,linkPreviewDescription,linkPreviewImageUrl,linkPreviewFileId,forwardedFromTitle,forwardedFromUsername,forwardedFromChatId,forwardedFromMessageId,replyToText,replyToAuthorTitle,replyToMessageId,replyToThumbnailUrl,replyToThumbnailFileId,hasDiscussionGroup,authorSignature,unsupportedKind,const DeepCollectionEquality().hash(_entities),poll]);

@override
String toString() {
  return 'Post(id: $id, chatId: $chatId, channelId: $channelId, messageId: $messageId, mediaAlbumId: $mediaAlbumId, channelTitle: $channelTitle, channelUsername: $channelUsername, channelAvatarUrl: $channelAvatarUrl, channelAvatarFileId: $channelAvatarFileId, channelAvatarColor: $channelAvatarColor, isChannelVerified: $isChannelVerified, text: $text, media: $media, publishedAt: $publishedAt, viewCount: $viewCount, replyCount: $replyCount, forwardCount: $forwardCount, reactions: $reactions, chosenReactions: $chosenReactions, isBookmarked: $isBookmarked, isRead: $isRead, linkPreviewUrl: $linkPreviewUrl, linkPreviewTitle: $linkPreviewTitle, linkPreviewDescription: $linkPreviewDescription, linkPreviewImageUrl: $linkPreviewImageUrl, linkPreviewFileId: $linkPreviewFileId, forwardedFromTitle: $forwardedFromTitle, forwardedFromUsername: $forwardedFromUsername, forwardedFromChatId: $forwardedFromChatId, forwardedFromMessageId: $forwardedFromMessageId, replyToText: $replyToText, replyToAuthorTitle: $replyToAuthorTitle, replyToMessageId: $replyToMessageId, replyToThumbnailUrl: $replyToThumbnailUrl, replyToThumbnailFileId: $replyToThumbnailFileId, hasDiscussionGroup: $hasDiscussionGroup, authorSignature: $authorSignature, unsupportedKind: $unsupportedKind, entities: $entities, poll: $poll)';
}


}

/// @nodoc
abstract mixin class _$PostCopyWith<$Res> implements $PostCopyWith<$Res> {
  factory _$PostCopyWith(_Post value, $Res Function(_Post) _then) = __$PostCopyWithImpl;
@override @useResult
$Res call({
 String id, int chatId, String channelId, int messageId, int mediaAlbumId, String channelTitle, String? channelUsername, String? channelAvatarUrl, int? channelAvatarFileId, String? channelAvatarColor, bool isChannelVerified, String? text, List<MediaItem> media, DateTime publishedAt, int viewCount, int replyCount, int forwardCount, Map<String, int> reactions, Set<String> chosenReactions, bool isBookmarked, bool isRead, String? linkPreviewUrl, String? linkPreviewTitle, String? linkPreviewDescription, String? linkPreviewImageUrl, int? linkPreviewFileId, String? forwardedFromTitle, String? forwardedFromUsername, String? forwardedFromChatId, int? forwardedFromMessageId, String? replyToText, String? replyToAuthorTitle, int? replyToMessageId, String? replyToThumbnailUrl, int? replyToThumbnailFileId, bool hasDiscussionGroup, String? authorSignature, String? unsupportedKind, List<TextEntity> entities,@JsonKey(fromJson: _pollFromJson, toJson: _pollToJson) Poll? poll
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? chatId = null,Object? channelId = null,Object? messageId = null,Object? mediaAlbumId = null,Object? channelTitle = null,Object? channelUsername = freezed,Object? channelAvatarUrl = freezed,Object? channelAvatarFileId = freezed,Object? channelAvatarColor = freezed,Object? isChannelVerified = null,Object? text = freezed,Object? media = null,Object? publishedAt = null,Object? viewCount = null,Object? replyCount = null,Object? forwardCount = null,Object? reactions = null,Object? chosenReactions = null,Object? isBookmarked = null,Object? isRead = null,Object? linkPreviewUrl = freezed,Object? linkPreviewTitle = freezed,Object? linkPreviewDescription = freezed,Object? linkPreviewImageUrl = freezed,Object? linkPreviewFileId = freezed,Object? forwardedFromTitle = freezed,Object? forwardedFromUsername = freezed,Object? forwardedFromChatId = freezed,Object? forwardedFromMessageId = freezed,Object? replyToText = freezed,Object? replyToAuthorTitle = freezed,Object? replyToMessageId = freezed,Object? replyToThumbnailUrl = freezed,Object? replyToThumbnailFileId = freezed,Object? hasDiscussionGroup = null,Object? authorSignature = freezed,Object? unsupportedKind = freezed,Object? entities = null,Object? poll = freezed,}) {
  return _then(_Post(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as int,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as int,mediaAlbumId: null == mediaAlbumId ? _self.mediaAlbumId : mediaAlbumId // ignore: cast_nullable_to_non_nullable
as int,channelTitle: null == channelTitle ? _self.channelTitle : channelTitle // ignore: cast_nullable_to_non_nullable
as String,channelUsername: freezed == channelUsername ? _self.channelUsername : channelUsername // ignore: cast_nullable_to_non_nullable
as String?,channelAvatarUrl: freezed == channelAvatarUrl ? _self.channelAvatarUrl : channelAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,channelAvatarFileId: freezed == channelAvatarFileId ? _self.channelAvatarFileId : channelAvatarFileId // ignore: cast_nullable_to_non_nullable
as int?,channelAvatarColor: freezed == channelAvatarColor ? _self.channelAvatarColor : channelAvatarColor // ignore: cast_nullable_to_non_nullable
as String?,isChannelVerified: null == isChannelVerified ? _self.isChannelVerified : isChannelVerified // ignore: cast_nullable_to_non_nullable
as bool,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,media: null == media ? _self._media : media // ignore: cast_nullable_to_non_nullable
as List<MediaItem>,publishedAt: null == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime,viewCount: null == viewCount ? _self.viewCount : viewCount // ignore: cast_nullable_to_non_nullable
as int,replyCount: null == replyCount ? _self.replyCount : replyCount // ignore: cast_nullable_to_non_nullable
as int,forwardCount: null == forwardCount ? _self.forwardCount : forwardCount // ignore: cast_nullable_to_non_nullable
as int,reactions: null == reactions ? _self._reactions : reactions // ignore: cast_nullable_to_non_nullable
as Map<String, int>,chosenReactions: null == chosenReactions ? _self._chosenReactions : chosenReactions // ignore: cast_nullable_to_non_nullable
as Set<String>,isBookmarked: null == isBookmarked ? _self.isBookmarked : isBookmarked // ignore: cast_nullable_to_non_nullable
as bool,isRead: null == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool,linkPreviewUrl: freezed == linkPreviewUrl ? _self.linkPreviewUrl : linkPreviewUrl // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewTitle: freezed == linkPreviewTitle ? _self.linkPreviewTitle : linkPreviewTitle // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewDescription: freezed == linkPreviewDescription ? _self.linkPreviewDescription : linkPreviewDescription // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewImageUrl: freezed == linkPreviewImageUrl ? _self.linkPreviewImageUrl : linkPreviewImageUrl // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewFileId: freezed == linkPreviewFileId ? _self.linkPreviewFileId : linkPreviewFileId // ignore: cast_nullable_to_non_nullable
as int?,forwardedFromTitle: freezed == forwardedFromTitle ? _self.forwardedFromTitle : forwardedFromTitle // ignore: cast_nullable_to_non_nullable
as String?,forwardedFromUsername: freezed == forwardedFromUsername ? _self.forwardedFromUsername : forwardedFromUsername // ignore: cast_nullable_to_non_nullable
as String?,forwardedFromChatId: freezed == forwardedFromChatId ? _self.forwardedFromChatId : forwardedFromChatId // ignore: cast_nullable_to_non_nullable
as String?,forwardedFromMessageId: freezed == forwardedFromMessageId ? _self.forwardedFromMessageId : forwardedFromMessageId // ignore: cast_nullable_to_non_nullable
as int?,replyToText: freezed == replyToText ? _self.replyToText : replyToText // ignore: cast_nullable_to_non_nullable
as String?,replyToAuthorTitle: freezed == replyToAuthorTitle ? _self.replyToAuthorTitle : replyToAuthorTitle // ignore: cast_nullable_to_non_nullable
as String?,replyToMessageId: freezed == replyToMessageId ? _self.replyToMessageId : replyToMessageId // ignore: cast_nullable_to_non_nullable
as int?,replyToThumbnailUrl: freezed == replyToThumbnailUrl ? _self.replyToThumbnailUrl : replyToThumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,replyToThumbnailFileId: freezed == replyToThumbnailFileId ? _self.replyToThumbnailFileId : replyToThumbnailFileId // ignore: cast_nullable_to_non_nullable
as int?,hasDiscussionGroup: null == hasDiscussionGroup ? _self.hasDiscussionGroup : hasDiscussionGroup // ignore: cast_nullable_to_non_nullable
as bool,authorSignature: freezed == authorSignature ? _self.authorSignature : authorSignature // ignore: cast_nullable_to_non_nullable
as String?,unsupportedKind: freezed == unsupportedKind ? _self.unsupportedKind : unsupportedKind // ignore: cast_nullable_to_non_nullable
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
