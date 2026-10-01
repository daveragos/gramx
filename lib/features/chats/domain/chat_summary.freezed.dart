// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatSummary {

 int get chatId; String get title; ChatKind get kind; String? get username; String? get avatarPath; int? get avatarFileId; String? get avatarColorHex;/// The one-line preview under the title, already collapsed by
/// `TdlibMappers.excerptOf`.
 String? get preview;/// The sender's name, prefixed to [preview] in a group ("Ada: on my way").
/// Null in a private chat.
 String? get previewSender;/// Set when [preview] is an unsent draft rather than a received message.
 bool get previewIsDraft;/// Delivery state of the last message, only when this account sent it.
/// Uses the same state as the bubbles so the row and the conversation agree.
 MessageSendState? get previewSendState;/// The user's personal channel, shown as a badge on the row. Read only
/// from the cached `UserFullInfo`, never fetched per row.
 int? get affiliatedChannelId; String? get affiliatedChannelTitle; String? get affiliatedChannelAvatarPath; int? get affiliatedChannelAvatarFileId; String? get affiliatedChannelAvatarColorHex; DateTime? get lastMessageAt; int get unreadCount;/// Marked unread by hand. It carries no count, so a row checking only
/// [unreadCount] would show it as read.
 bool get isMarkedAsUnread; int get unreadMentionCount;/// Unseen reactions to this account's own messages. Comes on the update
/// stream like [unreadMentionCount], and feeds the Activity screen.
 int get unreadReactionCount; bool get isMuted; bool get isVerified;/// A Telegram Premium account. The row shows the Premium star, never
/// [emojiStatusId], to keep the list easy to scan.
 bool get isPremium;/// The unexpired custom emoji a Premium account shows in place of the star.
/// Used in the conversation header only.
 int? get emojiStatusId;/// A chat from somebody not in the user's contacts, the kind Telegram
/// shows its "report / add / block" bar on.
 bool get isRequest; ChatPresence get presence;/// TDLib's ordering value for the main chat list. Pinned chats get a very
/// high order, so sorting by this puts them first.
 int get mainListOrder;/// Pinned in the main chat list, so the row can show a pin.
 bool get isPinned;/// An end-to-end encrypted chat, drawn with a lock.
 bool get isSecret;/// True while a secret chat's key exchange is pending. Telegram refuses
/// messages until the other device comes online.
 bool get isSecretPending;
/// Create a copy of ChatSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatSummaryCopyWith<ChatSummary> get copyWith => _$ChatSummaryCopyWithImpl<ChatSummary>(this as ChatSummary, _$identity);

  /// Serializes this ChatSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatSummary&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.title, title) || other.title == title)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.username, username) || other.username == username)&&(identical(other.avatarPath, avatarPath) || other.avatarPath == avatarPath)&&(identical(other.avatarFileId, avatarFileId) || other.avatarFileId == avatarFileId)&&(identical(other.avatarColorHex, avatarColorHex) || other.avatarColorHex == avatarColorHex)&&(identical(other.preview, preview) || other.preview == preview)&&(identical(other.previewSender, previewSender) || other.previewSender == previewSender)&&(identical(other.previewIsDraft, previewIsDraft) || other.previewIsDraft == previewIsDraft)&&(identical(other.previewSendState, previewSendState) || other.previewSendState == previewSendState)&&(identical(other.affiliatedChannelId, affiliatedChannelId) || other.affiliatedChannelId == affiliatedChannelId)&&(identical(other.affiliatedChannelTitle, affiliatedChannelTitle) || other.affiliatedChannelTitle == affiliatedChannelTitle)&&(identical(other.affiliatedChannelAvatarPath, affiliatedChannelAvatarPath) || other.affiliatedChannelAvatarPath == affiliatedChannelAvatarPath)&&(identical(other.affiliatedChannelAvatarFileId, affiliatedChannelAvatarFileId) || other.affiliatedChannelAvatarFileId == affiliatedChannelAvatarFileId)&&(identical(other.affiliatedChannelAvatarColorHex, affiliatedChannelAvatarColorHex) || other.affiliatedChannelAvatarColorHex == affiliatedChannelAvatarColorHex)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.isMarkedAsUnread, isMarkedAsUnread) || other.isMarkedAsUnread == isMarkedAsUnread)&&(identical(other.unreadMentionCount, unreadMentionCount) || other.unreadMentionCount == unreadMentionCount)&&(identical(other.unreadReactionCount, unreadReactionCount) || other.unreadReactionCount == unreadReactionCount)&&(identical(other.isMuted, isMuted) || other.isMuted == isMuted)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.isPremium, isPremium) || other.isPremium == isPremium)&&(identical(other.emojiStatusId, emojiStatusId) || other.emojiStatusId == emojiStatusId)&&(identical(other.isRequest, isRequest) || other.isRequest == isRequest)&&(identical(other.presence, presence) || other.presence == presence)&&(identical(other.mainListOrder, mainListOrder) || other.mainListOrder == mainListOrder)&&(identical(other.isPinned, isPinned) || other.isPinned == isPinned)&&(identical(other.isSecret, isSecret) || other.isSecret == isSecret)&&(identical(other.isSecretPending, isSecretPending) || other.isSecretPending == isSecretPending));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,chatId,title,kind,username,avatarPath,avatarFileId,avatarColorHex,preview,previewSender,previewIsDraft,previewSendState,affiliatedChannelId,affiliatedChannelTitle,affiliatedChannelAvatarPath,affiliatedChannelAvatarFileId,affiliatedChannelAvatarColorHex,lastMessageAt,unreadCount,isMarkedAsUnread,unreadMentionCount,unreadReactionCount,isMuted,isVerified,isPremium,emojiStatusId,isRequest,presence,mainListOrder,isPinned,isSecret,isSecretPending]);

@override
String toString() {
  return 'ChatSummary(chatId: $chatId, title: $title, kind: $kind, username: $username, avatarPath: $avatarPath, avatarFileId: $avatarFileId, avatarColorHex: $avatarColorHex, preview: $preview, previewSender: $previewSender, previewIsDraft: $previewIsDraft, previewSendState: $previewSendState, affiliatedChannelId: $affiliatedChannelId, affiliatedChannelTitle: $affiliatedChannelTitle, affiliatedChannelAvatarPath: $affiliatedChannelAvatarPath, affiliatedChannelAvatarFileId: $affiliatedChannelAvatarFileId, affiliatedChannelAvatarColorHex: $affiliatedChannelAvatarColorHex, lastMessageAt: $lastMessageAt, unreadCount: $unreadCount, isMarkedAsUnread: $isMarkedAsUnread, unreadMentionCount: $unreadMentionCount, unreadReactionCount: $unreadReactionCount, isMuted: $isMuted, isVerified: $isVerified, isPremium: $isPremium, emojiStatusId: $emojiStatusId, isRequest: $isRequest, presence: $presence, mainListOrder: $mainListOrder, isPinned: $isPinned, isSecret: $isSecret, isSecretPending: $isSecretPending)';
}


}

/// @nodoc
abstract mixin class $ChatSummaryCopyWith<$Res>  {
  factory $ChatSummaryCopyWith(ChatSummary value, $Res Function(ChatSummary) _then) = _$ChatSummaryCopyWithImpl;
@useResult
$Res call({
 int chatId, String title, ChatKind kind, String? username, String? avatarPath, int? avatarFileId, String? avatarColorHex, String? preview, String? previewSender, bool previewIsDraft, MessageSendState? previewSendState, int? affiliatedChannelId, String? affiliatedChannelTitle, String? affiliatedChannelAvatarPath, int? affiliatedChannelAvatarFileId, String? affiliatedChannelAvatarColorHex, DateTime? lastMessageAt, int unreadCount, bool isMarkedAsUnread, int unreadMentionCount, int unreadReactionCount, bool isMuted, bool isVerified, bool isPremium, int? emojiStatusId, bool isRequest, ChatPresence presence, int mainListOrder, bool isPinned, bool isSecret, bool isSecretPending
});




}
/// @nodoc
class _$ChatSummaryCopyWithImpl<$Res>
    implements $ChatSummaryCopyWith<$Res> {
  _$ChatSummaryCopyWithImpl(this._self, this._then);

  final ChatSummary _self;
  final $Res Function(ChatSummary) _then;

/// Create a copy of ChatSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chatId = null,Object? title = null,Object? kind = null,Object? username = freezed,Object? avatarPath = freezed,Object? avatarFileId = freezed,Object? avatarColorHex = freezed,Object? preview = freezed,Object? previewSender = freezed,Object? previewIsDraft = null,Object? previewSendState = freezed,Object? affiliatedChannelId = freezed,Object? affiliatedChannelTitle = freezed,Object? affiliatedChannelAvatarPath = freezed,Object? affiliatedChannelAvatarFileId = freezed,Object? affiliatedChannelAvatarColorHex = freezed,Object? lastMessageAt = freezed,Object? unreadCount = null,Object? isMarkedAsUnread = null,Object? unreadMentionCount = null,Object? unreadReactionCount = null,Object? isMuted = null,Object? isVerified = null,Object? isPremium = null,Object? emojiStatusId = freezed,Object? isRequest = null,Object? presence = null,Object? mainListOrder = null,Object? isPinned = null,Object? isSecret = null,Object? isSecretPending = null,}) {
  return _then(_self.copyWith(
chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ChatKind,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,avatarPath: freezed == avatarPath ? _self.avatarPath : avatarPath // ignore: cast_nullable_to_non_nullable
as String?,avatarFileId: freezed == avatarFileId ? _self.avatarFileId : avatarFileId // ignore: cast_nullable_to_non_nullable
as int?,avatarColorHex: freezed == avatarColorHex ? _self.avatarColorHex : avatarColorHex // ignore: cast_nullable_to_non_nullable
as String?,preview: freezed == preview ? _self.preview : preview // ignore: cast_nullable_to_non_nullable
as String?,previewSender: freezed == previewSender ? _self.previewSender : previewSender // ignore: cast_nullable_to_non_nullable
as String?,previewIsDraft: null == previewIsDraft ? _self.previewIsDraft : previewIsDraft // ignore: cast_nullable_to_non_nullable
as bool,previewSendState: freezed == previewSendState ? _self.previewSendState : previewSendState // ignore: cast_nullable_to_non_nullable
as MessageSendState?,affiliatedChannelId: freezed == affiliatedChannelId ? _self.affiliatedChannelId : affiliatedChannelId // ignore: cast_nullable_to_non_nullable
as int?,affiliatedChannelTitle: freezed == affiliatedChannelTitle ? _self.affiliatedChannelTitle : affiliatedChannelTitle // ignore: cast_nullable_to_non_nullable
as String?,affiliatedChannelAvatarPath: freezed == affiliatedChannelAvatarPath ? _self.affiliatedChannelAvatarPath : affiliatedChannelAvatarPath // ignore: cast_nullable_to_non_nullable
as String?,affiliatedChannelAvatarFileId: freezed == affiliatedChannelAvatarFileId ? _self.affiliatedChannelAvatarFileId : affiliatedChannelAvatarFileId // ignore: cast_nullable_to_non_nullable
as int?,affiliatedChannelAvatarColorHex: freezed == affiliatedChannelAvatarColorHex ? _self.affiliatedChannelAvatarColorHex : affiliatedChannelAvatarColorHex // ignore: cast_nullable_to_non_nullable
as String?,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,isMarkedAsUnread: null == isMarkedAsUnread ? _self.isMarkedAsUnread : isMarkedAsUnread // ignore: cast_nullable_to_non_nullable
as bool,unreadMentionCount: null == unreadMentionCount ? _self.unreadMentionCount : unreadMentionCount // ignore: cast_nullable_to_non_nullable
as int,unreadReactionCount: null == unreadReactionCount ? _self.unreadReactionCount : unreadReactionCount // ignore: cast_nullable_to_non_nullable
as int,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,isPremium: null == isPremium ? _self.isPremium : isPremium // ignore: cast_nullable_to_non_nullable
as bool,emojiStatusId: freezed == emojiStatusId ? _self.emojiStatusId : emojiStatusId // ignore: cast_nullable_to_non_nullable
as int?,isRequest: null == isRequest ? _self.isRequest : isRequest // ignore: cast_nullable_to_non_nullable
as bool,presence: null == presence ? _self.presence : presence // ignore: cast_nullable_to_non_nullable
as ChatPresence,mainListOrder: null == mainListOrder ? _self.mainListOrder : mainListOrder // ignore: cast_nullable_to_non_nullable
as int,isPinned: null == isPinned ? _self.isPinned : isPinned // ignore: cast_nullable_to_non_nullable
as bool,isSecret: null == isSecret ? _self.isSecret : isSecret // ignore: cast_nullable_to_non_nullable
as bool,isSecretPending: null == isSecretPending ? _self.isSecretPending : isSecretPending // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatSummary].
extension ChatSummaryPatterns on ChatSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatSummary value)  $default,){
final _that = this;
switch (_that) {
case _ChatSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatSummary value)?  $default,){
final _that = this;
switch (_that) {
case _ChatSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int chatId,  String title,  ChatKind kind,  String? username,  String? avatarPath,  int? avatarFileId,  String? avatarColorHex,  String? preview,  String? previewSender,  bool previewIsDraft,  MessageSendState? previewSendState,  int? affiliatedChannelId,  String? affiliatedChannelTitle,  String? affiliatedChannelAvatarPath,  int? affiliatedChannelAvatarFileId,  String? affiliatedChannelAvatarColorHex,  DateTime? lastMessageAt,  int unreadCount,  bool isMarkedAsUnread,  int unreadMentionCount,  int unreadReactionCount,  bool isMuted,  bool isVerified,  bool isPremium,  int? emojiStatusId,  bool isRequest,  ChatPresence presence,  int mainListOrder,  bool isPinned,  bool isSecret,  bool isSecretPending)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatSummary() when $default != null:
return $default(_that.chatId,_that.title,_that.kind,_that.username,_that.avatarPath,_that.avatarFileId,_that.avatarColorHex,_that.preview,_that.previewSender,_that.previewIsDraft,_that.previewSendState,_that.affiliatedChannelId,_that.affiliatedChannelTitle,_that.affiliatedChannelAvatarPath,_that.affiliatedChannelAvatarFileId,_that.affiliatedChannelAvatarColorHex,_that.lastMessageAt,_that.unreadCount,_that.isMarkedAsUnread,_that.unreadMentionCount,_that.unreadReactionCount,_that.isMuted,_that.isVerified,_that.isPremium,_that.emojiStatusId,_that.isRequest,_that.presence,_that.mainListOrder,_that.isPinned,_that.isSecret,_that.isSecretPending);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int chatId,  String title,  ChatKind kind,  String? username,  String? avatarPath,  int? avatarFileId,  String? avatarColorHex,  String? preview,  String? previewSender,  bool previewIsDraft,  MessageSendState? previewSendState,  int? affiliatedChannelId,  String? affiliatedChannelTitle,  String? affiliatedChannelAvatarPath,  int? affiliatedChannelAvatarFileId,  String? affiliatedChannelAvatarColorHex,  DateTime? lastMessageAt,  int unreadCount,  bool isMarkedAsUnread,  int unreadMentionCount,  int unreadReactionCount,  bool isMuted,  bool isVerified,  bool isPremium,  int? emojiStatusId,  bool isRequest,  ChatPresence presence,  int mainListOrder,  bool isPinned,  bool isSecret,  bool isSecretPending)  $default,) {final _that = this;
switch (_that) {
case _ChatSummary():
return $default(_that.chatId,_that.title,_that.kind,_that.username,_that.avatarPath,_that.avatarFileId,_that.avatarColorHex,_that.preview,_that.previewSender,_that.previewIsDraft,_that.previewSendState,_that.affiliatedChannelId,_that.affiliatedChannelTitle,_that.affiliatedChannelAvatarPath,_that.affiliatedChannelAvatarFileId,_that.affiliatedChannelAvatarColorHex,_that.lastMessageAt,_that.unreadCount,_that.isMarkedAsUnread,_that.unreadMentionCount,_that.unreadReactionCount,_that.isMuted,_that.isVerified,_that.isPremium,_that.emojiStatusId,_that.isRequest,_that.presence,_that.mainListOrder,_that.isPinned,_that.isSecret,_that.isSecretPending);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int chatId,  String title,  ChatKind kind,  String? username,  String? avatarPath,  int? avatarFileId,  String? avatarColorHex,  String? preview,  String? previewSender,  bool previewIsDraft,  MessageSendState? previewSendState,  int? affiliatedChannelId,  String? affiliatedChannelTitle,  String? affiliatedChannelAvatarPath,  int? affiliatedChannelAvatarFileId,  String? affiliatedChannelAvatarColorHex,  DateTime? lastMessageAt,  int unreadCount,  bool isMarkedAsUnread,  int unreadMentionCount,  int unreadReactionCount,  bool isMuted,  bool isVerified,  bool isPremium,  int? emojiStatusId,  bool isRequest,  ChatPresence presence,  int mainListOrder,  bool isPinned,  bool isSecret,  bool isSecretPending)?  $default,) {final _that = this;
switch (_that) {
case _ChatSummary() when $default != null:
return $default(_that.chatId,_that.title,_that.kind,_that.username,_that.avatarPath,_that.avatarFileId,_that.avatarColorHex,_that.preview,_that.previewSender,_that.previewIsDraft,_that.previewSendState,_that.affiliatedChannelId,_that.affiliatedChannelTitle,_that.affiliatedChannelAvatarPath,_that.affiliatedChannelAvatarFileId,_that.affiliatedChannelAvatarColorHex,_that.lastMessageAt,_that.unreadCount,_that.isMarkedAsUnread,_that.unreadMentionCount,_that.unreadReactionCount,_that.isMuted,_that.isVerified,_that.isPremium,_that.emojiStatusId,_that.isRequest,_that.presence,_that.mainListOrder,_that.isPinned,_that.isSecret,_that.isSecretPending);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChatSummary implements ChatSummary {
  const _ChatSummary({required this.chatId, required this.title, required this.kind, this.username, this.avatarPath, this.avatarFileId, this.avatarColorHex, this.preview, this.previewSender, this.previewIsDraft = false, this.previewSendState, this.affiliatedChannelId, this.affiliatedChannelTitle, this.affiliatedChannelAvatarPath, this.affiliatedChannelAvatarFileId, this.affiliatedChannelAvatarColorHex, this.lastMessageAt, this.unreadCount = 0, this.isMarkedAsUnread = false, this.unreadMentionCount = 0, this.unreadReactionCount = 0, this.isMuted = false, this.isVerified = false, this.isPremium = false, this.emojiStatusId, this.isRequest = false, this.presence = ChatPresence.unknown, this.mainListOrder = 0, this.isPinned = false, this.isSecret = false, this.isSecretPending = false});
  factory _ChatSummary.fromJson(Map<String, dynamic> json) => _$ChatSummaryFromJson(json);

@override final  int chatId;
@override final  String title;
@override final  ChatKind kind;
@override final  String? username;
@override final  String? avatarPath;
@override final  int? avatarFileId;
@override final  String? avatarColorHex;
/// The one-line preview under the title, already collapsed by
/// `TdlibMappers.excerptOf`.
@override final  String? preview;
/// The sender's name, prefixed to [preview] in a group ("Ada: on my way").
/// Null in a private chat.
@override final  String? previewSender;
/// Set when [preview] is an unsent draft rather than a received message.
@override@JsonKey() final  bool previewIsDraft;
/// Delivery state of the last message, only when this account sent it.
/// Uses the same state as the bubbles so the row and the conversation agree.
@override final  MessageSendState? previewSendState;
/// The user's personal channel, shown as a badge on the row. Read only
/// from the cached `UserFullInfo`, never fetched per row.
@override final  int? affiliatedChannelId;
@override final  String? affiliatedChannelTitle;
@override final  String? affiliatedChannelAvatarPath;
@override final  int? affiliatedChannelAvatarFileId;
@override final  String? affiliatedChannelAvatarColorHex;
@override final  DateTime? lastMessageAt;
@override@JsonKey() final  int unreadCount;
/// Marked unread by hand. It carries no count, so a row checking only
/// [unreadCount] would show it as read.
@override@JsonKey() final  bool isMarkedAsUnread;
@override@JsonKey() final  int unreadMentionCount;
/// Unseen reactions to this account's own messages. Comes on the update
/// stream like [unreadMentionCount], and feeds the Activity screen.
@override@JsonKey() final  int unreadReactionCount;
@override@JsonKey() final  bool isMuted;
@override@JsonKey() final  bool isVerified;
/// A Telegram Premium account. The row shows the Premium star, never
/// [emojiStatusId], to keep the list easy to scan.
@override@JsonKey() final  bool isPremium;
/// The unexpired custom emoji a Premium account shows in place of the star.
/// Used in the conversation header only.
@override final  int? emojiStatusId;
/// A chat from somebody not in the user's contacts, the kind Telegram
/// shows its "report / add / block" bar on.
@override@JsonKey() final  bool isRequest;
@override@JsonKey() final  ChatPresence presence;
/// TDLib's ordering value for the main chat list. Pinned chats get a very
/// high order, so sorting by this puts them first.
@override@JsonKey() final  int mainListOrder;
/// Pinned in the main chat list, so the row can show a pin.
@override@JsonKey() final  bool isPinned;
/// An end-to-end encrypted chat, drawn with a lock.
@override@JsonKey() final  bool isSecret;
/// True while a secret chat's key exchange is pending. Telegram refuses
/// messages until the other device comes online.
@override@JsonKey() final  bool isSecretPending;

/// Create a copy of ChatSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatSummaryCopyWith<_ChatSummary> get copyWith => __$ChatSummaryCopyWithImpl<_ChatSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatSummary&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.title, title) || other.title == title)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.username, username) || other.username == username)&&(identical(other.avatarPath, avatarPath) || other.avatarPath == avatarPath)&&(identical(other.avatarFileId, avatarFileId) || other.avatarFileId == avatarFileId)&&(identical(other.avatarColorHex, avatarColorHex) || other.avatarColorHex == avatarColorHex)&&(identical(other.preview, preview) || other.preview == preview)&&(identical(other.previewSender, previewSender) || other.previewSender == previewSender)&&(identical(other.previewIsDraft, previewIsDraft) || other.previewIsDraft == previewIsDraft)&&(identical(other.previewSendState, previewSendState) || other.previewSendState == previewSendState)&&(identical(other.affiliatedChannelId, affiliatedChannelId) || other.affiliatedChannelId == affiliatedChannelId)&&(identical(other.affiliatedChannelTitle, affiliatedChannelTitle) || other.affiliatedChannelTitle == affiliatedChannelTitle)&&(identical(other.affiliatedChannelAvatarPath, affiliatedChannelAvatarPath) || other.affiliatedChannelAvatarPath == affiliatedChannelAvatarPath)&&(identical(other.affiliatedChannelAvatarFileId, affiliatedChannelAvatarFileId) || other.affiliatedChannelAvatarFileId == affiliatedChannelAvatarFileId)&&(identical(other.affiliatedChannelAvatarColorHex, affiliatedChannelAvatarColorHex) || other.affiliatedChannelAvatarColorHex == affiliatedChannelAvatarColorHex)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.isMarkedAsUnread, isMarkedAsUnread) || other.isMarkedAsUnread == isMarkedAsUnread)&&(identical(other.unreadMentionCount, unreadMentionCount) || other.unreadMentionCount == unreadMentionCount)&&(identical(other.unreadReactionCount, unreadReactionCount) || other.unreadReactionCount == unreadReactionCount)&&(identical(other.isMuted, isMuted) || other.isMuted == isMuted)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.isPremium, isPremium) || other.isPremium == isPremium)&&(identical(other.emojiStatusId, emojiStatusId) || other.emojiStatusId == emojiStatusId)&&(identical(other.isRequest, isRequest) || other.isRequest == isRequest)&&(identical(other.presence, presence) || other.presence == presence)&&(identical(other.mainListOrder, mainListOrder) || other.mainListOrder == mainListOrder)&&(identical(other.isPinned, isPinned) || other.isPinned == isPinned)&&(identical(other.isSecret, isSecret) || other.isSecret == isSecret)&&(identical(other.isSecretPending, isSecretPending) || other.isSecretPending == isSecretPending));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,chatId,title,kind,username,avatarPath,avatarFileId,avatarColorHex,preview,previewSender,previewIsDraft,previewSendState,affiliatedChannelId,affiliatedChannelTitle,affiliatedChannelAvatarPath,affiliatedChannelAvatarFileId,affiliatedChannelAvatarColorHex,lastMessageAt,unreadCount,isMarkedAsUnread,unreadMentionCount,unreadReactionCount,isMuted,isVerified,isPremium,emojiStatusId,isRequest,presence,mainListOrder,isPinned,isSecret,isSecretPending]);

@override
String toString() {
  return 'ChatSummary(chatId: $chatId, title: $title, kind: $kind, username: $username, avatarPath: $avatarPath, avatarFileId: $avatarFileId, avatarColorHex: $avatarColorHex, preview: $preview, previewSender: $previewSender, previewIsDraft: $previewIsDraft, previewSendState: $previewSendState, affiliatedChannelId: $affiliatedChannelId, affiliatedChannelTitle: $affiliatedChannelTitle, affiliatedChannelAvatarPath: $affiliatedChannelAvatarPath, affiliatedChannelAvatarFileId: $affiliatedChannelAvatarFileId, affiliatedChannelAvatarColorHex: $affiliatedChannelAvatarColorHex, lastMessageAt: $lastMessageAt, unreadCount: $unreadCount, isMarkedAsUnread: $isMarkedAsUnread, unreadMentionCount: $unreadMentionCount, unreadReactionCount: $unreadReactionCount, isMuted: $isMuted, isVerified: $isVerified, isPremium: $isPremium, emojiStatusId: $emojiStatusId, isRequest: $isRequest, presence: $presence, mainListOrder: $mainListOrder, isPinned: $isPinned, isSecret: $isSecret, isSecretPending: $isSecretPending)';
}


}

/// @nodoc
abstract mixin class _$ChatSummaryCopyWith<$Res> implements $ChatSummaryCopyWith<$Res> {
  factory _$ChatSummaryCopyWith(_ChatSummary value, $Res Function(_ChatSummary) _then) = __$ChatSummaryCopyWithImpl;
@override @useResult
$Res call({
 int chatId, String title, ChatKind kind, String? username, String? avatarPath, int? avatarFileId, String? avatarColorHex, String? preview, String? previewSender, bool previewIsDraft, MessageSendState? previewSendState, int? affiliatedChannelId, String? affiliatedChannelTitle, String? affiliatedChannelAvatarPath, int? affiliatedChannelAvatarFileId, String? affiliatedChannelAvatarColorHex, DateTime? lastMessageAt, int unreadCount, bool isMarkedAsUnread, int unreadMentionCount, int unreadReactionCount, bool isMuted, bool isVerified, bool isPremium, int? emojiStatusId, bool isRequest, ChatPresence presence, int mainListOrder, bool isPinned, bool isSecret, bool isSecretPending
});




}
/// @nodoc
class __$ChatSummaryCopyWithImpl<$Res>
    implements _$ChatSummaryCopyWith<$Res> {
  __$ChatSummaryCopyWithImpl(this._self, this._then);

  final _ChatSummary _self;
  final $Res Function(_ChatSummary) _then;

/// Create a copy of ChatSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chatId = null,Object? title = null,Object? kind = null,Object? username = freezed,Object? avatarPath = freezed,Object? avatarFileId = freezed,Object? avatarColorHex = freezed,Object? preview = freezed,Object? previewSender = freezed,Object? previewIsDraft = null,Object? previewSendState = freezed,Object? affiliatedChannelId = freezed,Object? affiliatedChannelTitle = freezed,Object? affiliatedChannelAvatarPath = freezed,Object? affiliatedChannelAvatarFileId = freezed,Object? affiliatedChannelAvatarColorHex = freezed,Object? lastMessageAt = freezed,Object? unreadCount = null,Object? isMarkedAsUnread = null,Object? unreadMentionCount = null,Object? unreadReactionCount = null,Object? isMuted = null,Object? isVerified = null,Object? isPremium = null,Object? emojiStatusId = freezed,Object? isRequest = null,Object? presence = null,Object? mainListOrder = null,Object? isPinned = null,Object? isSecret = null,Object? isSecretPending = null,}) {
  return _then(_ChatSummary(
chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ChatKind,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,avatarPath: freezed == avatarPath ? _self.avatarPath : avatarPath // ignore: cast_nullable_to_non_nullable
as String?,avatarFileId: freezed == avatarFileId ? _self.avatarFileId : avatarFileId // ignore: cast_nullable_to_non_nullable
as int?,avatarColorHex: freezed == avatarColorHex ? _self.avatarColorHex : avatarColorHex // ignore: cast_nullable_to_non_nullable
as String?,preview: freezed == preview ? _self.preview : preview // ignore: cast_nullable_to_non_nullable
as String?,previewSender: freezed == previewSender ? _self.previewSender : previewSender // ignore: cast_nullable_to_non_nullable
as String?,previewIsDraft: null == previewIsDraft ? _self.previewIsDraft : previewIsDraft // ignore: cast_nullable_to_non_nullable
as bool,previewSendState: freezed == previewSendState ? _self.previewSendState : previewSendState // ignore: cast_nullable_to_non_nullable
as MessageSendState?,affiliatedChannelId: freezed == affiliatedChannelId ? _self.affiliatedChannelId : affiliatedChannelId // ignore: cast_nullable_to_non_nullable
as int?,affiliatedChannelTitle: freezed == affiliatedChannelTitle ? _self.affiliatedChannelTitle : affiliatedChannelTitle // ignore: cast_nullable_to_non_nullable
as String?,affiliatedChannelAvatarPath: freezed == affiliatedChannelAvatarPath ? _self.affiliatedChannelAvatarPath : affiliatedChannelAvatarPath // ignore: cast_nullable_to_non_nullable
as String?,affiliatedChannelAvatarFileId: freezed == affiliatedChannelAvatarFileId ? _self.affiliatedChannelAvatarFileId : affiliatedChannelAvatarFileId // ignore: cast_nullable_to_non_nullable
as int?,affiliatedChannelAvatarColorHex: freezed == affiliatedChannelAvatarColorHex ? _self.affiliatedChannelAvatarColorHex : affiliatedChannelAvatarColorHex // ignore: cast_nullable_to_non_nullable
as String?,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,isMarkedAsUnread: null == isMarkedAsUnread ? _self.isMarkedAsUnread : isMarkedAsUnread // ignore: cast_nullable_to_non_nullable
as bool,unreadMentionCount: null == unreadMentionCount ? _self.unreadMentionCount : unreadMentionCount // ignore: cast_nullable_to_non_nullable
as int,unreadReactionCount: null == unreadReactionCount ? _self.unreadReactionCount : unreadReactionCount // ignore: cast_nullable_to_non_nullable
as int,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,isPremium: null == isPremium ? _self.isPremium : isPremium // ignore: cast_nullable_to_non_nullable
as bool,emojiStatusId: freezed == emojiStatusId ? _self.emojiStatusId : emojiStatusId // ignore: cast_nullable_to_non_nullable
as int?,isRequest: null == isRequest ? _self.isRequest : isRequest // ignore: cast_nullable_to_non_nullable
as bool,presence: null == presence ? _self.presence : presence // ignore: cast_nullable_to_non_nullable
as ChatPresence,mainListOrder: null == mainListOrder ? _self.mainListOrder : mainListOrder // ignore: cast_nullable_to_non_nullable
as int,isPinned: null == isPinned ? _self.isPinned : isPinned // ignore: cast_nullable_to_non_nullable
as bool,isSecret: null == isSecret ? _self.isSecret : isSecret // ignore: cast_nullable_to_non_nullable
as bool,isSecretPending: null == isSecretPending ? _self.isSecretPending : isSecretPending // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
