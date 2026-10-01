import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/data/chat_list_builder.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/domain/message_place.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/poll.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';
import 'package:gramx/infrastructure/telegram/message_content_support.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';

/// Turns a TDLib message into a conversation bubble. Pure: every lookup is
/// passed in, so mapping a page of messages costs no requests.
abstract class ChatMessageMapper {
  /// Maps one message. Messages at or below [lastReadOutboxMessageId] have
  /// been read by the other side (TDLib has no per-message read flag). Sender
  /// names are drawn only when [isGroup].
  static ChatMessage map(
    td.Message message, {
    required Map<int, td.User> users,
    required int lastReadOutboxMessageId,
    bool isGroup = false,
    Map<int, td.Chat> chats = const {},
  }) {
    final content = message.content;
    final support = MessageContentSupport.supportFor(content);
    final isService = support.handling == ContentHandling.service;

    final sender = message.senderId;
    final senderUser = sender is td.MessageSenderUser
        ? users[sender.userId]
        : null;
    // Someone posting as a chat (a channel, or an anonymous admin) is looked
    // up among chats, not users.
    final senderChat = sender is td.MessageSenderChat
        ? chats[sender.chatId]
        : null;

    final body = decodeContent(content);
    final mappedReactions = TdlibMappers.mapReactions(
      message.interactionInfo?.reactions,
    );
    final destruct = message.selfDestructType;

    return ChatMessage(
      id: '${message.chatId}_${message.id}',
      chatId: message.chatId,
      messageId: message.id,
      mediaAlbumId: message.mediaAlbumId,
      isOutgoing: message.isOutgoing,
      senderId: sender is td.MessageSenderUser ? sender.userId : null,
      // Only groups name their senders; null means no name row.
      senderName: !isGroup
          ? null
          : senderUser != null
          ? ChatListBuilder.displayNameOf(senderUser)
          : senderChat?.title,
      senderAvatarPath: !isGroup
          ? null
          : senderUser != null
          ? (senderUser.profilePhoto?.small.local.path.isNotEmpty == true
                ? senderUser.profilePhoto!.small.local.path
                : null)
          : (senderChat?.photo?.small.local.path.isNotEmpty == true
                ? senderChat!.photo!.small.local.path
                : null),
      senderAvatarFileId: !isGroup
          ? null
          : senderUser?.profilePhoto?.small.id ?? senderChat?.photo?.small.id,
      senderAvatarColorHex: !isGroup
          ? null
          : senderUser != null
          ? TdlibMappers.avatarColorFor(senderUser.id)
          : senderChat != null
          ? TdlibMappers.avatarColorFor(senderChat.id)
          : null,
      text: isService
          ? serviceText(message, users: users, chats: chats)
          : body.text,
      entities: body.entities,
      media: body.media,
      poll: body.poll,
      place: body.place,
      contact: body.contact,
      isSecretMedia: body.isSecretMedia,
      isViewOnce: destruct is td.MessageSelfDestructTypeImmediately,
      selfDestructSeconds: destruct is td.MessageSelfDestructTypeTimer
          ? destruct.selfDestructTime
          : 0,
      sentAt: DateTime.fromMillisecondsSinceEpoch(message.date * 1000),
      editedAt: message.editDate > 0
          ? DateTime.fromMillisecondsSinceEpoch(message.editDate * 1000)
          : null,
      sendState: sendStateOf(
        message,
        lastReadOutboxMessageId: lastReadOutboxMessageId,
      ),
      reactions: mappedReactions.counts,
      chosenReactions: mappedReactions.chosen,
      replyToMessageId: _replyTarget(message)?.messageId,
      replyToChatId: _replyChatId(message),
      replyToText: _replyExcerpt(message),
      replyToAuthorName: _replyAuthor(message, users: users, chats: chats),
      replyToThumbnailFileId: _replyThumbnailFileId(message),
      forwardedFromTitle: _forwardOrigin(message, users: users),
      linkPreviewUrl: body.linkPreviewUrl,
      linkPreviewTitle: body.linkPreviewTitle,
      linkPreviewDescription: body.linkPreviewDescription,
      linkPreviewFileId: body.linkPreviewFileId,
      isPinned: message.isPinned,
      isService: isService,
      unsupportedKind: support.handling == ContentHandling.unrepresentable
          ? content.currentObjectId
          : null,
    );
  }

  /// Where a message is on its way to Telegram. Pending or failed wins over
  /// the read cursor; an incoming message reports [sent] and draws no tick.
  static MessageSendState sendStateOf(
    td.Message message, {
    required int lastReadOutboxMessageId,
  }) {
    return switch (message.sendingState) {
      td.MessageSendingStatePending() => MessageSendState.sending,
      td.MessageSendingStateFailed() => MessageSendState.failed,
      _ =>
        message.isOutgoing && message.id <= lastReadOutboxMessageId
            ? MessageSendState.read
            : MessageSendState.sent,
    };
  }

  /// Maps a page of messages, newest last (TDLib returns history newest first).
  static List<ChatMessage> mapHistory(
    List<td.Message> messages, {
    required Map<int, td.User> users,
    required int lastReadOutboxMessageId,
    bool isGroup = false,
    Map<int, td.Chat> chats = const {},
  }) {
    final mapped = [
      for (final message in messages)
        map(
          message,
          users: users,
          lastReadOutboxMessageId: lastReadOutboxMessageId,
          isGroup: isGroup,
          chats: chats,
        ),
    ];
    mapped.sort((a, b) => a.messageId.compareTo(b.messageId));
    return mapped;
  }

  /// Fills in reply previews from loaded messages, since TDLib inlines
  /// `replyTo.content` only for cross-chat replies and quotes. [from] adds
  /// targets outside [messages], such as the rest of the conversation.
  static List<ChatMessage> fillReplyExcerpts(
    List<ChatMessage> messages, {
    Iterable<ChatMessage> from = const [],
  }) {
    final byId = {
      for (final message in from) message.messageId: message,
      for (final message in messages) message.messageId: message,
    };

    return [
      for (final message in messages)
        if (message.replyToMessageId == null ||
            message.replyToChatId != null ||
            message.replyToText != null)
          message
        else if (byId[message.replyToMessageId!] case final target?)
          message.copyWith(
            replyToText: replyPreviewOf(target),
            replyToAuthorName:
                message.replyToAuthorName ?? replyAuthorOf(target),
            replyToThumbnailFileId:
                message.replyToThumbnailFileId ?? _thumbnailOf(target),
          )
        else
          message,
    ];
  }

  /// The author a reply names: "You" for your own messages, otherwise the
  /// sender name (null in a one-to-one chat).
  static String? replyAuthorOf(ChatMessage target) =>
      target.isOutgoing ? AppStrings.messagesYouPrefix : target.senderName;

  /// A message in one line for a reply: its text, or a label for its content.
  static String? replyPreviewOf(ChatMessage target) {
    final text = target.text;
    if (text != null && text.trim().isNotEmpty) return text;
    if (target.poll case final poll?) return poll.question;
    if (target.place != null) return AppStrings.mediaLocation;
    if (target.contact != null) return AppStrings.contactMessage;
    if (target.media.isEmpty) return null;
    return switch (target.media.first.type) {
      MediaType.photo => AppStrings.mediaPhoto,
      MediaType.video => AppStrings.mediaVideo,
      MediaType.gif => AppStrings.mediaGif,
      MediaType.document => AppStrings.mediaDocument,
      MediaType.audio => AppStrings.mediaAudio,
      MediaType.voice => AppStrings.mediaVoice,
      MediaType.sticker => AppStrings.mediaSticker,
    };
  }

  static int? _thumbnailOf(ChatMessage target) {
    if (target.media.isEmpty) return null;
    final item = target.media.first;
    return switch (item.type) {
      MediaType.photo => item.thumbnailFileId ?? item.fileId,
      MediaType.video || MediaType.gif => item.thumbnailFileId,
      _ => null,
    };
  }

  /// Rewrites a mapped message around new content from `updateMessageContent`
  /// (a caption edit, a poll vote, or expiring media), using the same decoder
  /// as [map].
  static ChatMessage withContent(ChatMessage message, td.MessageContent body) {
    final decoded = decodeContent(body);
    final support = MessageContentSupport.supportFor(body);

    return message.copyWith(
      text: decoded.text,
      entities: decoded.entities,
      media: decoded.media,
      poll: decoded.poll,
      place: decoded.place,
      contact: decoded.contact,
      isSecretMedia: decoded.isSecretMedia,
      linkPreviewUrl: decoded.linkPreviewUrl,
      linkPreviewTitle: decoded.linkPreviewTitle,
      linkPreviewDescription: decoded.linkPreviewDescription,
      linkPreviewFileId: decoded.linkPreviewFileId,
      unsupportedKind: support.handling == ContentHandling.unrepresentable
          ? body.currentObjectId
          : null,
    );
  }

  /// Everything a bubble draws, read from one content object. Shared by [map]
  /// and [withContent] so the two always agree.
  @visibleForTesting
  static ({
    String? text,
    List<TextEntity> entities,
    List<MediaItem> media,
    Poll? poll,
    MessagePlace? place,
    MessageContactCard? contact,
    bool isSecretMedia,
    String? linkPreviewUrl,
    String? linkPreviewTitle,
    String? linkPreviewDescription,
    int? linkPreviewFileId,
  })
  decodeContent(td.MessageContent content) {
    // A poll is the whole message, with no caption or media.
    if (content is td.MessagePoll) {
      return (
        text: null,
        entities: const <TextEntity>[],
        media: const <MediaItem>[],
        poll: TdlibMappers.mapPoll(content.poll),
        place: null,
        contact: null,
        isSecretMedia: false,
        linkPreviewUrl: null,
        linkPreviewTitle: null,
        linkPreviewDescription: null,
        linkPreviewFileId: null,
      );
    }

    // Places and contacts are drawn as cards, not captions.
    final place = _placeOf(content);
    if (place != null) {
      return (
        text: null,
        entities: const <TextEntity>[],
        media: const <MediaItem>[],
        poll: null,
        place: place,
        contact: null,
        isSecretMedia: false,
        linkPreviewUrl: null,
        linkPreviewTitle: null,
        linkPreviewDescription: null,
        linkPreviewFileId: null,
      );
    }

    if (content is td.MessageContact) {
      return (
        text: null,
        entities: const <TextEntity>[],
        media: const <MediaItem>[],
        poll: null,
        place: null,
        contact: MessageContactCard(
          firstName: content.contact.firstName,
          lastName: content.contact.lastName,
          phoneNumber: content.contact.phoneNumber,
          userId: content.contact.userId,
        ),
        isSecretMedia: false,
        linkPreviewUrl: null,
        linkPreviewTitle: null,
        linkPreviewDescription: null,
        linkPreviewFileId: null,
      );
    }

    td.FormattedText? formatted;
    String? linkPreviewUrl;
    String? linkPreviewTitle;
    String? linkPreviewDescription;
    int? linkPreviewFileId;

    switch (content) {
      case td.MessageText():
        formatted = content.text;
        final preview = content.linkPreview;
        if (preview != null) {
          linkPreviewUrl = preview.url.isNotEmpty ? preview.url : null;
          linkPreviewTitle = preview.title.isNotEmpty
              ? preview.title
              : (preview.displayUrl.isNotEmpty ? preview.displayUrl : null);
          linkPreviewDescription = TdlibMappers.plainTextOf(
            preview.description,
          );
          linkPreviewFileId = TdlibMappers.linkPreviewImage(preview.type)?.id;
        }
      case td.MessagePhoto():
        formatted = content.caption;
      case td.MessageVideo():
        formatted = content.caption;
      case td.MessageAnimation():
        formatted = content.caption;
      case td.MessageDocument():
        formatted = content.caption;
      case td.MessageVoiceNote():
        formatted = content.caption;
      case td.MessageAudio():
        formatted = content.caption;
      default:
        // Anything else (a sticker, a service notice) has no text, so it uses
        // the feed's label. See MessageContentSupport.
        return (
          text: MessageContentSupport.describe(content),
          entities: const <TextEntity>[],
          media: TdlibMappers.extractMediaFromContent(content),
          poll: null,
          place: null,
          contact: null,
          isSecretMedia: _isSecret(content),
          linkPreviewUrl: null,
          linkPreviewTitle: null,
          linkPreviewDescription: null,
          linkPreviewFileId: null,
        );
    }

    return (
      text: TdlibMappers.plainTextOf(formatted),
      entities: TdlibMappers.entitiesOf(formatted.entities) ?? const [],
      media: TdlibMappers.extractMediaFromContent(content),
      poll: null,
      place: null,
      contact: null,
      isSecretMedia: _isSecret(content),
      linkPreviewUrl: linkPreviewUrl,
      linkPreviewTitle: linkPreviewTitle,
      linkPreviewDescription: linkPreviewDescription,
      linkPreviewFileId: linkPreviewFileId,
    );
  }

  /// The place in a location or venue message, or null for anything else.
  static MessagePlace? _placeOf(td.MessageContent content) => switch (content) {
    td.MessageLocation() => MessagePlace(
      latitude: content.location.latitude,
      longitude: content.location.longitude,
      livePeriod: content.livePeriod,
      expiresIn: content.expiresIn,
    ),
    td.MessageVenue() => MessagePlace(
      latitude: content.venue.location.latitude,
      longitude: content.venue.location.longitude,
      title: content.venue.title,
      address: content.venue.address.isEmpty ? null : content.venue.address,
    ),
    _ => null,
  };

  /// Whether this is tap-to-view media that is still covered. TDLib keeps the
  /// flag on the content and clears it once the media is opened.
  static bool _isSecret(td.MessageContent content) => switch (content) {
    td.MessagePhoto() => content.isSecret,
    td.MessageVideo() => content.isSecret,
    td.MessageVideoNote() => content.isSecret,
    td.MessageAnimation() => content.isSecret,
    _ => false,
  };

  static td.MessageReplyToMessage? _replyTarget(td.Message message) {
    final replyTo = message.replyTo;
    return replyTo is td.MessageReplyToMessage ? replyTo : null;
  }

  static int? _replyChatId(td.Message message) {
    final target = _replyTarget(message);
    if (target == null) return null;
    // 0 or this chat's own id both mean a same-chat reply.
    if (target.chatId == 0 || target.chatId == message.chatId) return null;
    return target.chatId;
  }

  static String? _replyExcerpt(td.Message message) {
    final target = _replyTarget(message);
    if (target == null) return null;

    // A quote is what the sender pointed at, so it wins over the whole message.
    final quote = target.quote;
    if (quote != null) {
      final text = TdlibMappers.plainTextOf(quote.text);
      if (text != null) return text;
    }

    final content = target.content;
    if (content == null) return null;
    return _previewOfContent(content);
  }

  static String? _previewOfContent(td.MessageContent content) =>
      switch (content) {
        td.MessageText() => TdlibMappers.plainTextOf(content.text),
        td.MessagePhoto() =>
          TdlibMappers.plainTextOf(content.caption) ?? '🖼 Photo',
        td.MessageVideo() =>
          TdlibMappers.plainTextOf(content.caption) ?? '🎬 Video',
        td.MessageAnimation() =>
          TdlibMappers.plainTextOf(content.caption) ?? 'GIF',
        td.MessageVoiceNote() =>
          TdlibMappers.plainTextOf(content.caption) ?? '🎤 Voice message',
        td.MessageDocument() =>
          TdlibMappers.plainTextOf(content.caption) ??
              (content.document.fileName.isNotEmpty
                  ? content.document.fileName
                  : '📄 Document'),
        td.MessageSticker() => '${content.sticker.emoji} Sticker',
        _ => MessageContentSupport.describe(content),
      };

  static String? _replyAuthor(
    td.Message message, {
    required Map<int, td.User> users,
    Map<int, td.Chat> chats = const {},
  }) {
    final origin = _replyTarget(message)?.origin;
    // Channel posts and messages sent as a chat are named after the chat,
    // since most channels set no signature.
    return switch (origin) {
      td.MessageOriginUser() => _nameOfUser(origin.senderUserId, users: users),
      td.MessageOriginHiddenUser() => origin.senderName,
      td.MessageOriginChannel() =>
        chats[origin.chatId]?.title ??
            (origin.authorSignature.isNotEmpty ? origin.authorSignature : null),
      td.MessageOriginChat() =>
        chats[origin.senderChatId]?.title ??
            (origin.authorSignature.isNotEmpty ? origin.authorSignature : null),
      _ => null,
    };
  }

  static int? _replyThumbnailFileId(td.Message message) {
    final content = _replyTarget(message)?.content;
    return switch (content) {
      td.MessagePhoto() =>
        content.photo.sizes.isEmpty ? null : content.photo.sizes.first.photo.id,
      td.MessageVideo() => content.video.thumbnail?.file.id,
      td.MessageAnimation() => content.animation.thumbnail?.file.id,
      td.MessageDocument() => content.document.thumbnail?.file.id,
      _ => null,
    };
  }

  static String? _forwardOrigin(
    td.Message message, {
    required Map<int, td.User> users,
  }) {
    final origin = message.forwardInfo?.origin;
    return switch (origin) {
      td.MessageOriginUser() => _nameOfUser(origin.senderUserId, users: users),
      td.MessageOriginHiddenUser() => origin.senderName,
      td.MessageOriginChannel() =>
        origin.authorSignature.isNotEmpty ? origin.authorSignature : null,
      _ => null,
    };
  }

  static String? _nameOfUser(int userId, {required Map<int, td.User> users}) {
    final user = users[userId];
    return user == null ? null : ChatListBuilder.displayNameOf(user);
  }

  /// The line for something that happened to a chat (a join, a pin, a
  /// rename), or null for kinds not worth showing, which the conversation
  /// leaves out (see `ConversationRows.build`).
  static String? serviceText(
    td.Message message, {
    required Map<int, td.User> users,
    Map<int, td.Chat> chats = const {},
  }) {
    final sender = message.senderId;
    final who =
        switch (sender) {
          td.MessageSenderUser() => _nameOfUser(sender.userId, users: users),
          td.MessageSenderChat() => chats[sender.chatId]?.title,
        } ??
        AppStrings.serviceSomeone;
    String nameOf(int userId) =>
        _nameOfUser(userId, users: users) ?? AppStrings.serviceSomeone;
    final senderUserId = sender is td.MessageSenderUser ? sender.userId : null;

    final content = message.content;
    return switch (content) {
      td.MessageChatAddMembers(:final memberUserIds)
          when memberUserIds.length == 1 &&
              memberUserIds.first == senderUserId =>
        AppStrings.serviceJoined(who),
      td.MessageChatAddMembers(:final memberUserIds) => AppStrings.serviceAdded(
        who,
        memberUserIds.map(nameOf).join(', '),
      ),
      td.MessageChatJoinByLink() => AppStrings.serviceJoinedByLink(who),
      td.MessageChatJoinByRequest() => AppStrings.serviceAccepted(who),
      td.MessageChatDeleteMember(:final userId) when userId == senderUserId =>
        AppStrings.serviceLeft(who),
      td.MessageChatDeleteMember(:final userId) => AppStrings.serviceRemoved(
        who,
        nameOf(userId),
      ),
      td.MessagePinMessage() => AppStrings.servicePinned(who),
      td.MessageChatChangeTitle(:final title) => AppStrings.serviceRenamed(
        who,
        title,
      ),
      td.MessageChatChangePhoto() => AppStrings.servicePhotoChanged(who),
      td.MessageChatDeletePhoto() => AppStrings.servicePhotoRemoved(who),
      td.MessageBasicGroupChatCreate(:final title) ||
      td.MessageSupergroupChatCreate(
        :final title,
      ) => AppStrings.serviceCreated(who, title),
      td.MessageChatUpgradeTo() ||
      td.MessageChatUpgradeFrom() => AppStrings.serviceUpgraded,
      td.MessageScreenshotTaken() => AppStrings.serviceScreenshot(who),
      td.MessageChatSetMessageAutoDeleteTime(:final messageAutoDeleteTime) =>
        AppStrings.serviceAutoDelete(who, messageAutoDeleteTime),
      td.MessageContactRegistered() => AppStrings.serviceJoinedTelegram(who),
      td.MessageVideoChatStarted() => AppStrings.serviceVideoChatStarted,
      td.MessageVideoChatEnded() => AppStrings.serviceVideoChatEnded,
      td.MessageForumTopicCreated(:final name) =>
        AppStrings.serviceTopicCreated(name),
      td.MessageChatBoost() => AppStrings.serviceBoosted(who),
      td.MessageCustomServiceAction(:final text) when text.isNotEmpty => text,
      _ => null,
    };
  }
}
