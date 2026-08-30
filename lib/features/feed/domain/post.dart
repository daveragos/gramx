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

    /// The person who wrote this, when it was a person rather than a channel.
    ///
    /// Set for comments, which are messages in a channel's discussion group by
    /// whoever left them. Null for a channel's own posts, where the channel is
    /// the author and [channelId] already says who that is. It is what lets a
    /// comment's avatar open a profile instead of the channel the thread
    /// hangs off — see `PostSender`.
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

    /// The original post's id in its own channel, when Telegram tells us.
    /// Lets a forward link to the post itself rather than just the channel.
    int? forwardedFromMessageId,
    String? replyToText,

    /// Whether [replyToText] is a passage the writer *selected* out of the
    /// message being answered, rather than that message's opening words.
    ///
    /// differently from a reply to a whole post: the span becomes its own
    /// block above the reply on a thread connector, while a whole-post reply
    /// is embedded in a quote card. So the two cannot share one field. TDLib
    /// fills `replyTo.quote` only in the first case, and the mapper folds it
    /// into [replyToText] alongside two other sources — this is what survives
    /// that fold. See `ReplyPresentation`.
    @Default(false) bool replyToIsQuote,
    String? replyToAuthorTitle,
    int? replyToMessageId,

    /// The chat the replied-to message lives in, when it isn't this one.
    ///
    /// Telegram lets a message reply across chats. Assuming the reply target
    /// shares [chatId] sends the reader to a message id in the wrong chat,
    /// which reports itself as "post not found" however reachable it is.
    int? replyToChatId,
    String? replyToThumbnailUrl,
    int? replyToThumbnailFileId,
    @Default(false) bool hasDiscussionGroup,
    String? authorSignature,

    /// Set when Telegram sent content this app cannot draw — the TDLib type
    /// name, so the card can offer to open it in Telegram instead of showing a
    /// dead sentence.
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
