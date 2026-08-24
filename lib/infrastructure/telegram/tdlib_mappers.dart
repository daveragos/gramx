import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';
import 'package:gramx/features/feed/domain/poll.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/infrastructure/telegram/message_content_support.dart';

/// A message's reactions, flattened into the two collections `Post` carries.
///
/// A record rather than a `Post` fragment because the live update path needs
/// the same pair without building a post around it.
typedef MappedReactions = ({Map<String, int> counts, Set<String> chosen});

class TdlibMappers {
  /// The chip a paid (Telegram Stars) reaction is drawn as.
  ///
  /// `ReactionTypePaid` carries no emoji of its own — Telegram renders it as a
  /// star icon — so the map needs a key, and the key is what the card shows.
  static const String paidReactionEmoji = '⭐';

  /// Fallback glyph for a custom emoji reaction.
  ///
  /// Resolving the real artwork means `GetCustomEmojiStickers`, a networked
  /// request per distinct emoji and squarely against the budget in
  /// docs/TDLIB.md. A count under a placeholder is the honest version of "one
  /// more person reacted", and it beats dropping the reaction entirely — which
  /// is what used to happen.
  static const String customReactionEmoji = '🩶';

  /// Flattens TDLib's reaction list into counts and the reader's own choices.
  ///
  /// One function rather than a loop at each call site: the history mapper and
  /// the live update path both need this, they had a copy each, and the copies
  /// agreed only by accident — both kept nothing but [td.ReactionTypeEmoji], so
  /// paid and custom-emoji reactions vanished from posts that visibly had them
  /// in Telegram.
  static MappedReactions mapReactions(td.MessageReactions? reactions) =>
      mapReactionList(reactions?.reactions);

  /// The list form, for `updateMessageReactions` which carries no wrapper.
  static MappedReactions mapReactionList(List<td.MessageReaction>? reactions) {
    final counts = <String, int>{};
    final chosen = <String>{};
    if (reactions == null) return (counts: counts, chosen: chosen);

    for (final reaction in reactions) {
      final key = switch (reaction.type) {
        td.ReactionTypeEmoji(:final emoji) => emoji.isNotEmpty ? emoji : null,
        td.ReactionTypePaid() => paidReactionEmoji,
        td.ReactionTypeCustomEmoji() => customReactionEmoji,
      };
      if (key == null) continue;

      // Custom emoji all collapse onto one placeholder key, so counts add
      // rather than overwrite — two different custom reactions on one post are
      // two reactions, not the second one's count.
      counts[key] = (counts[key] ?? 0) + reaction.totalCount;
      if (reaction.isChosen) chosen.add(key);
    }

    return (counts: counts, chosen: chosen);
  }

  static String? _parseFormattedText(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw.isNotEmpty ? raw : null;
    if (raw is td.FormattedText) return raw.text.isNotEmpty ? raw.text : null;
    if (raw is Map) {
      final text = raw['text']?.toString();
      return text != null && text.isNotEmpty ? text : null;
    }
    try {
      final text = (raw as dynamic).text?.toString();
      if (text != null && text.isNotEmpty) return text;
    } catch (_) {}
    final str = raw.toString();
    return str.isNotEmpty ? str : null;
  }

  static Channel mapChatToChannel(td.Chat chat, {td.Supergroup? supergroup, td.SupergroupFullInfo? fullInfo}) {
    final status = supergroup?.status;
    final isJoined = status != null
        ? (status is! td.ChatMemberStatusLeft && status is! td.ChatMemberStatusBanned)
        : chat.positions.isNotEmpty;

    return Channel(
      id: chat.id.toString(),
      chatId: chat.id,
      title: chat.title,
      username: supergroup?.usernames?.activeUsernames.isNotEmpty == true ? supergroup!.usernames!.activeUsernames.first : null,
      description: _parseFormattedText(fullInfo?.description),
      avatarUrl: chat.photo != null
          ? (chat.photo!.small.local.path.isNotEmpty == true
              ? chat.photo!.small.local.path
              : (chat.photo!.small.remote.id.isNotEmpty
                  ? chat.photo!.small.remote.id
                  : chat.photo!.small.id.toString()))
          : null,
      avatarFileId: chat.photo?.small.id,
      avatarColor: _generateRandomHexColor(chat.id),
      subscriberCount: supergroup?.memberCount ?? 0,
      isVerified: supergroup?.isVerified ?? false,
      isFavorite: false,
      isMuted: false,
      isHidden: false,
      isJoined: isJoined,
    );
  }

  /// A one-line summary of a message, for a reply preview.
  ///
  /// Text messages and captions show their own words; everything else falls
  /// back to a label for its kind, the same way Telegram does.
  static String? excerptOf(td.Message message, {int maxLength = 120}) {
    final content = message.content;
    String? text;

    if (content is td.MessageText) {
      text = _parseFormattedText(content.text);
    } else if (content is td.MessagePhoto) {
      text = _parseFormattedText(content.caption) ?? '🖼 Photo';
    } else if (content is td.MessageVideo) {
      text = _parseFormattedText(content.caption) ?? '🎬 Video';
    } else if (content is td.MessageAnimation) {
      text = _parseFormattedText(content.caption) ?? 'GIF';
    } else if (content is td.MessageDocument) {
      text = _parseFormattedText(content.caption) ??
          (content.document.fileName.isNotEmpty
              ? content.document.fileName
              : '📄 Document');
    } else if (content is td.MessageVoiceNote) {
      text = _parseFormattedText(content.caption) ?? '🎤 Voice message';
    } else if (content is td.MessageAudio) {
      text = _parseFormattedText(content.caption) ?? '🎵 Audio';
    } else if (content is td.MessagePoll) {
      text = _parseFormattedText(content.poll.question);
    } else if (content is td.MessageSticker) {
      text = '${content.sticker.emoji} Sticker';
    } else {
      text = MessageContentSupport.describe(content);
    }

    if (text == null || text.isEmpty) return null;

    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= maxLength) return collapsed;
    return '${collapsed.substring(0, maxLength).trimRight()}…';
  }

  static Post mapMessageToPost(
    td.Message message,
    td.Chat chat, {
    bool isBookmarked = false,
    Map<int, String>? knownChatTitles,
    /// Excerpts for replied-to messages, keyed `chatId_messageId`.
    ///
    /// TDLib only fills `replyTo.content` for cross-chat replies and quotes, so
    /// a reply within the same channel arrives with no preview text at all. The
    /// repository resolves those and passes them in here.
    Map<String, String>? knownReplyExcerpts,
    String? overrideSenderTitle,
    String? overrideSenderAvatarUrl,
    int? overrideSenderAvatarFileId,
  }) {
    String? bodyText;
    String? linkPreviewUrl;
    String? linkPreviewTitle;
    String? linkPreviewDescription;
    String? linkPreviewImageUrl;
    int? linkPreviewFileId;
    List<TextEntity> textEntities = [];
    Poll? pollObj;
    String? unsupportedKind;

    final content = message.content;
    if (content is td.MessageText) {
      bodyText = _parseFormattedText(content.text);
      final parsed = _parseEntities(content.text.entities);
      if (parsed != null) textEntities = parsed;

      if (content.linkPreview != null) {
        final lp = content.linkPreview!;
        linkPreviewUrl = lp.url.isNotEmpty ? lp.url : null;
        linkPreviewTitle = lp.title.isNotEmpty ? lp.title : (lp.displayUrl.isNotEmpty ? lp.displayUrl : null);
        linkPreviewDescription = _parseFormattedText(lp.description);
        
        final preview = linkPreviewImage(lp.type);
        if (preview != null) {
          linkPreviewFileId = preview.id;
          if (preview.local.path.isNotEmpty) {
            linkPreviewImageUrl = preview.local.path;
          }
        }
      }
    } else if (content is td.MessagePhoto) {
      bodyText = _parseFormattedText(content.caption);
      final parsed = _parseEntities(content.caption.entities);
      if (parsed != null) textEntities = parsed;
    } else if (content is td.MessageVideo) {
      bodyText = _parseFormattedText(content.caption);
      final parsed = _parseEntities(content.caption.entities);
      if (parsed != null) textEntities = parsed;
    } else if (content is td.MessageAnimation) {
      bodyText = _parseFormattedText(content.caption);
      final parsed = _parseEntities(content.caption.entities);
      if (parsed != null) textEntities = parsed;
    } else if (content is td.MessageDocument) {
      bodyText = _parseFormattedText(content.caption);
      final parsed = _parseEntities(content.caption.entities);
      if (parsed != null) textEntities = parsed;
    } else if (content is td.MessageVoiceNote) {
      bodyText = _parseFormattedText(content.caption);
      final parsed = _parseEntities(content.caption.entities);
      if (parsed != null) textEntities = parsed;
    } else if (content is td.MessageAudio) {
      bodyText = _parseFormattedText(content.caption);
      final parsed = _parseEntities(content.caption.entities);
      if (parsed != null) textEntities = parsed;
    } else if (content is td.MessagePoll) {
      bodyText = _parseFormattedText(content.poll.question);
      pollObj = _parsePoll(content.poll);
    } else {
      // Content we don't draw yet still gets a label. Falling through silently
      // produced a card with a header, a timestamp, an action bar and nothing
      // between them — see MessageContentSupport.
      bodyText = MessageContentSupport.describe(content);
      if (MessageContentSupport.isUnsupported(content)) {
        // Carried so the card can offer Telegram rather than ending in a
        // sentence the reader can do nothing with. The type name is logged
        // because "unsupported" is otherwise unactionable in a bug report.
        unsupportedKind = content.currentObjectId;
        debugPrint('[Mapper] Unrendered content: ${content.currentObjectId}');
      }
    }

    final mappedReactions = mapReactions(message.interactionInfo?.reactions);

    String? forwardedFromTitle;
    String? forwardedFromUsername;
    String? forwardedFromChatId;
    int? forwardedFromMessageId;
    final fwdOrigin = message.forwardInfo?.origin;
    if (fwdOrigin is td.MessageOriginChannel) {
      forwardedFromChatId = fwdOrigin.chatId.toString();
      forwardedFromMessageId = fwdOrigin.messageId;
      final resolvedTitle = knownChatTitles?[fwdOrigin.chatId];
      forwardedFromTitle = resolvedTitle ?? (fwdOrigin.authorSignature.isNotEmpty ? fwdOrigin.authorSignature : null);
    } else if (fwdOrigin is td.MessageOriginChat) {
      forwardedFromChatId = fwdOrigin.senderChatId.toString();
      final resolvedTitle = knownChatTitles?[fwdOrigin.senderChatId];
      forwardedFromTitle = resolvedTitle;
    } else if (fwdOrigin is td.MessageOriginUser) {
      // User origin
    } else if (fwdOrigin is td.MessageOriginHiddenUser) {
      forwardedFromTitle = fwdOrigin.senderName;
    }

    String? replyToText;
    String? replyToAuthorTitle;
    int? replyToMessageId;
    String? replyToThumbnailUrl;
    int? replyToThumbnailFileId;
    int? replyToChatId;
    final replyTo = message.replyTo;
    if (replyTo is td.MessageReplyToMessage) {
      replyToMessageId = replyTo.messageId;
      // 0 means "same chat"; anything else is a reply across chats, and losing
      // it is what made a reachable post report itself as not found.
      replyToChatId = replyTo.chatId != 0 && replyTo.chatId != chat.id
          ? replyTo.chatId
          : null;

      // Author title resolution
      final origin = replyTo.origin;
      if (origin is td.MessageOriginChannel) {
        replyToAuthorTitle = knownChatTitles?[origin.chatId] ??
            (origin.authorSignature.isNotEmpty ? origin.authorSignature : chat.title);
      } else if (origin is td.MessageOriginChat) {
        replyToAuthorTitle = knownChatTitles?[origin.senderChatId] ?? chat.title;
      } else if (origin is td.MessageOriginUser) {
        replyToAuthorTitle = 'User';
      } else if (origin is td.MessageOriginHiddenUser) {
        replyToAuthorTitle = origin.senderName;
      }
      replyToAuthorTitle ??= chat.title;

      // Check for quoted text first (user selected specific text to reply to)
      final quote = replyTo.quote;
      if (quote != null) {
        replyToText = _parseFormattedText(quote.text);
      }

      // Resolved separately when TDLib didn't inline the content.
      replyToText ??= knownReplyExcerpts?[
          '${replyToChatId ?? chat.id}_${replyTo.messageId}'];

      // Content preview resolution & thumbnail extraction
      final content = replyTo.content;
      if (content is td.MessageText) {
        // Only use full content text if no quote was set
        replyToText ??= _parseFormattedText(content.text);
        if (content.linkPreview != null) {
          final lp = content.linkPreview!;
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
            final f = photo.sizes.first.photo;
            replyToThumbnailFileId = f.id;
            replyToThumbnailUrl = f.local.isDownloadingCompleted && f.local.path.isNotEmpty
                ? f.local.path
                : (f.remote.id.isNotEmpty ? f.remote.id : f.id.toString());
          } else if (thumbnail != null) {
            final f = thumbnail.file;
            replyToThumbnailFileId = f.id;
            replyToThumbnailUrl = f.local.isDownloadingCompleted && f.local.path.isNotEmpty
                ? f.local.path
                : (f.remote.id.isNotEmpty ? f.remote.id : f.id.toString());
          }
        }
      } else if (content is td.MessagePhoto) {
        final captionText = _parseFormattedText(content.caption);
        replyToText = captionText != null && captionText.isNotEmpty ? captionText : '📷 Photo';
        if (content.photo.sizes.isNotEmpty) {
          final f = content.photo.sizes.first.photo;
          replyToThumbnailFileId = f.id;
          replyToThumbnailUrl = f.local.isDownloadingCompleted && f.local.path.isNotEmpty
              ? f.local.path
              : (f.remote.id.isNotEmpty ? f.remote.id : f.id.toString());
        }
      } else if (content is td.MessageVideo) {
        final captionText = _parseFormattedText(content.caption);
        replyToText = captionText != null && captionText.isNotEmpty ? captionText : '📹 Video';
        final thumbFile = content.video.thumbnail?.file;
        if (thumbFile != null) {
          replyToThumbnailFileId = thumbFile.id;
          replyToThumbnailUrl = thumbFile.local.isDownloadingCompleted && thumbFile.local.path.isNotEmpty
              ? thumbFile.local.path
              : (thumbFile.remote.id.isNotEmpty ? thumbFile.remote.id : thumbFile.id.toString());
        }
      } else if (content is td.MessageAnimation) {
        replyToText = 'GIF';
        final thumbFile = content.animation.thumbnail?.file;
        if (thumbFile != null) {
          replyToThumbnailFileId = thumbFile.id;
          replyToThumbnailUrl = thumbFile.local.isDownloadingCompleted && thumbFile.local.path.isNotEmpty
              ? thumbFile.local.path
              : (thumbFile.remote.id.isNotEmpty ? thumbFile.remote.id : thumbFile.id.toString());
        }
      } else if (content is td.MessageSticker) {
        replyToText = '${content.sticker.emoji} Sticker';
        final thumbFile = content.sticker.thumbnail?.file ?? content.sticker.sticker;
        replyToThumbnailFileId = thumbFile.id;
        replyToThumbnailUrl = thumbFile.local.isDownloadingCompleted && thumbFile.local.path.isNotEmpty
            ? thumbFile.local.path
            : (thumbFile.remote.id.isNotEmpty ? thumbFile.remote.id : thumbFile.id.toString());
      } else if (content is td.MessagePoll) {
        final qText = _parseFormattedText(content.poll.question);
        replyToText = '📊 ${qText ?? ''}';
      } else if (content is td.MessageDocument) {
        replyToText = '📄 ${content.document.fileName}';
        final thumbFile = content.document.thumbnail?.file;
        if (thumbFile != null) {
          replyToThumbnailFileId = thumbFile.id;
          replyToThumbnailUrl = thumbFile.local.isDownloadingCompleted && thumbFile.local.path.isNotEmpty
              ? thumbFile.local.path
              : (thumbFile.remote.id.isNotEmpty ? thumbFile.remote.id : thumbFile.id.toString());
        }
      } else if (content is td.MessageVoiceNote) {
        final captionText = _parseFormattedText(content.caption);
        replyToText = captionText != null && captionText.isNotEmpty ? captionText : '🎤 Voice message';
      } else if (content is td.MessageAudio) {
        final captionText = _parseFormattedText(content.caption);
        replyToText = captionText != null && captionText.isNotEmpty ? captionText : '🎵 ${content.audio.fileName}';
      }
    }

    final hasDiscussionGroup = message.interactionInfo?.replyInfo != null;

    return Post(
      id: '${chat.id}_${message.id}',
      chatId: chat.id,
      channelId: chat.id.toString(),
      messageId: message.id,
      mediaAlbumId: message.mediaAlbumId.toInt(),
      channelTitle: overrideSenderTitle ?? chat.title,
      channelAvatarUrl: overrideSenderAvatarUrl ?? (chat.photo != null
          ? (chat.photo!.small.local.path.isNotEmpty == true
              ? chat.photo!.small.local.path
              : (chat.photo!.small.remote.id.isNotEmpty
                  ? chat.photo!.small.remote.id
                  : chat.photo!.small.id.toString()))
          : null),
      channelAvatarFileId: overrideSenderAvatarFileId ?? chat.photo?.small.id,
      channelAvatarColor: _generateRandomHexColor(chat.id),
      text: bodyText,
      media: extractMediaItems(message),
      publishedAt: DateTime.fromMillisecondsSinceEpoch(message.date * 1000),
      viewCount: message.interactionInfo?.viewCount ?? 0,
      replyCount: message.interactionInfo?.replyInfo?.replyCount ?? 0,
      forwardCount: message.interactionInfo?.forwardCount ?? 0,
      reactions: mappedReactions.counts,
      chosenReactions: mappedReactions.chosen,
      isBookmarked: isBookmarked,
      isRead: message.isOutgoing || message.id <= chat.lastReadInboxMessageId,
      linkPreviewUrl: linkPreviewUrl,
      linkPreviewTitle: linkPreviewTitle,
      linkPreviewDescription: linkPreviewDescription,
      linkPreviewImageUrl: linkPreviewImageUrl,
      linkPreviewFileId: linkPreviewFileId,
      forwardedFromTitle: forwardedFromTitle,
      forwardedFromUsername: forwardedFromUsername,
      forwardedFromChatId: forwardedFromChatId,
      forwardedFromMessageId: forwardedFromMessageId,
      replyToText: replyToText,
      replyToAuthorTitle: replyToAuthorTitle,
      replyToMessageId: replyToMessageId,
      replyToChatId: replyToChatId,
      replyToThumbnailUrl: replyToThumbnailUrl,
      replyToThumbnailFileId: replyToThumbnailFileId,
      hasDiscussionGroup: hasDiscussionGroup,
      authorSignature: message.authorSignature.isNotEmpty ? message.authorSignature : null,
      entities: textEntities,
      poll: pollObj,
      unsupportedKind: unsupportedKind,
    );
  }

  static List<MediaItem> extractMediaItems(td.Message message) {
    final list = <MediaItem>[];
    final content = message.content;

    if (content is td.MessagePhoto) {
      final photo = content.photo;
      final bestSize = photo.sizes.last;
      final bestPhotoFile = bestSize.photo;
      final bestPhotoPath = bestPhotoFile.local.isDownloadingCompleted && bestPhotoFile.local.path.isNotEmpty
          ? bestPhotoFile.local.path
          : (bestPhotoFile.remote.id.isNotEmpty ? bestPhotoFile.remote.id : bestPhotoFile.id.toString());
      final thumbFile = photo.sizes.first.photo;
      final thumbPath = thumbFile.local.isDownloadingCompleted && thumbFile.local.path.isNotEmpty
          ? thumbFile.local.path
          : (thumbFile.remote.id.isNotEmpty ? thumbFile.remote.id : thumbFile.id.toString());

      // Extract minithumbnail if available
      final minithumbnailBase64 = photo.minithumbnail?.data;

      list.add(MediaItem(
        id: bestPhotoPath,
        type: MediaType.photo,
        hasSpoiler: content.hasSpoiler,
        url: bestPhotoPath,
        thumbnailUrl: thumbPath,
        width: bestSize.width,
        height: bestSize.height,
        minithumbnail: minithumbnailBase64,
        fileId: bestPhotoFile.id,
        thumbnailFileId: thumbFile.id,
        localPath: bestPhotoFile.local.isDownloadingCompleted ? bestPhotoFile.local.path : null,
      ));
    } else if (content is td.MessageVideo) {
      final video = content.video;
      final videoFile = video.video;
      final videoPath = videoFile.local.isDownloadingCompleted && videoFile.local.path.isNotEmpty
          ? videoFile.local.path
          : (videoFile.remote.id.isNotEmpty ? videoFile.remote.id : videoFile.id.toString());
      final thumbFile = video.thumbnail?.file;
      final thumbPath = thumbFile != null
          ? (thumbFile.local.isDownloadingCompleted && thumbFile.local.path.isNotEmpty
              ? thumbFile.local.path
              : (thumbFile.remote.id.isNotEmpty ? thumbFile.remote.id : thumbFile.id.toString()))
          : null;

      // Extract minithumbnail
      final minithumbnailBase64 = video.minithumbnail?.data;

      list.add(MediaItem(
        id: videoPath,
        type: MediaType.video,
        hasSpoiler: content.hasSpoiler,
        url: videoPath,
        thumbnailUrl: thumbPath,
        width: video.width,
        height: video.height,
        duration: video.duration,
        fileSize: videoFile.expectedSize,
        fileName: video.fileName,
        mimeType: video.mimeType,
        minithumbnail: minithumbnailBase64,
        fileId: videoFile.id,
        thumbnailFileId: thumbFile?.id,
        localPath: videoFile.local.isDownloadingCompleted ? videoFile.local.path : null,
      ));
    } else if (content is td.MessageAnimation) {
      final anim = content.animation;
      final animFile = anim.animation;
      final animPath = animFile.local.isDownloadingCompleted && animFile.local.path.isNotEmpty
          ? animFile.local.path
          : (animFile.remote.id.isNotEmpty ? animFile.remote.id : animFile.id.toString());
      final thumbFile = anim.thumbnail?.file;
      final thumbPath = thumbFile != null
          ? (thumbFile.local.isDownloadingCompleted && thumbFile.local.path.isNotEmpty
              ? thumbFile.local.path
              : (thumbFile.remote.id.isNotEmpty ? thumbFile.remote.id : thumbFile.id.toString()))
          : null;

      // Extract minithumbnail
      final minithumbnailBase64 = anim.minithumbnail?.data;

      list.add(MediaItem(
        id: animPath,
        type: MediaType.gif,
        hasSpoiler: content.hasSpoiler,
        url: animPath,
        thumbnailUrl: thumbPath,
        width: anim.width,
        height: anim.height,
        duration: anim.duration,
        minithumbnail: minithumbnailBase64,
        fileId: animFile.id,
        thumbnailFileId: thumbFile?.id,
        localPath: animFile.local.isDownloadingCompleted ? animFile.local.path : null,
      ));
    } else if (content is td.MessageDocument) {
      final doc = content.document;
      final docFile = doc.document;
      final docPath = docFile.local.isDownloadingCompleted && docFile.local.path.isNotEmpty
          ? docFile.local.path
          : (docFile.remote.id.isNotEmpty ? docFile.remote.id : docFile.id.toString());
      final thumbFile = doc.thumbnail?.file;
      final thumbPath = thumbFile != null
          ? (thumbFile.local.isDownloadingCompleted && thumbFile.local.path.isNotEmpty
              ? thumbFile.local.path
              : (thumbFile.remote.id.isNotEmpty ? thumbFile.remote.id : thumbFile.id.toString()))
          : null;

      list.add(MediaItem(
        id: docPath,
        type: MediaType.document,
        url: docPath,
        thumbnailUrl: thumbPath,
        fileSize: docFile.expectedSize,
        fileName: doc.fileName,
        mimeType: doc.mimeType,
        fileId: docFile.id,
        thumbnailFileId: thumbFile?.id,
        localPath: docFile.local.isDownloadingCompleted ? docFile.local.path : null,
      ));
    } else if (content is td.MessageSticker) {
      final sticker = content.sticker;
      final stickerFile = sticker.sticker;
      final stickerPath = stickerFile.local.isDownloadingCompleted && stickerFile.local.path.isNotEmpty
          ? stickerFile.local.path
          : (stickerFile.remote.id.isNotEmpty ? stickerFile.remote.id : stickerFile.id.toString());
      final thumbFile = sticker.thumbnail?.file;
      final thumbPath = thumbFile != null
          ? (thumbFile.local.isDownloadingCompleted && thumbFile.local.path.isNotEmpty
              ? thumbFile.local.path
              : (thumbFile.remote.id.isNotEmpty ? thumbFile.remote.id : thumbFile.id.toString()))
          : null;

      list.add(MediaItem(
        id: stickerPath,
        // Not MediaType.photo: a TGS sticker is gzipped Lottie JSON and a WebM
        // sticker is video, so handing either to an image widget renders
        // nothing. The tile picks a renderer from stickerFormat.
        type: MediaType.sticker,
        url: stickerPath,
        thumbnailUrl: thumbPath,
        width: sticker.width,
        height: sticker.height,
        fileId: stickerFile.id,
        thumbnailFileId: thumbFile?.id,
        stickerFormat:
            StickerFormat.fromTdName(sticker.format.currentObjectId),
        localPath: stickerFile.local.isDownloadingCompleted ? stickerFile.local.path : null,
      ));
    } else if (content is td.MessageVoiceNote) {
      final voice = content.voiceNote;
      final voiceFile = voice.voice;
      final voicePath = voiceFile.local.isDownloadingCompleted && voiceFile.local.path.isNotEmpty
          ? voiceFile.local.path
          : (voiceFile.remote.id.isNotEmpty ? voiceFile.remote.id : voiceFile.id.toString());

      list.add(MediaItem(
        id: voicePath,
        type: MediaType.voice,
        url: voicePath,
        duration: voice.duration,
        fileSize: voiceFile.expectedSize,
        fileName: 'Voice message',
        mimeType: voice.mimeType,
        fileId: voiceFile.id,
        localPath: voiceFile.local.isDownloadingCompleted ? voiceFile.local.path : null,
      ));
    } else if (content is td.MessageAudio) {
      final audio = content.audio;
      final audioFile = audio.audio;
      final audioPath = audioFile.local.isDownloadingCompleted && audioFile.local.path.isNotEmpty
          ? audioFile.local.path
          : (audioFile.remote.id.isNotEmpty ? audioFile.remote.id : audioFile.id.toString());
      final thumbFile = audio.albumCoverThumbnail?.file;
      final thumbPath = thumbFile != null
          ? (thumbFile.local.isDownloadingCompleted && thumbFile.local.path.isNotEmpty
              ? thumbFile.local.path
              : (thumbFile.remote.id.isNotEmpty ? thumbFile.remote.id : thumbFile.id.toString()))
          : null;

      list.add(MediaItem(
        id: audioPath,
        type: MediaType.audio,
        url: audioPath,
        thumbnailUrl: thumbPath,
        duration: audio.duration,
        fileSize: audioFile.expectedSize,
        fileName: audio.fileName.isNotEmpty ? audio.fileName : (audio.title.isNotEmpty ? audio.title : 'Audio track'),
        mimeType: audio.mimeType,
        fileId: audioFile.id,
        thumbnailFileId: thumbFile?.id,
        localPath: audioFile.local.isDownloadingCompleted ? audioFile.local.path : null,
      ));
    }

    return list;
  }

  static List<Post> mergeAlbumMessages(List<td.Message> messages, td.Chat chat, {Set<String> bookmarkedKeys = const {}, Map<int, String>? knownChatTitles, Map<String, String>? knownReplyExcerpts}) {
    final grouped = <int, List<td.Message>>{};
    final result = <Post>[];

    for (final m in messages) {
      // Telegram's own notices about the chat — pins, renames, joins — are
      // noise in a reading feed.
      if (!MessageContentSupport.belongsInFeed(m.content)) continue;

      final albumId = m.mediaAlbumId.toInt();
      if (albumId == 0) {
        result.add(mapMessageToPost(m, chat, isBookmarked: bookmarkedKeys.contains('${chat.id}_${m.id}'), knownChatTitles: knownChatTitles, knownReplyExcerpts: knownReplyExcerpts));
      } else {
        grouped.putIfAbsent(albumId, () => []).add(m);
      }
    }

    for (final group in grouped.values) {
      group.sort((a, b) => a.id.compareTo(b.id));
      final anchor = group.first;
      
      final post = mapMessageToPost(anchor, chat, isBookmarked: bookmarkedKeys.contains('${chat.id}_${anchor.id}'), knownChatTitles: knownChatTitles, knownReplyExcerpts: knownReplyExcerpts);
      
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

  /// The image to show for a link preview, whatever shape TDLib describes it in.
  ///
  /// `LinkPreviewType` is a union of thirty-odd branches and each carries its
  /// picture somewhere different. Handling only a handful of them is why a
  /// YouTube link showed a bare card: those arrive as
  /// `linkPreviewTypeEmbeddedVideoPlayer`, whose thumbnail lives in a `Photo`
  /// rather than on a `Video` — a branch nothing looked at.
  ///
  /// Returns null for links that genuinely have no image (a voice note, a
  /// boost link), so the card renders without a blank banner.
  static td.File? linkPreviewImage(td.LinkPreviewType type) {
    td.File? fromPhoto(td.Photo? photo) {
      if (photo == null || photo.sizes.isEmpty) return null;
      // Sizes are ordered smallest first; the last is the best available.
      return photo.sizes.last.photo;
    }

    return switch (type) {
      td.LinkPreviewTypePhoto() => fromPhoto(type.photo),
      td.LinkPreviewTypeArticle() => fromPhoto(type.photo),
      td.LinkPreviewTypeApp() => fromPhoto(type.photo),
      td.LinkPreviewTypeWebApp() => fromPhoto(type.photo),
      // The embedded players — YouTube, Vimeo, SoundCloud and friends.
      td.LinkPreviewTypeEmbeddedVideoPlayer() => fromPhoto(type.thumbnail),
      td.LinkPreviewTypeEmbeddedAnimationPlayer() => fromPhoto(type.thumbnail),
      td.LinkPreviewTypeEmbeddedAudioPlayer() => fromPhoto(type.thumbnail),
      td.LinkPreviewTypeVideo() => type.video.thumbnail?.file,
      td.LinkPreviewTypeAnimation() => type.animation.thumbnail?.file,
      td.LinkPreviewTypeDocument() => type.document.thumbnail?.file,
      td.LinkPreviewTypeAudio() => type.audio.albumCoverThumbnail?.file,
      td.LinkPreviewTypeVideoNote() => type.videoNote.thumbnail?.file,
      td.LinkPreviewTypeSticker() =>
        type.sticker.thumbnail?.file ?? type.sticker.sticker,
      td.LinkPreviewTypeAlbum() => _albumCover(type.media),
      td.LinkPreviewTypeChat() => _chatPhotoFile(type.photo),
      td.LinkPreviewTypeUser() => _chatPhotoFile(type.photo),
      _ => null,
    };
  }

  static td.File? _chatPhotoFile(td.ChatPhoto? photo) {
    if (photo == null || photo.sizes.isEmpty) return null;
    return photo.sizes.last.photo;
  }

  /// The first thing in a shared album that has a picture.
  static td.File? _albumCover(List<td.LinkPreviewAlbumMedia> media) {
    for (final item in media) {
      switch (item) {
        case td.LinkPreviewAlbumMediaPhoto():
          if (item.photo.sizes.isNotEmpty) return item.photo.sizes.last.photo;
        case td.LinkPreviewAlbumMediaVideo():
          final thumbnail = item.video.thumbnail?.file;
          if (thumbnail != null) return thumbnail;
      }
    }
    return null;
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

        String? language;

        // Every branch of TDLib's union gets a name. Anything left out arrives
        // as 'unknown' and renders as plain text, which is how block quotes and
        // fenced code lost their formatting.
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
        } else if (type is td.TextEntityTypePreCode) {
          // Checked before Pre: PreCode is not a subclass, but keeping the
          // language-bearing case first makes the intent obvious.
          typeStr = 'codeBlock';
          language = type.language;
        } else if (type is td.TextEntityTypePre) {
          typeStr = 'codeBlock';
        } else if (type is td.TextEntityTypeBlockQuote) {
          typeStr = 'blockQuote';
        } else if (type is td.TextEntityTypeExpandableBlockQuote) {
          typeStr = 'expandableBlockQuote';
        } else if (type is td.TextEntityTypeUrl) {
          typeStr = 'url';
        } else if (type is td.TextEntityTypeTextUrl) {
          typeStr = 'textUrl';
          url = type.url;
        } else if (type is td.TextEntityTypeMention) {
          typeStr = 'mention';
        } else if (type is td.TextEntityTypeMentionName) {
          typeStr = 'mentionName';
        } else if (type is td.TextEntityTypeHashtag) {
          typeStr = 'hashtag';
        } else if (type is td.TextEntityTypeCashtag) {
          typeStr = 'cashtag';
        } else if (type is td.TextEntityTypeBotCommand) {
          typeStr = 'botCommand';
        } else if (type is td.TextEntityTypeEmailAddress) {
          typeStr = 'emailAddress';
        } else if (type is td.TextEntityTypePhoneNumber) {
          typeStr = 'phoneNumber';
        } else if (type is td.TextEntityTypeBankCardNumber) {
          typeStr = 'bankCardNumber';
        } else if (type is td.TextEntityTypeMediaTimestamp) {
          typeStr = 'mediaTimestamp';
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
          'url': ?url,
          'customEmojiId': ?customEmojiId,
          'language': ?language,
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
          'text': _parseFormattedText(opt.text) ?? '',
          'voterCount': opt.voterCount,
          'votePercentage': opt.votePercentage.toDouble(),
          'isChosen': opt.isChosen,
          'isCorrect': isCorrect,
        };
      }).toList();

      final map = {
        'id': poll.id.toString(),
        'question': _parseFormattedText(poll.question) ?? '',
        'options': options,
        'totalVoterCount': poll.totalVoterCount,
        'isAnonymous': poll.isAnonymous,
        'isClosed': poll.isClosed,
        'isQuiz': isQuiz,
        'correctOptionId': correctOptionId,
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
