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
    String? textEntitiesJson;
    String? pollJson;

    final content = message.content;
    if (content is td.MessageText) {
      bodyText = content.text.text;
      textEntitiesJson = serializeEntities(content.text.entities);
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
      textEntitiesJson = serializeEntities(content.caption.entities);
    } else if (content is td.MessageVideo) {
      bodyText = content.caption.text;
      textEntitiesJson = serializeEntities(content.caption.entities);
    } else if (content is td.MessageAnimation) {
      bodyText = content.caption.text;
      textEntitiesJson = serializeEntities(content.caption.entities);
    } else if (content is td.MessageDocument) {
      bodyText = content.caption.text;
      textEntitiesJson = serializeEntities(content.caption.entities);
    } else if (content is td.MessagePoll) {
      bodyText = content.poll.question.text;
      pollJson = serializePoll(content.poll);
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
      textEntitiesJson: Value(textEntitiesJson),
      pollJson: Value(pollJson),
    );
  }

  static String? serializeEntities(List<td.TextEntity>? entities) {
    if (entities == null || entities.isEmpty) return null;
    try {
      final list = entities.map((entity) {
        final type = entity.type;
        String typeStr = 'unknown';
        String? url;
        String? customEmojiId;

        if (type is td.TextEntityTypeBold) {
          typeStr = 'bold';
        } else if (type is td.TextEntityTypeItalic) {
          typeStr = 'italic';
        } else if (type is td.TextEntityTypeUnderline) {
          typeStr = 'underline';
        } else if (type is td.TextEntityTypeStrikethrough) {
          typeStr = 'strikethrough';
        } else if (type is td.TextEntityTypeCode) {
          typeStr = 'code';
        } else if (type is td.TextEntityTypePre) {
          typeStr = 'codeBlock';
        } else if (type is td.TextEntityTypePreCode) {
          typeStr = 'codeBlock';
        } else if (type is td.TextEntityTypeUrl) {
          typeStr = 'url';
        } else if (type is td.TextEntityTypeTextUrl) {
          typeStr = 'textUrl';
          url = type.url;
        } else if (type is td.TextEntityTypeMention) {
          typeStr = 'mention';
        } else if (type is td.TextEntityTypeHashtag) {
          typeStr = 'hashtag';
        } else if (type is td.TextEntityTypeSpoiler) {
          typeStr = 'spoiler';
        } else if (type is td.TextEntityTypeCustomEmoji) {
          typeStr = 'customEmoji';
          customEmojiId = type.customEmojiId.toString();
        }

        return {
          'offset': entity.offset,
          'length': entity.length,
          'type': typeStr,
          if (url != null) 'url': url,
          if (customEmojiId != null) 'customEmojiId': customEmojiId,
        };
      }).toList();
      return jsonEncode(list);
    } catch (e) {
      return null;
    }
  }

  static String? serializePoll(td.Poll? poll) {
    if (poll == null) return null;
    try {
      final isQuiz = poll.type is td.PollTypeQuiz;
      final int? correctOptionId = isQuiz ? (poll.type as td.PollTypeQuiz).correctOptionId : null;

      final options = poll.options.asMap().entries.map((entry) {
        final idx = entry.key;
        final opt = entry.value;
        final isCorrect = isQuiz && (idx == correctOptionId);
        return {
          'text': opt.text,
          'voterCount': opt.voterCount,
          'votePercentage': opt.votePercentage.toDouble(),
          'isChosen': opt.isChosen,
          'isCorrect': isCorrect,
        };
      }).toList();

      final map = {
        'id': poll.id.toString(),
        'question': poll.question.text,
        'options': options,
        'totalVoterCount': poll.totalVoterCount,
        'isAnonymous': poll.isAnonymous,
        'isClosed': poll.isClosed,
        'isQuiz': isQuiz,
        if (correctOptionId != null) 'correctOptionId': correctOptionId,
        'chosenOptionIds': poll.options
            .asMap()
            .entries
            .where((entry) => entry.value.isChosen)
            .map((entry) => entry.key)
            .toList(),
      };
      return jsonEncode(map);
    } catch (e) {
      return null;
    }
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
