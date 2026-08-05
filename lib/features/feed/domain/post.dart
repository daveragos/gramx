import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';
import 'package:gramx/features/feed/domain/poll.dart';

part 'post.freezed.dart';
part 'post.g.dart';

@freezed
abstract class Post with _$Post {
  const factory Post({
    required String id,
    required int chatId,
    required String channelId,
    required int messageId,
    @Default(0) int mediaAlbumId,
    required String channelTitle,
    String? channelUsername,
    String? channelAvatarUrl,
    int? channelAvatarFileId,
    String? channelAvatarColor,
    @Default(false) bool isChannelVerified,
    String? text,
    @Default([]) List<MediaItem> media,
    required DateTime publishedAt,
    @Default(0) int viewCount,
    @Default(0) int replyCount,
    @Default(0) int forwardCount,
    @Default({}) Map<String, int> reactions,
    @Default(false) bool isBookmarked,
    @Default(false) bool isRead,
    String? linkPreviewUrl,
    String? linkPreviewTitle,
    String? linkPreviewDescription,
    String? linkPreviewImageUrl,
    String? forwardedFromTitle,
    String? forwardedFromUsername,
    String? forwardedFromChatId,
    @Default([]) List<TextEntity> entities,
    Poll? poll,
  }) = _Post;

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);
}
