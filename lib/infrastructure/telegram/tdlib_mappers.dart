import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/infrastructure/database/database.dart';

class TdlibMappers {
  /// Map TDLib Chat model to Drift ChannelsCompanion
  static ChannelsCompanion mapChatToCompanion(
    td.Chat chat, 
    int accountDbId, {
    String? username,
    String? description,
    bool isVerified = false,
    int subscriberCount = 0,
  }) {
    return ChannelsCompanion.insert(
      accountId: accountDbId,
      chatId: chat.id,
      title: chat.title,
      username: Value(username),
      description: Value(description),
      avatarUrl: Value(chat.photo != null
          ? (chat.photo!.small.local.path.isNotEmpty == true
              ? chat.photo!.small.local.path
              : chat.photo!.small.remote.id)
          : null),
      avatarColor: Value(_generateRandomHexColor(chat.id)),
      subscriberCount: Value(subscriberCount),
      isVerified: Value(isVerified),
      lastReadInboxMessageId: Value(chat.lastReadInboxMessageId),
      isFavorite: const Value(false),
      isMuted: const Value(false),
      isHidden: const Value(false),
      lastPostAt: Value(DateTime.now()), // default placeholder
    );
  }

  /// Map TDLib Message to Drift PostsCompanion
  static PostsCompanion mapMessageToCompanion(
    td.Message message, 
    int accountDbId, 
    int channelDbId
  ) {
    String? bodyText;
    String? linkPreviewUrl;
    String? linkPreviewTitle;
    String? linkPreviewDescription;
    String? linkPreviewImageUrl;

    final content = message.content;
    if (content is td.MessageText) {
      bodyText = content.text.text;
      if (content.linkPreview != null) {
        linkPreviewUrl = content.linkPreview!.url;
        linkPreviewTitle = content.linkPreview!.title;
        linkPreviewDescription = content.linkPreview!.description.text;
        
        final previewType = content.linkPreview!.type;
        if (previewType is td.LinkPreviewTypePhoto) {
          linkPreviewImageUrl = previewType.photo.sizes.first.photo.local.path;
        } else if (previewType is td.LinkPreviewTypeArticle) {
          linkPreviewImageUrl = previewType.photo?.sizes.first.photo.local.path;
        }
      }
    } else if (content is td.MessagePhoto) {
      bodyText = content.caption.text;
    } else if (content is td.MessageVideo) {
      bodyText = content.caption.text;
    } else if (content is td.MessageAnimation) {
      bodyText = content.caption.text;
    } else if (content is td.MessageDocument) {
      bodyText = content.caption.text;
    }

    // Map reactions
    final Map<String, int> reactionsMap = {};
    for (final reaction in message.interactionInfo?.reactions?.reactions ?? <td.MessageReaction>[]) {
      final type = reaction.type;
      if (type is td.ReactionTypeEmoji) {
        reactionsMap[type.emoji] = reaction.totalCount;
      }
    }

    return PostsCompanion.insert(
      accountId: accountDbId,
      channelId: channelDbId,
      messageId: message.id,
      body: Value(bodyText),
      publishedAt: DateTime.fromMillisecondsSinceEpoch(message.date * 1000),
      viewCount: Value(message.interactionInfo?.viewCount ?? 0),
      replyCount: Value(message.interactionInfo?.replyInfo?.replyCount ?? 0),
      forwardCount: Value(message.interactionInfo?.forwardCount ?? 0),
      reactionsJson: Value(jsonEncode(reactionsMap)),
      isBookmarked: const Value(false),
      isRead: Value(message.isOutgoing == false ? false : true),
      isDeleted: const Value(false),
      linkPreviewUrl: Value(linkPreviewUrl),
      linkPreviewTitle: Value(linkPreviewTitle),
      linkPreviewDescription: Value(linkPreviewDescription),
      linkPreviewImageUrl: Value(linkPreviewImageUrl),
      forwardedFromTitle: Value(message.forwardInfo?.origin is td.MessageOriginChat
          ? (message.forwardInfo!.origin as td.MessageOriginChat).senderChatId.toString()
          : message.forwardInfo?.origin is td.MessageOriginChannel
              ? (message.forwardInfo!.origin as td.MessageOriginChannel).chatId.toString()
              : null),
    );
  }

  /// Extracts MediaItemEntry companions from a TDLib Message
  static List<MediaItemsCompanion> extractMediaCompanions(
    td.Message message, 
    int postDbId
  ) {
    final list = <MediaItemsCompanion>[];
    final content = message.content;

    if (content is td.MessagePhoto) {
      final photo = content.photo;
      // Get the highest resolution size
      final bestSize = photo.sizes.last;
      list.add(MediaItemsCompanion.insert(
        postId: postDbId,
        type: MediaType.photo.name,
        url: Value(bestSize.photo.remote.id),
        thumbnailUrl: Value(photo.sizes.first.photo.local.path.isNotEmpty == true 
            ? photo.sizes.first.photo.local.path 
            : photo.sizes.first.photo.remote.id),
        width: Value(bestSize.width),
        height: Value(bestSize.height),
        localPath: Value(bestSize.photo.local.path.isNotEmpty == true 
            ? bestSize.photo.local.path 
            : bestSize.photo.remote.id),
      ));
    } else if (content is td.MessageVideo) {
      final video = content.video;
      list.add(MediaItemsCompanion.insert(
        postId: postDbId,
        type: MediaType.video.name,
        url: Value(video.video.remote.id),
        thumbnailUrl: Value(video.thumbnail != null
            ? (video.thumbnail!.file.local.path.isNotEmpty == true
                ? video.thumbnail!.file.local.path
                : video.thumbnail!.file.remote.id)
            : null),
        width: Value(video.width),
        height: Value(video.height),
        duration: Value(video.duration),
        fileSize: Value(video.video.expectedSize),
        fileName: Value(video.fileName),
        mimeType: Value(video.mimeType),
        localPath: Value(video.video.local.path.isNotEmpty == true 
            ? video.video.local.path 
            : video.video.remote.id),
      ));
    } else if (content is td.MessageAnimation) {
      final anim = content.animation;
      list.add(MediaItemsCompanion.insert(
        postId: postDbId,
        type: MediaType.gif.name,
        url: Value(anim.animation.remote.id),
        thumbnailUrl: Value(anim.thumbnail != null
            ? (anim.thumbnail!.file.local.path.isNotEmpty == true
                ? anim.thumbnail!.file.local.path
                : anim.thumbnail!.file.remote.id)
            : null),
        width: Value(anim.width),
        height: Value(anim.height),
        duration: Value(anim.duration),
        localPath: Value(anim.animation.local.path.isNotEmpty == true 
            ? anim.animation.local.path 
            : anim.animation.remote.id),
      ));
    }

    return list;
  }

  static String _generateRandomHexColor(int seedId) {
    final colors = [
      '#FF6154', // red
      '#027DFD', // blue
      '#F7931A', // orange
      '#FF3366', // pink
      '#1DA1F2', // lightblue
      '#00BA7C', // green
      '#794BC4', // purple
    ];
    return colors[seedId.abs() % colors.length];
  }
}
