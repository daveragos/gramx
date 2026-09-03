// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatMessage {

/// `"<chatId>_<messageId>"`, the same key shape the rest of the app uses.
 String get id; int get chatId; int get messageId;/// Album members share this. Zero when the message stands alone.
 int get mediaAlbumId;/// True when this account sent it. Decides which side the bubble sits on,
/// and whether a send state is drawn at all.
 bool get isOutgoing;/// Who sent it. Null for a message from an anonymous admin or a channel
/// posting into its discussion group.
 int? get senderId;/// The sender's display name. Only drawn in groups — in a private chat the
/// two possible senders are the two people looking at it.
 String? get senderName; String? get senderAvatarPath; int? get senderAvatarFileId; String? get senderAvatarColorHex; String? get text; List<TextEntity> get entities; List<MediaItem> get media;/// The poll this message is, if it is one.
///
/// Carried rather than flattened to its question text. A poll bubble used
/// to render as an empty box: `MessagePoll` is content the feed draws in
/// full, so it had no fallback label to borrow, and nothing here knew what
/// to do with it — a message with no words, no media and no poll is a
/// bubble with nothing in it.
@JsonKey(fromJson: _pollFromJson, toJson: _pollToJson) Poll? get poll;/// A place somebody sent: a location, or a venue with a name on it.
///
/// Drawn as a card rather than reduced to the words "📍 Location", which
/// is what a conversation showed for one — a label with the coordinates
/// thrown away, so the one thing a location is for could not be done with
/// it.
@JsonKey(fromJson: _placeFromJson, toJson: _placeToJson) MessagePlace? get place;/// A contact card somebody sent.
@JsonKey(fromJson: _contactFromJson, toJson: _contactToJson) MessageContactCard? get contact;/// True while this message's media is Telegram's tap-to-view kind and has
/// not been opened. The bubble draws a cover rather than the picture, which
/// is the whole point of it.
 bool get isSecretMedia;/// True when the media is "view once": gone when the viewer closes it,
/// however long they looked. Mutually exclusive with
/// [selfDestructSeconds] — Telegram's type is one or the other.
 bool get isViewOnce;/// How long the viewer gets once they open it, in seconds. Zero for
/// [isViewOnce] media and for anything that does not self-destruct.
 int get selfDestructSeconds; DateTime get sentAt;/// When Telegram says the message was edited, if it was.
 DateTime? get editedAt; MessageSendState get sendState; Map<String, int> get reactions; Set<String> get chosenReactions;/// The message this one replies to, when there is one.
 int? get replyToMessageId; String? get replyToText; String? get replyToAuthorName;/// The chat the replied-to message lives in, when it isn't this one.
/// Telegram allows replies across chats, and assuming otherwise sends the
/// reader to a message id in the wrong chat.
 int? get replyToChatId; int? get replyToThumbnailFileId;/// Where a forwarded message came from, as Telegram will name it. Null
/// when the origin is hidden, which Telegram allows.
 String? get forwardedFromTitle; String? get linkPreviewUrl; String? get linkPreviewTitle; String? get linkPreviewDescription; int? get linkPreviewFileId;/// Whether this message is pinned to the top of the chat.
///
/// Read so the long-press menu can offer the right one of Pin and Unpin.
/// It arrives on `updateMessageIsPinned` rather than as a content change,
/// because nothing about the message itself moved.
 bool get isPinned;/// Telegram's own notice about the chat — "you joined", "photo changed".
/// Drawn as a centred line rather than a bubble, the way every Telegram
/// client does it, so it reads as narration and not as something somebody
/// said.
 bool get isService;/// Set when Telegram sent content this build cannot draw: the TDLib type
/// name, so the bubble can offer Telegram rather than showing an empty box.
 String? get unsupportedKind;
/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatMessageCopyWith<ChatMessage> get copyWith => _$ChatMessageCopyWithImpl<ChatMessage>(this as ChatMessage, _$identity);

  /// Serializes this ChatMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.mediaAlbumId, mediaAlbumId) || other.mediaAlbumId == mediaAlbumId)&&(identical(other.isOutgoing, isOutgoing) || other.isOutgoing == isOutgoing)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.senderName, senderName) || other.senderName == senderName)&&(identical(other.senderAvatarPath, senderAvatarPath) || other.senderAvatarPath == senderAvatarPath)&&(identical(other.senderAvatarFileId, senderAvatarFileId) || other.senderAvatarFileId == senderAvatarFileId)&&(identical(other.senderAvatarColorHex, senderAvatarColorHex) || other.senderAvatarColorHex == senderAvatarColorHex)&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other.entities, entities)&&const DeepCollectionEquality().equals(other.media, media)&&(identical(other.poll, poll) || other.poll == poll)&&(identical(other.place, place) || other.place == place)&&(identical(other.contact, contact) || other.contact == contact)&&(identical(other.isSecretMedia, isSecretMedia) || other.isSecretMedia == isSecretMedia)&&(identical(other.isViewOnce, isViewOnce) || other.isViewOnce == isViewOnce)&&(identical(other.selfDestructSeconds, selfDestructSeconds) || other.selfDestructSeconds == selfDestructSeconds)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.sendState, sendState) || other.sendState == sendState)&&const DeepCollectionEquality().equals(other.reactions, reactions)&&const DeepCollectionEquality().equals(other.chosenReactions, chosenReactions)&&(identical(other.replyToMessageId, replyToMessageId) || other.replyToMessageId == replyToMessageId)&&(identical(other.replyToText, replyToText) || other.replyToText == replyToText)&&(identical(other.replyToAuthorName, replyToAuthorName) || other.replyToAuthorName == replyToAuthorName)&&(identical(other.replyToChatId, replyToChatId) || other.replyToChatId == replyToChatId)&&(identical(other.replyToThumbnailFileId, replyToThumbnailFileId) || other.replyToThumbnailFileId == replyToThumbnailFileId)&&(identical(other.forwardedFromTitle, forwardedFromTitle) || other.forwardedFromTitle == forwardedFromTitle)&&(identical(other.linkPreviewUrl, linkPreviewUrl) || other.linkPreviewUrl == linkPreviewUrl)&&(identical(other.linkPreviewTitle, linkPreviewTitle) || other.linkPreviewTitle == linkPreviewTitle)&&(identical(other.linkPreviewDescription, linkPreviewDescription) || other.linkPreviewDescription == linkPreviewDescription)&&(identical(other.linkPreviewFileId, linkPreviewFileId) || other.linkPreviewFileId == linkPreviewFileId)&&(identical(other.isPinned, isPinned) || other.isPinned == isPinned)&&(identical(other.isService, isService) || other.isService == isService)&&(identical(other.unsupportedKind, unsupportedKind) || other.unsupportedKind == unsupportedKind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,chatId,messageId,mediaAlbumId,isOutgoing,senderId,senderName,senderAvatarPath,senderAvatarFileId,senderAvatarColorHex,text,const DeepCollectionEquality().hash(entities),const DeepCollectionEquality().hash(media),poll,place,contact,isSecretMedia,isViewOnce,selfDestructSeconds,sentAt,editedAt,sendState,const DeepCollectionEquality().hash(reactions),const DeepCollectionEquality().hash(chosenReactions),replyToMessageId,replyToText,replyToAuthorName,replyToChatId,replyToThumbnailFileId,forwardedFromTitle,linkPreviewUrl,linkPreviewTitle,linkPreviewDescription,linkPreviewFileId,isPinned,isService,unsupportedKind]);

@override
String toString() {
  return 'ChatMessage(id: $id, chatId: $chatId, messageId: $messageId, mediaAlbumId: $mediaAlbumId, isOutgoing: $isOutgoing, senderId: $senderId, senderName: $senderName, senderAvatarPath: $senderAvatarPath, senderAvatarFileId: $senderAvatarFileId, senderAvatarColorHex: $senderAvatarColorHex, text: $text, entities: $entities, media: $media, poll: $poll, place: $place, contact: $contact, isSecretMedia: $isSecretMedia, isViewOnce: $isViewOnce, selfDestructSeconds: $selfDestructSeconds, sentAt: $sentAt, editedAt: $editedAt, sendState: $sendState, reactions: $reactions, chosenReactions: $chosenReactions, replyToMessageId: $replyToMessageId, replyToText: $replyToText, replyToAuthorName: $replyToAuthorName, replyToChatId: $replyToChatId, replyToThumbnailFileId: $replyToThumbnailFileId, forwardedFromTitle: $forwardedFromTitle, linkPreviewUrl: $linkPreviewUrl, linkPreviewTitle: $linkPreviewTitle, linkPreviewDescription: $linkPreviewDescription, linkPreviewFileId: $linkPreviewFileId, isPinned: $isPinned, isService: $isService, unsupportedKind: $unsupportedKind)';
}


}

/// @nodoc
abstract mixin class $ChatMessageCopyWith<$Res>  {
  factory $ChatMessageCopyWith(ChatMessage value, $Res Function(ChatMessage) _then) = _$ChatMessageCopyWithImpl;
@useResult
$Res call({
 String id, int chatId, int messageId, int mediaAlbumId, bool isOutgoing, int? senderId, String? senderName, String? senderAvatarPath, int? senderAvatarFileId, String? senderAvatarColorHex, String? text, List<TextEntity> entities, List<MediaItem> media,@JsonKey(fromJson: _pollFromJson, toJson: _pollToJson) Poll? poll,@JsonKey(fromJson: _placeFromJson, toJson: _placeToJson) MessagePlace? place,@JsonKey(fromJson: _contactFromJson, toJson: _contactToJson) MessageContactCard? contact, bool isSecretMedia, bool isViewOnce, int selfDestructSeconds, DateTime sentAt, DateTime? editedAt, MessageSendState sendState, Map<String, int> reactions, Set<String> chosenReactions, int? replyToMessageId, String? replyToText, String? replyToAuthorName, int? replyToChatId, int? replyToThumbnailFileId, String? forwardedFromTitle, String? linkPreviewUrl, String? linkPreviewTitle, String? linkPreviewDescription, int? linkPreviewFileId, bool isPinned, bool isService, String? unsupportedKind
});


$PollCopyWith<$Res>? get poll;

}
/// @nodoc
class _$ChatMessageCopyWithImpl<$Res>
    implements $ChatMessageCopyWith<$Res> {
  _$ChatMessageCopyWithImpl(this._self, this._then);

  final ChatMessage _self;
  final $Res Function(ChatMessage) _then;

/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? chatId = null,Object? messageId = null,Object? mediaAlbumId = null,Object? isOutgoing = null,Object? senderId = freezed,Object? senderName = freezed,Object? senderAvatarPath = freezed,Object? senderAvatarFileId = freezed,Object? senderAvatarColorHex = freezed,Object? text = freezed,Object? entities = null,Object? media = null,Object? poll = freezed,Object? place = freezed,Object? contact = freezed,Object? isSecretMedia = null,Object? isViewOnce = null,Object? selfDestructSeconds = null,Object? sentAt = null,Object? editedAt = freezed,Object? sendState = null,Object? reactions = null,Object? chosenReactions = null,Object? replyToMessageId = freezed,Object? replyToText = freezed,Object? replyToAuthorName = freezed,Object? replyToChatId = freezed,Object? replyToThumbnailFileId = freezed,Object? forwardedFromTitle = freezed,Object? linkPreviewUrl = freezed,Object? linkPreviewTitle = freezed,Object? linkPreviewDescription = freezed,Object? linkPreviewFileId = freezed,Object? isPinned = null,Object? isService = null,Object? unsupportedKind = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as int,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as int,mediaAlbumId: null == mediaAlbumId ? _self.mediaAlbumId : mediaAlbumId // ignore: cast_nullable_to_non_nullable
as int,isOutgoing: null == isOutgoing ? _self.isOutgoing : isOutgoing // ignore: cast_nullable_to_non_nullable
as bool,senderId: freezed == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as int?,senderName: freezed == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String?,senderAvatarPath: freezed == senderAvatarPath ? _self.senderAvatarPath : senderAvatarPath // ignore: cast_nullable_to_non_nullable
as String?,senderAvatarFileId: freezed == senderAvatarFileId ? _self.senderAvatarFileId : senderAvatarFileId // ignore: cast_nullable_to_non_nullable
as int?,senderAvatarColorHex: freezed == senderAvatarColorHex ? _self.senderAvatarColorHex : senderAvatarColorHex // ignore: cast_nullable_to_non_nullable
as String?,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,entities: null == entities ? _self.entities : entities // ignore: cast_nullable_to_non_nullable
as List<TextEntity>,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as List<MediaItem>,poll: freezed == poll ? _self.poll : poll // ignore: cast_nullable_to_non_nullable
as Poll?,place: freezed == place ? _self.place : place // ignore: cast_nullable_to_non_nullable
as MessagePlace?,contact: freezed == contact ? _self.contact : contact // ignore: cast_nullable_to_non_nullable
as MessageContactCard?,isSecretMedia: null == isSecretMedia ? _self.isSecretMedia : isSecretMedia // ignore: cast_nullable_to_non_nullable
as bool,isViewOnce: null == isViewOnce ? _self.isViewOnce : isViewOnce // ignore: cast_nullable_to_non_nullable
as bool,selfDestructSeconds: null == selfDestructSeconds ? _self.selfDestructSeconds : selfDestructSeconds // ignore: cast_nullable_to_non_nullable
as int,sentAt: null == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,sendState: null == sendState ? _self.sendState : sendState // ignore: cast_nullable_to_non_nullable
as MessageSendState,reactions: null == reactions ? _self.reactions : reactions // ignore: cast_nullable_to_non_nullable
as Map<String, int>,chosenReactions: null == chosenReactions ? _self.chosenReactions : chosenReactions // ignore: cast_nullable_to_non_nullable
as Set<String>,replyToMessageId: freezed == replyToMessageId ? _self.replyToMessageId : replyToMessageId // ignore: cast_nullable_to_non_nullable
as int?,replyToText: freezed == replyToText ? _self.replyToText : replyToText // ignore: cast_nullable_to_non_nullable
as String?,replyToAuthorName: freezed == replyToAuthorName ? _self.replyToAuthorName : replyToAuthorName // ignore: cast_nullable_to_non_nullable
as String?,replyToChatId: freezed == replyToChatId ? _self.replyToChatId : replyToChatId // ignore: cast_nullable_to_non_nullable
as int?,replyToThumbnailFileId: freezed == replyToThumbnailFileId ? _self.replyToThumbnailFileId : replyToThumbnailFileId // ignore: cast_nullable_to_non_nullable
as int?,forwardedFromTitle: freezed == forwardedFromTitle ? _self.forwardedFromTitle : forwardedFromTitle // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewUrl: freezed == linkPreviewUrl ? _self.linkPreviewUrl : linkPreviewUrl // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewTitle: freezed == linkPreviewTitle ? _self.linkPreviewTitle : linkPreviewTitle // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewDescription: freezed == linkPreviewDescription ? _self.linkPreviewDescription : linkPreviewDescription // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewFileId: freezed == linkPreviewFileId ? _self.linkPreviewFileId : linkPreviewFileId // ignore: cast_nullable_to_non_nullable
as int?,isPinned: null == isPinned ? _self.isPinned : isPinned // ignore: cast_nullable_to_non_nullable
as bool,isService: null == isService ? _self.isService : isService // ignore: cast_nullable_to_non_nullable
as bool,unsupportedKind: freezed == unsupportedKind ? _self.unsupportedKind : unsupportedKind // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of ChatMessage
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


/// Adds pattern-matching-related methods to [ChatMessage].
extension ChatMessagePatterns on ChatMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatMessage value)  $default,){
final _that = this;
switch (_that) {
case _ChatMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatMessage value)?  $default,){
final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int chatId,  int messageId,  int mediaAlbumId,  bool isOutgoing,  int? senderId,  String? senderName,  String? senderAvatarPath,  int? senderAvatarFileId,  String? senderAvatarColorHex,  String? text,  List<TextEntity> entities,  List<MediaItem> media, @JsonKey(fromJson: _pollFromJson, toJson: _pollToJson)  Poll? poll, @JsonKey(fromJson: _placeFromJson, toJson: _placeToJson)  MessagePlace? place, @JsonKey(fromJson: _contactFromJson, toJson: _contactToJson)  MessageContactCard? contact,  bool isSecretMedia,  bool isViewOnce,  int selfDestructSeconds,  DateTime sentAt,  DateTime? editedAt,  MessageSendState sendState,  Map<String, int> reactions,  Set<String> chosenReactions,  int? replyToMessageId,  String? replyToText,  String? replyToAuthorName,  int? replyToChatId,  int? replyToThumbnailFileId,  String? forwardedFromTitle,  String? linkPreviewUrl,  String? linkPreviewTitle,  String? linkPreviewDescription,  int? linkPreviewFileId,  bool isPinned,  bool isService,  String? unsupportedKind)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
return $default(_that.id,_that.chatId,_that.messageId,_that.mediaAlbumId,_that.isOutgoing,_that.senderId,_that.senderName,_that.senderAvatarPath,_that.senderAvatarFileId,_that.senderAvatarColorHex,_that.text,_that.entities,_that.media,_that.poll,_that.place,_that.contact,_that.isSecretMedia,_that.isViewOnce,_that.selfDestructSeconds,_that.sentAt,_that.editedAt,_that.sendState,_that.reactions,_that.chosenReactions,_that.replyToMessageId,_that.replyToText,_that.replyToAuthorName,_that.replyToChatId,_that.replyToThumbnailFileId,_that.forwardedFromTitle,_that.linkPreviewUrl,_that.linkPreviewTitle,_that.linkPreviewDescription,_that.linkPreviewFileId,_that.isPinned,_that.isService,_that.unsupportedKind);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int chatId,  int messageId,  int mediaAlbumId,  bool isOutgoing,  int? senderId,  String? senderName,  String? senderAvatarPath,  int? senderAvatarFileId,  String? senderAvatarColorHex,  String? text,  List<TextEntity> entities,  List<MediaItem> media, @JsonKey(fromJson: _pollFromJson, toJson: _pollToJson)  Poll? poll, @JsonKey(fromJson: _placeFromJson, toJson: _placeToJson)  MessagePlace? place, @JsonKey(fromJson: _contactFromJson, toJson: _contactToJson)  MessageContactCard? contact,  bool isSecretMedia,  bool isViewOnce,  int selfDestructSeconds,  DateTime sentAt,  DateTime? editedAt,  MessageSendState sendState,  Map<String, int> reactions,  Set<String> chosenReactions,  int? replyToMessageId,  String? replyToText,  String? replyToAuthorName,  int? replyToChatId,  int? replyToThumbnailFileId,  String? forwardedFromTitle,  String? linkPreviewUrl,  String? linkPreviewTitle,  String? linkPreviewDescription,  int? linkPreviewFileId,  bool isPinned,  bool isService,  String? unsupportedKind)  $default,) {final _that = this;
switch (_that) {
case _ChatMessage():
return $default(_that.id,_that.chatId,_that.messageId,_that.mediaAlbumId,_that.isOutgoing,_that.senderId,_that.senderName,_that.senderAvatarPath,_that.senderAvatarFileId,_that.senderAvatarColorHex,_that.text,_that.entities,_that.media,_that.poll,_that.place,_that.contact,_that.isSecretMedia,_that.isViewOnce,_that.selfDestructSeconds,_that.sentAt,_that.editedAt,_that.sendState,_that.reactions,_that.chosenReactions,_that.replyToMessageId,_that.replyToText,_that.replyToAuthorName,_that.replyToChatId,_that.replyToThumbnailFileId,_that.forwardedFromTitle,_that.linkPreviewUrl,_that.linkPreviewTitle,_that.linkPreviewDescription,_that.linkPreviewFileId,_that.isPinned,_that.isService,_that.unsupportedKind);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int chatId,  int messageId,  int mediaAlbumId,  bool isOutgoing,  int? senderId,  String? senderName,  String? senderAvatarPath,  int? senderAvatarFileId,  String? senderAvatarColorHex,  String? text,  List<TextEntity> entities,  List<MediaItem> media, @JsonKey(fromJson: _pollFromJson, toJson: _pollToJson)  Poll? poll, @JsonKey(fromJson: _placeFromJson, toJson: _placeToJson)  MessagePlace? place, @JsonKey(fromJson: _contactFromJson, toJson: _contactToJson)  MessageContactCard? contact,  bool isSecretMedia,  bool isViewOnce,  int selfDestructSeconds,  DateTime sentAt,  DateTime? editedAt,  MessageSendState sendState,  Map<String, int> reactions,  Set<String> chosenReactions,  int? replyToMessageId,  String? replyToText,  String? replyToAuthorName,  int? replyToChatId,  int? replyToThumbnailFileId,  String? forwardedFromTitle,  String? linkPreviewUrl,  String? linkPreviewTitle,  String? linkPreviewDescription,  int? linkPreviewFileId,  bool isPinned,  bool isService,  String? unsupportedKind)?  $default,) {final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
return $default(_that.id,_that.chatId,_that.messageId,_that.mediaAlbumId,_that.isOutgoing,_that.senderId,_that.senderName,_that.senderAvatarPath,_that.senderAvatarFileId,_that.senderAvatarColorHex,_that.text,_that.entities,_that.media,_that.poll,_that.place,_that.contact,_that.isSecretMedia,_that.isViewOnce,_that.selfDestructSeconds,_that.sentAt,_that.editedAt,_that.sendState,_that.reactions,_that.chosenReactions,_that.replyToMessageId,_that.replyToText,_that.replyToAuthorName,_that.replyToChatId,_that.replyToThumbnailFileId,_that.forwardedFromTitle,_that.linkPreviewUrl,_that.linkPreviewTitle,_that.linkPreviewDescription,_that.linkPreviewFileId,_that.isPinned,_that.isService,_that.unsupportedKind);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChatMessage extends ChatMessage {
  const _ChatMessage({required this.id, required this.chatId, required this.messageId, this.mediaAlbumId = 0, required this.isOutgoing, this.senderId, this.senderName, this.senderAvatarPath, this.senderAvatarFileId, this.senderAvatarColorHex, this.text, final  List<TextEntity> entities = const [], final  List<MediaItem> media = const [], @JsonKey(fromJson: _pollFromJson, toJson: _pollToJson) this.poll, @JsonKey(fromJson: _placeFromJson, toJson: _placeToJson) this.place, @JsonKey(fromJson: _contactFromJson, toJson: _contactToJson) this.contact, this.isSecretMedia = false, this.isViewOnce = false, this.selfDestructSeconds = 0, required this.sentAt, this.editedAt, this.sendState = MessageSendState.sent, final  Map<String, int> reactions = const {}, final  Set<String> chosenReactions = const {}, this.replyToMessageId, this.replyToText, this.replyToAuthorName, this.replyToChatId, this.replyToThumbnailFileId, this.forwardedFromTitle, this.linkPreviewUrl, this.linkPreviewTitle, this.linkPreviewDescription, this.linkPreviewFileId, this.isPinned = false, this.isService = false, this.unsupportedKind}): _entities = entities,_media = media,_reactions = reactions,_chosenReactions = chosenReactions,super._();
  factory _ChatMessage.fromJson(Map<String, dynamic> json) => _$ChatMessageFromJson(json);

/// `"<chatId>_<messageId>"`, the same key shape the rest of the app uses.
@override final  String id;
@override final  int chatId;
@override final  int messageId;
/// Album members share this. Zero when the message stands alone.
@override@JsonKey() final  int mediaAlbumId;
/// True when this account sent it. Decides which side the bubble sits on,
/// and whether a send state is drawn at all.
@override final  bool isOutgoing;
/// Who sent it. Null for a message from an anonymous admin or a channel
/// posting into its discussion group.
@override final  int? senderId;
/// The sender's display name. Only drawn in groups — in a private chat the
/// two possible senders are the two people looking at it.
@override final  String? senderName;
@override final  String? senderAvatarPath;
@override final  int? senderAvatarFileId;
@override final  String? senderAvatarColorHex;
@override final  String? text;
 final  List<TextEntity> _entities;
@override@JsonKey() List<TextEntity> get entities {
  if (_entities is EqualUnmodifiableListView) return _entities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entities);
}

 final  List<MediaItem> _media;
@override@JsonKey() List<MediaItem> get media {
  if (_media is EqualUnmodifiableListView) return _media;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_media);
}

/// The poll this message is, if it is one.
///
/// Carried rather than flattened to its question text. A poll bubble used
/// to render as an empty box: `MessagePoll` is content the feed draws in
/// full, so it had no fallback label to borrow, and nothing here knew what
/// to do with it — a message with no words, no media and no poll is a
/// bubble with nothing in it.
@override@JsonKey(fromJson: _pollFromJson, toJson: _pollToJson) final  Poll? poll;
/// A place somebody sent: a location, or a venue with a name on it.
///
/// Drawn as a card rather than reduced to the words "📍 Location", which
/// is what a conversation showed for one — a label with the coordinates
/// thrown away, so the one thing a location is for could not be done with
/// it.
@override@JsonKey(fromJson: _placeFromJson, toJson: _placeToJson) final  MessagePlace? place;
/// A contact card somebody sent.
@override@JsonKey(fromJson: _contactFromJson, toJson: _contactToJson) final  MessageContactCard? contact;
/// True while this message's media is Telegram's tap-to-view kind and has
/// not been opened. The bubble draws a cover rather than the picture, which
/// is the whole point of it.
@override@JsonKey() final  bool isSecretMedia;
/// True when the media is "view once": gone when the viewer closes it,
/// however long they looked. Mutually exclusive with
/// [selfDestructSeconds] — Telegram's type is one or the other.
@override@JsonKey() final  bool isViewOnce;
/// How long the viewer gets once they open it, in seconds. Zero for
/// [isViewOnce] media and for anything that does not self-destruct.
@override@JsonKey() final  int selfDestructSeconds;
@override final  DateTime sentAt;
/// When Telegram says the message was edited, if it was.
@override final  DateTime? editedAt;
@override@JsonKey() final  MessageSendState sendState;
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

/// The message this one replies to, when there is one.
@override final  int? replyToMessageId;
@override final  String? replyToText;
@override final  String? replyToAuthorName;
/// The chat the replied-to message lives in, when it isn't this one.
/// Telegram allows replies across chats, and assuming otherwise sends the
/// reader to a message id in the wrong chat.
@override final  int? replyToChatId;
@override final  int? replyToThumbnailFileId;
/// Where a forwarded message came from, as Telegram will name it. Null
/// when the origin is hidden, which Telegram allows.
@override final  String? forwardedFromTitle;
@override final  String? linkPreviewUrl;
@override final  String? linkPreviewTitle;
@override final  String? linkPreviewDescription;
@override final  int? linkPreviewFileId;
/// Whether this message is pinned to the top of the chat.
///
/// Read so the long-press menu can offer the right one of Pin and Unpin.
/// It arrives on `updateMessageIsPinned` rather than as a content change,
/// because nothing about the message itself moved.
@override@JsonKey() final  bool isPinned;
/// Telegram's own notice about the chat — "you joined", "photo changed".
/// Drawn as a centred line rather than a bubble, the way every Telegram
/// client does it, so it reads as narration and not as something somebody
/// said.
@override@JsonKey() final  bool isService;
/// Set when Telegram sent content this build cannot draw: the TDLib type
/// name, so the bubble can offer Telegram rather than showing an empty box.
@override final  String? unsupportedKind;

/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatMessageCopyWith<_ChatMessage> get copyWith => __$ChatMessageCopyWithImpl<_ChatMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.mediaAlbumId, mediaAlbumId) || other.mediaAlbumId == mediaAlbumId)&&(identical(other.isOutgoing, isOutgoing) || other.isOutgoing == isOutgoing)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.senderName, senderName) || other.senderName == senderName)&&(identical(other.senderAvatarPath, senderAvatarPath) || other.senderAvatarPath == senderAvatarPath)&&(identical(other.senderAvatarFileId, senderAvatarFileId) || other.senderAvatarFileId == senderAvatarFileId)&&(identical(other.senderAvatarColorHex, senderAvatarColorHex) || other.senderAvatarColorHex == senderAvatarColorHex)&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other._entities, _entities)&&const DeepCollectionEquality().equals(other._media, _media)&&(identical(other.poll, poll) || other.poll == poll)&&(identical(other.place, place) || other.place == place)&&(identical(other.contact, contact) || other.contact == contact)&&(identical(other.isSecretMedia, isSecretMedia) || other.isSecretMedia == isSecretMedia)&&(identical(other.isViewOnce, isViewOnce) || other.isViewOnce == isViewOnce)&&(identical(other.selfDestructSeconds, selfDestructSeconds) || other.selfDestructSeconds == selfDestructSeconds)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.sendState, sendState) || other.sendState == sendState)&&const DeepCollectionEquality().equals(other._reactions, _reactions)&&const DeepCollectionEquality().equals(other._chosenReactions, _chosenReactions)&&(identical(other.replyToMessageId, replyToMessageId) || other.replyToMessageId == replyToMessageId)&&(identical(other.replyToText, replyToText) || other.replyToText == replyToText)&&(identical(other.replyToAuthorName, replyToAuthorName) || other.replyToAuthorName == replyToAuthorName)&&(identical(other.replyToChatId, replyToChatId) || other.replyToChatId == replyToChatId)&&(identical(other.replyToThumbnailFileId, replyToThumbnailFileId) || other.replyToThumbnailFileId == replyToThumbnailFileId)&&(identical(other.forwardedFromTitle, forwardedFromTitle) || other.forwardedFromTitle == forwardedFromTitle)&&(identical(other.linkPreviewUrl, linkPreviewUrl) || other.linkPreviewUrl == linkPreviewUrl)&&(identical(other.linkPreviewTitle, linkPreviewTitle) || other.linkPreviewTitle == linkPreviewTitle)&&(identical(other.linkPreviewDescription, linkPreviewDescription) || other.linkPreviewDescription == linkPreviewDescription)&&(identical(other.linkPreviewFileId, linkPreviewFileId) || other.linkPreviewFileId == linkPreviewFileId)&&(identical(other.isPinned, isPinned) || other.isPinned == isPinned)&&(identical(other.isService, isService) || other.isService == isService)&&(identical(other.unsupportedKind, unsupportedKind) || other.unsupportedKind == unsupportedKind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,chatId,messageId,mediaAlbumId,isOutgoing,senderId,senderName,senderAvatarPath,senderAvatarFileId,senderAvatarColorHex,text,const DeepCollectionEquality().hash(_entities),const DeepCollectionEquality().hash(_media),poll,place,contact,isSecretMedia,isViewOnce,selfDestructSeconds,sentAt,editedAt,sendState,const DeepCollectionEquality().hash(_reactions),const DeepCollectionEquality().hash(_chosenReactions),replyToMessageId,replyToText,replyToAuthorName,replyToChatId,replyToThumbnailFileId,forwardedFromTitle,linkPreviewUrl,linkPreviewTitle,linkPreviewDescription,linkPreviewFileId,isPinned,isService,unsupportedKind]);

@override
String toString() {
  return 'ChatMessage(id: $id, chatId: $chatId, messageId: $messageId, mediaAlbumId: $mediaAlbumId, isOutgoing: $isOutgoing, senderId: $senderId, senderName: $senderName, senderAvatarPath: $senderAvatarPath, senderAvatarFileId: $senderAvatarFileId, senderAvatarColorHex: $senderAvatarColorHex, text: $text, entities: $entities, media: $media, poll: $poll, place: $place, contact: $contact, isSecretMedia: $isSecretMedia, isViewOnce: $isViewOnce, selfDestructSeconds: $selfDestructSeconds, sentAt: $sentAt, editedAt: $editedAt, sendState: $sendState, reactions: $reactions, chosenReactions: $chosenReactions, replyToMessageId: $replyToMessageId, replyToText: $replyToText, replyToAuthorName: $replyToAuthorName, replyToChatId: $replyToChatId, replyToThumbnailFileId: $replyToThumbnailFileId, forwardedFromTitle: $forwardedFromTitle, linkPreviewUrl: $linkPreviewUrl, linkPreviewTitle: $linkPreviewTitle, linkPreviewDescription: $linkPreviewDescription, linkPreviewFileId: $linkPreviewFileId, isPinned: $isPinned, isService: $isService, unsupportedKind: $unsupportedKind)';
}


}

/// @nodoc
abstract mixin class _$ChatMessageCopyWith<$Res> implements $ChatMessageCopyWith<$Res> {
  factory _$ChatMessageCopyWith(_ChatMessage value, $Res Function(_ChatMessage) _then) = __$ChatMessageCopyWithImpl;
@override @useResult
$Res call({
 String id, int chatId, int messageId, int mediaAlbumId, bool isOutgoing, int? senderId, String? senderName, String? senderAvatarPath, int? senderAvatarFileId, String? senderAvatarColorHex, String? text, List<TextEntity> entities, List<MediaItem> media,@JsonKey(fromJson: _pollFromJson, toJson: _pollToJson) Poll? poll,@JsonKey(fromJson: _placeFromJson, toJson: _placeToJson) MessagePlace? place,@JsonKey(fromJson: _contactFromJson, toJson: _contactToJson) MessageContactCard? contact, bool isSecretMedia, bool isViewOnce, int selfDestructSeconds, DateTime sentAt, DateTime? editedAt, MessageSendState sendState, Map<String, int> reactions, Set<String> chosenReactions, int? replyToMessageId, String? replyToText, String? replyToAuthorName, int? replyToChatId, int? replyToThumbnailFileId, String? forwardedFromTitle, String? linkPreviewUrl, String? linkPreviewTitle, String? linkPreviewDescription, int? linkPreviewFileId, bool isPinned, bool isService, String? unsupportedKind
});


@override $PollCopyWith<$Res>? get poll;

}
/// @nodoc
class __$ChatMessageCopyWithImpl<$Res>
    implements _$ChatMessageCopyWith<$Res> {
  __$ChatMessageCopyWithImpl(this._self, this._then);

  final _ChatMessage _self;
  final $Res Function(_ChatMessage) _then;

/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? chatId = null,Object? messageId = null,Object? mediaAlbumId = null,Object? isOutgoing = null,Object? senderId = freezed,Object? senderName = freezed,Object? senderAvatarPath = freezed,Object? senderAvatarFileId = freezed,Object? senderAvatarColorHex = freezed,Object? text = freezed,Object? entities = null,Object? media = null,Object? poll = freezed,Object? place = freezed,Object? contact = freezed,Object? isSecretMedia = null,Object? isViewOnce = null,Object? selfDestructSeconds = null,Object? sentAt = null,Object? editedAt = freezed,Object? sendState = null,Object? reactions = null,Object? chosenReactions = null,Object? replyToMessageId = freezed,Object? replyToText = freezed,Object? replyToAuthorName = freezed,Object? replyToChatId = freezed,Object? replyToThumbnailFileId = freezed,Object? forwardedFromTitle = freezed,Object? linkPreviewUrl = freezed,Object? linkPreviewTitle = freezed,Object? linkPreviewDescription = freezed,Object? linkPreviewFileId = freezed,Object? isPinned = null,Object? isService = null,Object? unsupportedKind = freezed,}) {
  return _then(_ChatMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as int,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as int,mediaAlbumId: null == mediaAlbumId ? _self.mediaAlbumId : mediaAlbumId // ignore: cast_nullable_to_non_nullable
as int,isOutgoing: null == isOutgoing ? _self.isOutgoing : isOutgoing // ignore: cast_nullable_to_non_nullable
as bool,senderId: freezed == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as int?,senderName: freezed == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String?,senderAvatarPath: freezed == senderAvatarPath ? _self.senderAvatarPath : senderAvatarPath // ignore: cast_nullable_to_non_nullable
as String?,senderAvatarFileId: freezed == senderAvatarFileId ? _self.senderAvatarFileId : senderAvatarFileId // ignore: cast_nullable_to_non_nullable
as int?,senderAvatarColorHex: freezed == senderAvatarColorHex ? _self.senderAvatarColorHex : senderAvatarColorHex // ignore: cast_nullable_to_non_nullable
as String?,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,entities: null == entities ? _self._entities : entities // ignore: cast_nullable_to_non_nullable
as List<TextEntity>,media: null == media ? _self._media : media // ignore: cast_nullable_to_non_nullable
as List<MediaItem>,poll: freezed == poll ? _self.poll : poll // ignore: cast_nullable_to_non_nullable
as Poll?,place: freezed == place ? _self.place : place // ignore: cast_nullable_to_non_nullable
as MessagePlace?,contact: freezed == contact ? _self.contact : contact // ignore: cast_nullable_to_non_nullable
as MessageContactCard?,isSecretMedia: null == isSecretMedia ? _self.isSecretMedia : isSecretMedia // ignore: cast_nullable_to_non_nullable
as bool,isViewOnce: null == isViewOnce ? _self.isViewOnce : isViewOnce // ignore: cast_nullable_to_non_nullable
as bool,selfDestructSeconds: null == selfDestructSeconds ? _self.selfDestructSeconds : selfDestructSeconds // ignore: cast_nullable_to_non_nullable
as int,sentAt: null == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,sendState: null == sendState ? _self.sendState : sendState // ignore: cast_nullable_to_non_nullable
as MessageSendState,reactions: null == reactions ? _self._reactions : reactions // ignore: cast_nullable_to_non_nullable
as Map<String, int>,chosenReactions: null == chosenReactions ? _self._chosenReactions : chosenReactions // ignore: cast_nullable_to_non_nullable
as Set<String>,replyToMessageId: freezed == replyToMessageId ? _self.replyToMessageId : replyToMessageId // ignore: cast_nullable_to_non_nullable
as int?,replyToText: freezed == replyToText ? _self.replyToText : replyToText // ignore: cast_nullable_to_non_nullable
as String?,replyToAuthorName: freezed == replyToAuthorName ? _self.replyToAuthorName : replyToAuthorName // ignore: cast_nullable_to_non_nullable
as String?,replyToChatId: freezed == replyToChatId ? _self.replyToChatId : replyToChatId // ignore: cast_nullable_to_non_nullable
as int?,replyToThumbnailFileId: freezed == replyToThumbnailFileId ? _self.replyToThumbnailFileId : replyToThumbnailFileId // ignore: cast_nullable_to_non_nullable
as int?,forwardedFromTitle: freezed == forwardedFromTitle ? _self.forwardedFromTitle : forwardedFromTitle // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewUrl: freezed == linkPreviewUrl ? _self.linkPreviewUrl : linkPreviewUrl // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewTitle: freezed == linkPreviewTitle ? _self.linkPreviewTitle : linkPreviewTitle // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewDescription: freezed == linkPreviewDescription ? _self.linkPreviewDescription : linkPreviewDescription // ignore: cast_nullable_to_non_nullable
as String?,linkPreviewFileId: freezed == linkPreviewFileId ? _self.linkPreviewFileId : linkPreviewFileId // ignore: cast_nullable_to_non_nullable
as int?,isPinned: null == isPinned ? _self.isPinned : isPinned // ignore: cast_nullable_to_non_nullable
as bool,isService: null == isService ? _self.isService : isService // ignore: cast_nullable_to_non_nullable
as bool,unsupportedKind: freezed == unsupportedKind ? _self.unsupportedKind : unsupportedKind // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of ChatMessage
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
