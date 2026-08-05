import 'dart:convert';
import 'dart:math' as math;
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';
import 'package:gramx/features/feed/domain/poll.dart';
import 'package:gramx/features/channels/domain/channel.dart';

class TdlibMappers {
  static Channel mapChatToChannel(td.Chat chat, {td.Supergroup? supergroup, td.SupergroupFullInfo? fullInfo}) {
    return Channel(
      id: chat.id.toString(),
      chatId: chat.id,
      title: chat.title,
      username: supergroup?.usernames?.activeUsernames.isNotEmpty == true ? supergroup!.usernames!.activeUsernames.first : null,
      description: fullInfo?.description,
      avatarUrl: chat.photo != null
          ? (chat.photo!.small.local.path.isNotEmpty == true
              ? chat.photo!.small.local.path
              : (chat.photo!.small.remote.id.isNotEmpty
                  ? chat.photo!.small.remote.id
                  : chat.photo!.small.id.toString()))
          : null,
      avatarColor: _generateRandomHexColor(chat.id),
      subscriberCount: supergroup?.memberCount ?? 0,
      isVerified: supergroup?.isVerified ?? false,
            isFavorite: false,
      isMuted: false,
      isHidden: false,
    );
  }

  static Post mapMessageToPost(td.Message message, td.Chat chat, {bool isBookmarked = false}) {
    String? bodyText;
    String? linkPreviewUrl;
    String? linkPreviewTitle;
    String? linkPreviewDescription;
    String? linkPreviewImageUrl;
    List<TextEntity> textEntities = [];
    Poll? pollObj;

    final content = message.content;
    if (content is td.MessageText) {
      bodyText = content.text.text;
      final parsed = _parseEntities(content.text.entities);
      if (parsed != null) textEntities = parsed;
      if (content.linkPreview != null) {
        final lp = content.linkPreview!;
        linkPreviewUrl = lp.url.isNotEmpty ? lp.url : null;
        linkPreviewTitle = lp.title.isNotEmpty ? lp.title : (lp.displayUrl.isNotEmpty ? lp.displayUrl : null);
        linkPreviewDescription = lp.description.text.isNotEmpty ? lp.description.text : null;
        
        final previewType = lp.type;
        td.Photo? photo;
        td.Thumbnail? thumbnail;

        if (previewType is td.LinkPreviewTypePhoto) {
          photo = previewType.photo;
        } else if (previewType is td.LinkPreviewTypeArticle) {
          photo = previewType.photo;
        } else if (previewType is td.LinkPreviewTypeApp) {
          photo = previewType.photo;
        } else if (previewType is td.LinkPreviewTypeVideo) {
          thumbnail = previewType.video.thumbnail;
        } else if (previewType is td.LinkPreviewTypeAnimation) {
          thumbnail = previewType.animation.thumbnail;
        } else if (previewType is td.LinkPreviewTypeDocument) {
          thumbnail = previewType.document.thumbnail;
        }

        if (photo != null && photo.sizes.isNotEmpty) {
          final best = photo.sizes.last;
          linkPreviewImageUrl = best.photo.local.path.isNotEmpty == true
              ? best.photo.local.path
              : (best.photo.remote.id.isNotEmpty ? best.photo.remote.id : best.photo.id.toString());
        } else if (thumbnail != null) {
          linkPreviewImageUrl = thumbnail.file.local.path.isNotEmpty == true
              ? thumbnail.file.local.path
              : (thumbnail.file.remote.id.isNotEmpty ? thumbnail.file.remote.id : thumbnail.file.id.toString());
        }
      }
    } else if (content is td.MessagePhoto) {
      bodyText = content.caption.text;
      final parsed = _parseEntities(content.caption.entities);
      if (parsed != null) textEntities = parsed;
    } else if (content is td.MessageVideo) {
      bodyText = content.caption.text;
      final parsed = _parseEntities(content.caption.entities);
      if (parsed != null) textEntities = parsed;
    } else if (content is td.MessageAnimation) {
      bodyText = content.caption.text;
      final parsed = _parseEntities(content.caption.entities);
      if (parsed != null) textEntities = parsed;
    } else if (content is td.MessageDocument) {
      bodyText = content.caption.text;
      final parsed = _parseEntities(content.caption.entities);
      if (parsed != null) textEntities = parsed;
    } else if (content is td.MessagePoll) {
      bodyText = content.poll.question.text;
      pollObj = _parsePoll(content.poll);
    }

    final Map<String, int> reactionsMap = {};
    for (final reaction in message.interactionInfo?.reactions?.reactions ?? <td.MessageReaction>[]) {
      final type = reaction.type;
      if (type is td.ReactionTypeEmoji) {
        reactionsMap[type.emoji] = reaction.totalCount;
      }
    }

    String? forwardedFromTitle;
    String? forwardedFromUsername;
    String? forwardedFromChatId;
    final fwdOrigin = message.forwardInfo?.origin;
    if (fwdOrigin is td.MessageOriginChannel) {
      forwardedFromChatId = fwdOrigin.chatId.toString();
      forwardedFromTitle = fwdOrigin.authorSignature.isNotEmpty ? fwdOrigin.authorSignature : null;
    } else if (fwdOrigin is td.MessageOriginChat) {
      forwardedFromChatId = fwdOrigin.senderChatId.toString();
    } else if (fwdOrigin is td.MessageOriginUser) {
      // User ID could be used to resolve user, but not channel ID.
      // We will skip for now or resolve async.
    } else if (fwdOrigin is td.MessageOriginHiddenUser) {
      forwardedFromTitle = fwdOrigin.senderName;
    }

    return Post(
      id: '${chat.id}_${message.id}',
      chatId: chat.id,
      channelId: chat.id.toString(),
      messageId: message.id,
      mediaAlbumId: message.mediaAlbumId.toInt(),
      channelTitle: chat.title,
      channelAvatarUrl: chat.photo != null
          ? (chat.photo!.small.local.path.isNotEmpty == true
              ? chat.photo!.small.local.path
              : (chat.photo!.small.remote.id.isNotEmpty
                  ? chat.photo!.small.remote.id
                  : chat.photo!.small.id.toString()))
          : null,
      channelAvatarColor: _generateRandomHexColor(chat.id),
      text: bodyText,
      media: extractMediaItems(message),
      publishedAt: DateTime.fromMillisecondsSinceEpoch(message.date * 1000),
      viewCount: message.interactionInfo?.viewCount ?? 0,
      replyCount: message.interactionInfo?.replyInfo?.replyCount ?? 0,
      forwardCount: message.interactionInfo?.forwardCount ?? 0,
      reactions: reactionsMap,
      isBookmarked: isBookmarked,
      isRead: message.isOutgoing ? true : false,
      linkPreviewUrl: linkPreviewUrl,
      linkPreviewTitle: linkPreviewTitle,
      linkPreviewDescription: linkPreviewDescription,
      linkPreviewImageUrl: linkPreviewImageUrl,
      forwardedFromTitle: forwardedFromTitle,
      forwardedFromUsername: forwardedFromUsername,
      forwardedFromChatId: forwardedFromChatId,
      entities: textEntities,
      poll: pollObj,
    );
  }

  static List<MediaItem> extractMediaItems(td.Message message) {
    final list = <MediaItem>[];
    final content = message.content;

    if (content is td.MessagePhoto) {
      final photo = content.photo;
      final bestSize = photo.sizes.last;
      final bestPhotoPath = bestSize.photo.local.path.isNotEmpty == true 
          ? bestSize.photo.local.path 
          : (bestSize.photo.remote.id.isNotEmpty ? bestSize.photo.remote.id : bestSize.photo.id.toString());
      final thumbPath = photo.sizes.first.photo.local.path.isNotEmpty == true 
          ? photo.sizes.first.photo.local.path 
          : (photo.sizes.first.photo.remote.id.isNotEmpty ? photo.sizes.first.photo.remote.id : photo.sizes.first.photo.id.toString());

      list.add(MediaItem(
        id: bestPhotoPath,
        type: MediaType.photo,
        url: bestPhotoPath,
        thumbnailUrl: thumbPath,
        width: bestSize.width,
        height: bestSize.height,
      ));
    } else if (content is td.MessageVideo) {
      final video = content.video;
      final videoPath = video.video.local.path.isNotEmpty == true 
          ? video.video.local.path 
          : (video.video.remote.id.isNotEmpty ? video.video.remote.id : video.video.id.toString());
      final thumbPath = video.thumbnail != null
          ? (video.thumbnail!.file.local.path.isNotEmpty == true
              ? video.thumbnail!.file.local.path
              : (video.thumbnail!.file.remote.id.isNotEmpty ? video.thumbnail!.file.remote.id : video.thumbnail!.file.id.toString()))
          : null;

      list.add(MediaItem(
        id: videoPath,
        type: MediaType.video,
        url: videoPath,
        thumbnailUrl: thumbPath,
        width: video.width,
        height: video.height,
        duration: video.duration,
        fileSize: video.video.expectedSize,
        fileName: video.fileName,
        mimeType: video.mimeType,
      ));
    } else if (content is td.MessageAnimation) {
      final anim = content.animation;
      final animPath = anim.animation.local.path.isNotEmpty == true 
          ? anim.animation.local.path 
          : (anim.animation.remote.id.isNotEmpty ? anim.animation.remote.id : anim.animation.id.toString());
      final thumbPath = anim.thumbnail != null
          ? (anim.thumbnail!.file.local.path.isNotEmpty == true
              ? anim.thumbnail!.file.local.path
              : (anim.thumbnail!.file.remote.id.isNotEmpty ? anim.thumbnail!.file.remote.id : anim.thumbnail!.file.id.toString()))
          : null;

      list.add(MediaItem(
        id: animPath,
        type: MediaType.gif,
        url: animPath,
        thumbnailUrl: thumbPath,
        width: anim.width,
        height: anim.height,
        duration: anim.duration,
      ));
    } else if (content is td.MessageDocument) {
      final doc = content.document;
      final docPath = doc.document.local.path.isNotEmpty == true 
          ? doc.document.local.path 
          : (doc.document.remote.id.isNotEmpty ? doc.document.remote.id : doc.document.id.toString());
      final thumbPath = doc.thumbnail != null
          ? (doc.thumbnail!.file.local.path.isNotEmpty == true
              ? doc.thumbnail!.file.local.path
              : (doc.thumbnail!.file.remote.id.isNotEmpty ? doc.thumbnail!.file.remote.id : doc.thumbnail!.file.id.toString()))
          : null;

      list.add(MediaItem(
        id: docPath,
        type: MediaType.document,
        url: docPath,
        thumbnailUrl: thumbPath,
        fileSize: doc.document.expectedSize,
        fileName: doc.fileName,
        mimeType: doc.mimeType,
      ));
    }

    return list;
  }

  static List<Post> mergeAlbumMessages(List<td.Message> messages, td.Chat chat, {Set<String> bookmarkedKeys = const {}}) {
    final grouped = <int, List<td.Message>>{};
    final result = <Post>[];

    for (final m in messages) {
      final albumId = m.mediaAlbumId.toInt();
      if (albumId == 0) {
        result.add(mapMessageToPost(m, chat, isBookmarked: bookmarkedKeys.contains('${chat.id}_${m.id}')));
      } else {
        grouped.putIfAbsent(albumId, () => []).add(m);
      }
    }

    for (final group in grouped.values) {
      group.sort((a, b) => a.id.compareTo(b.id));
      final anchor = group.first;
      
      final post = mapMessageToPost(anchor, chat, isBookmarked: bookmarkedKeys.contains('${chat.id}_${anchor.id}'));
      
      final allMedia = <MediaItem>[];
      int maxViews = 0;
      String? caption;
      List<TextEntity> captionEntities = [];
      
      for (final m in group) {
        allMedia.addAll(extractMediaItems(m));
        if (m.interactionInfo?.viewCount != null) {
          maxViews = math.max(maxViews, m.interactionInfo!.viewCount);
        }
        if (caption == null) {
          if (m.content is td.MessagePhoto && (m.content as td.MessagePhoto).caption.text.isNotEmpty) {
            caption = (m.content as td.MessagePhoto).caption.text;
            captionEntities = _parseEntities((m.content as td.MessagePhoto).caption.entities) ?? [];
          } else if (m.content is td.MessageVideo && (m.content as td.MessageVideo).caption.text.isNotEmpty) {
            caption = (m.content as td.MessageVideo).caption.text;
            captionEntities = _parseEntities((m.content as td.MessageVideo).caption.entities) ?? [];
          }
        }
      }

      result.add(post.copyWith(
        media: allMedia,
        viewCount: maxViews > 0 ? maxViews : post.viewCount,
        text: caption ?? post.text,
        entities: captionEntities.isNotEmpty ? captionEntities : post.entities,
      ));
    }

    return result;
  }

  static List<TextEntity>? _parseEntities(List<td.TextEntity>? entities) {
    final serialized = serializeEntities(entities);
    if (serialized == null) return null;
    final List<dynamic> list = jsonDecode(serialized);
    return list.map((e) => TextEntity.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Poll? _parsePoll(td.Poll? poll) {
    final serialized = serializePoll(poll);
    if (serialized == null) return null;
    return Poll.fromJson(jsonDecode(serialized));
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
