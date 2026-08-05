// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'media_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MediaItem {

 String get id; MediaType get type; String? get url; String? get thumbnailUrl; int get width; int get height; int get duration; int get fileSize; String? get fileName; String? get mimeType; String? get localPath;/// Base64-encoded JPEG minithumbnail from Telegram (tiny ~100 byte preview).
 String? get minithumbnail;/// TDLib file ID for the main media file (for reactive download tracking).
 int? get fileId;/// TDLib file ID for the thumbnail file.
 int? get thumbnailFileId;
/// Create a copy of MediaItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaItemCopyWith<MediaItem> get copyWith => _$MediaItemCopyWithImpl<MediaItem>(this as MediaItem, _$identity);

  /// Serializes this MediaItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaItem&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.url, url) || other.url == url)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.localPath, localPath) || other.localPath == localPath)&&(identical(other.minithumbnail, minithumbnail) || other.minithumbnail == minithumbnail)&&(identical(other.fileId, fileId) || other.fileId == fileId)&&(identical(other.thumbnailFileId, thumbnailFileId) || other.thumbnailFileId == thumbnailFileId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,url,thumbnailUrl,width,height,duration,fileSize,fileName,mimeType,localPath,minithumbnail,fileId,thumbnailFileId);

@override
String toString() {
  return 'MediaItem(id: $id, type: $type, url: $url, thumbnailUrl: $thumbnailUrl, width: $width, height: $height, duration: $duration, fileSize: $fileSize, fileName: $fileName, mimeType: $mimeType, localPath: $localPath, minithumbnail: $minithumbnail, fileId: $fileId, thumbnailFileId: $thumbnailFileId)';
}


}

/// @nodoc
abstract mixin class $MediaItemCopyWith<$Res>  {
  factory $MediaItemCopyWith(MediaItem value, $Res Function(MediaItem) _then) = _$MediaItemCopyWithImpl;
@useResult
$Res call({
 String id, MediaType type, String? url, String? thumbnailUrl, int width, int height, int duration, int fileSize, String? fileName, String? mimeType, String? localPath, String? minithumbnail, int? fileId, int? thumbnailFileId
});




}
/// @nodoc
class _$MediaItemCopyWithImpl<$Res>
    implements $MediaItemCopyWith<$Res> {
  _$MediaItemCopyWithImpl(this._self, this._then);

  final MediaItem _self;
  final $Res Function(MediaItem) _then;

/// Create a copy of MediaItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? url = freezed,Object? thumbnailUrl = freezed,Object? width = null,Object? height = null,Object? duration = null,Object? fileSize = null,Object? fileName = freezed,Object? mimeType = freezed,Object? localPath = freezed,Object? minithumbnail = freezed,Object? fileId = freezed,Object? thumbnailFileId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as MediaType,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,fileName: freezed == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String?,mimeType: freezed == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String?,localPath: freezed == localPath ? _self.localPath : localPath // ignore: cast_nullable_to_non_nullable
as String?,minithumbnail: freezed == minithumbnail ? _self.minithumbnail : minithumbnail // ignore: cast_nullable_to_non_nullable
as String?,fileId: freezed == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as int?,thumbnailFileId: freezed == thumbnailFileId ? _self.thumbnailFileId : thumbnailFileId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [MediaItem].
extension MediaItemPatterns on MediaItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MediaItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MediaItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MediaItem value)  $default,){
final _that = this;
switch (_that) {
case _MediaItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MediaItem value)?  $default,){
final _that = this;
switch (_that) {
case _MediaItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  MediaType type,  String? url,  String? thumbnailUrl,  int width,  int height,  int duration,  int fileSize,  String? fileName,  String? mimeType,  String? localPath,  String? minithumbnail,  int? fileId,  int? thumbnailFileId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MediaItem() when $default != null:
return $default(_that.id,_that.type,_that.url,_that.thumbnailUrl,_that.width,_that.height,_that.duration,_that.fileSize,_that.fileName,_that.mimeType,_that.localPath,_that.minithumbnail,_that.fileId,_that.thumbnailFileId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  MediaType type,  String? url,  String? thumbnailUrl,  int width,  int height,  int duration,  int fileSize,  String? fileName,  String? mimeType,  String? localPath,  String? minithumbnail,  int? fileId,  int? thumbnailFileId)  $default,) {final _that = this;
switch (_that) {
case _MediaItem():
return $default(_that.id,_that.type,_that.url,_that.thumbnailUrl,_that.width,_that.height,_that.duration,_that.fileSize,_that.fileName,_that.mimeType,_that.localPath,_that.minithumbnail,_that.fileId,_that.thumbnailFileId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  MediaType type,  String? url,  String? thumbnailUrl,  int width,  int height,  int duration,  int fileSize,  String? fileName,  String? mimeType,  String? localPath,  String? minithumbnail,  int? fileId,  int? thumbnailFileId)?  $default,) {final _that = this;
switch (_that) {
case _MediaItem() when $default != null:
return $default(_that.id,_that.type,_that.url,_that.thumbnailUrl,_that.width,_that.height,_that.duration,_that.fileSize,_that.fileName,_that.mimeType,_that.localPath,_that.minithumbnail,_that.fileId,_that.thumbnailFileId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MediaItem implements MediaItem {
  const _MediaItem({required this.id, required this.type, this.url, this.thumbnailUrl, this.width = 0, this.height = 0, this.duration = 0, this.fileSize = 0, this.fileName, this.mimeType, this.localPath, this.minithumbnail, this.fileId, this.thumbnailFileId});
  factory _MediaItem.fromJson(Map<String, dynamic> json) => _$MediaItemFromJson(json);

@override final  String id;
@override final  MediaType type;
@override final  String? url;
@override final  String? thumbnailUrl;
@override@JsonKey() final  int width;
@override@JsonKey() final  int height;
@override@JsonKey() final  int duration;
@override@JsonKey() final  int fileSize;
@override final  String? fileName;
@override final  String? mimeType;
@override final  String? localPath;
/// Base64-encoded JPEG minithumbnail from Telegram (tiny ~100 byte preview).
@override final  String? minithumbnail;
/// TDLib file ID for the main media file (for reactive download tracking).
@override final  int? fileId;
/// TDLib file ID for the thumbnail file.
@override final  int? thumbnailFileId;

/// Create a copy of MediaItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MediaItemCopyWith<_MediaItem> get copyWith => __$MediaItemCopyWithImpl<_MediaItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MediaItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MediaItem&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.url, url) || other.url == url)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.localPath, localPath) || other.localPath == localPath)&&(identical(other.minithumbnail, minithumbnail) || other.minithumbnail == minithumbnail)&&(identical(other.fileId, fileId) || other.fileId == fileId)&&(identical(other.thumbnailFileId, thumbnailFileId) || other.thumbnailFileId == thumbnailFileId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,url,thumbnailUrl,width,height,duration,fileSize,fileName,mimeType,localPath,minithumbnail,fileId,thumbnailFileId);

@override
String toString() {
  return 'MediaItem(id: $id, type: $type, url: $url, thumbnailUrl: $thumbnailUrl, width: $width, height: $height, duration: $duration, fileSize: $fileSize, fileName: $fileName, mimeType: $mimeType, localPath: $localPath, minithumbnail: $minithumbnail, fileId: $fileId, thumbnailFileId: $thumbnailFileId)';
}


}

/// @nodoc
abstract mixin class _$MediaItemCopyWith<$Res> implements $MediaItemCopyWith<$Res> {
  factory _$MediaItemCopyWith(_MediaItem value, $Res Function(_MediaItem) _then) = __$MediaItemCopyWithImpl;
@override @useResult
$Res call({
 String id, MediaType type, String? url, String? thumbnailUrl, int width, int height, int duration, int fileSize, String? fileName, String? mimeType, String? localPath, String? minithumbnail, int? fileId, int? thumbnailFileId
});




}
/// @nodoc
class __$MediaItemCopyWithImpl<$Res>
    implements _$MediaItemCopyWith<$Res> {
  __$MediaItemCopyWithImpl(this._self, this._then);

  final _MediaItem _self;
  final $Res Function(_MediaItem) _then;

/// Create a copy of MediaItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? url = freezed,Object? thumbnailUrl = freezed,Object? width = null,Object? height = null,Object? duration = null,Object? fileSize = null,Object? fileName = freezed,Object? mimeType = freezed,Object? localPath = freezed,Object? minithumbnail = freezed,Object? fileId = freezed,Object? thumbnailFileId = freezed,}) {
  return _then(_MediaItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as MediaType,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,fileName: freezed == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String?,mimeType: freezed == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String?,localPath: freezed == localPath ? _self.localPath : localPath // ignore: cast_nullable_to_non_nullable
as String?,minithumbnail: freezed == minithumbnail ? _self.minithumbnail : minithumbnail // ignore: cast_nullable_to_non_nullable
as String?,fileId: freezed == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as int?,thumbnailFileId: freezed == thumbnailFileId ? _self.thumbnailFileId : thumbnailFileId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
