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

    /// The user who wrote this, for comments in a discussion group. Null for a
    /// channel's own posts. Lets a comment's avatar open a profile; see
    /// `PostSender`.
    int? senderUserId,
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
    @Default({}) Set<String> chosenReactions,
    @Default(false) bool isBookmarked,
    @Default(false) bool isRead,
    String? linkPreviewUrl,
    String? linkPreviewTitle,
    String? linkPreviewDescription,
    String? linkPreviewImageUrl,
    int? linkPreviewFileId,
    String? forwardedFromTitle,
    String? forwardedFromUsername,
    String? forwardedFromChatId,

    /// The original post's id in its channel, when Telegram provides it, so a
    /// forward can link to the post rather than the channel.
    int? forwardedFromMessageId,
    String? replyToText,

    /// Whether [replyToText] is a span quoted from the replied-to message
    /// rather than its opening words. TDLib sets `replyTo.quote` only for a
    /// quote, and the two are drawn differently. See `ReplyPresentation`.
    @Default(false) bool replyToIsQuote,
    String? replyToAuthorTitle,
    int? replyToMessageId,

    /// The chat of the replied-to message, when it isn't this one. Telegram
    /// allows replies across chats.
    int? replyToChatId,
    String? replyToThumbnailUrl,
    int? replyToThumbnailFileId,
    @Default(false) bool hasDiscussionGroup,
    String? authorSignature,

    /// The TDLib type name of content this app can't draw, so the card can
    /// offer to open it in Telegram.
    String? unsupportedKind,
    @Default([]) List<TextEntity> entities,
    @JsonKey(fromJson: _pollFromJson, toJson: _pollToJson) Poll? poll,
  }) = _Post;

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);
}

Poll? _pollFromJson(dynamic json) =>
    json == null ? null : Poll.fromJson(json as Map<String, dynamic>);
Map<String, dynamic>? _pollToJson(Poll? poll) =>
    poll == null ? null : (poll as dynamic).toJson() as Map<String, dynamic>;
