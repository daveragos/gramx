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

/// Turns a TDLib message into a conversation bubble.
///
/// Pure: every lookup it needs — who the sender is, what the outbox cursor is
/// — is passed in rather than fetched, so the whole mapping is testable and
/// costs no requests. That matters more here than in the feed, because a
/// conversation maps a page of messages at a time and a per-message `GetUser`
/// would be a fan-out inside a single screen.
abstract class ChatMessageMapper {
  /// Maps one message.
  ///
  /// [lastReadOutboxMessageId] is the chat's outbox cursor: anything at or
  /// below it has been read by the other side. It is the only source for the
  /// double tick — TDLib sends no per-message "was read" flag.
  ///
  /// [isGroup] decides whether a sender name is drawn at all. In a private chat
  /// the two possible senders are the two people looking at the screen, and
  /// naming them on every bubble is noise.
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
    // Somebody writing *as a chat* — a channel they run, or a group's
    // anonymous admin. Looked up among chats rather than users, or the bubble
    // draws a nameless "?" for one of the commonest senders in a group.
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
      // Only groups name their senders. A null here is what the bubble reads to
      // decide not to draw a name row at all.
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

  /// Where a message is on its way to Telegram.
  ///
  /// The order matters. A pending or failed send is the truth regardless of any
  /// cursor, and only a message this account sent can be "read" at all — an
  /// incoming message has no send state to show, so it reports [sent] and the
  /// bubble draws no tick.
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

  /// Maps a page of messages, newest last.
  ///
  /// TDLib hands history back newest-first; a conversation reads oldest-first,
  /// so the reversal happens here rather than at three call sites.
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

  /// Fills in reply previews from the page itself.
  ///
  /// TDLib only inlines `replyTo.content` for cross-chat replies and quotes, so
  /// a reply within the same chat arrives with no preview text at all. In a
  /// conversation the answer is almost always already on screen — the message
  /// being replied to is a few bubbles up — so this resolves it from the loaded
  /// page rather than asking the server. That is the whole point: the feed has
  /// to spend a `GetMessages` on this, and a conversation does not.
  ///
  /// [from] adds targets that are not in [messages] themselves: the rest of the
  /// conversation, for a message arriving live, or the ones fetched for a page
  /// whose replies point further back than it reaches.
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

  /// Who wrote a message, as a reply to it names them.
  ///
  /// "You" for your own, which Telegram says too — and which is the only name
  /// there can be in a one-to-one chat, where nobody else's name is put on a
  /// bubble. Null for somebody else there: the other person is the header.
  static String? replyAuthorOf(ChatMessage target) =>
      target.isOutgoing ? AppStrings.messagesYouPrefix : target.senderName;

  /// A message in one line, as a reply to it quotes it.
  ///
  /// Its words when it has them, otherwise what it *is*. A photo has no text,
  /// so a reply to one said "Replying to" and stopped.
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

  /// Rewrites a mapped message around a new content object.
  ///
  /// `updateMessageContent` hands over a bare content with no message around
  /// it, and it is how three separate things reach a bubble that is already on
  /// screen: a caption edit, a vote landing on a poll, and self-destructing
  /// media expiring into `messageExpiredPhoto`. Folding it through the same
  /// decoder the first mapping used is what stops those three from each needing
  /// their own partial copy of it — the previous version updated text and media
  /// and left the poll, the secret flag and the entities behind.
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

  /// Everything a bubble draws, read out of one content object.
  ///
  /// Public because [withContent] and [map] must agree: the two entry points
  /// into a bubble are the history page and the live update, and a decoder
  /// each is how they drift apart.
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
    // A poll is the whole message. It has no caption to read and no media to
    // extract, and it is the case the old decoder fell through — MessagePoll is
    // content the feed renders in full, so it carried no fallback label either,
    // and the bubble came out empty.
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

    // A place and a contact are cards, not captions. Both used to fall through
    // to the feed's label — "📍 Location" with the coordinates discarded — so
    // the one thing a location is for could not be done with one.
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
        // Everything else — a sticker, a location, a service notice — has no
        // words of its own, so it borrows the label the feed already gives it
        // rather than drawing an empty bubble. See MessageContentSupport.
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

  /// The place in a location or a venue message, or null for anything else.
  ///
  /// One function for both, because a venue is a location with a name on it and
  /// everything downstream draws them the same way with a line more.
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

  /// Whether this content is Telegram's tap-to-view kind and still covered.
  ///
  /// TDLib puts the flag on the content, not the message, and clears it when
  /// the media is opened — so this is "is it still hidden", not "was it ever
  /// secret". Only the four content types that can carry it are named; every
  /// other kind of message answers false without a `default` swallowing a type
  /// that grows the flag later.
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
    // 0 means "same chat". Carrying the chat's own id would make every reply
    // look like a cross-chat one.
    if (target.chatId == 0 || target.chatId == message.chatId) return null;
    return target.chatId;
  }

  static String? _replyExcerpt(td.Message message) {
    final target = _replyTarget(message);
    if (target == null) return null;

    // A quote is what the sender actually pointed at, so it wins over the whole
    // message when Telegram gives us one.
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
    // A channel's post and a message sent as a chat are named after that
    // chat. Only the signature was read before, which most channels do not
    // set — so a reply to one said "Replying to" and stopped.
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

  /// The line drawn for something that happened *to* a chat rather than being
  /// said in it — a join, a pin, a rename.
  ///
  /// Null for a kind with nothing worth saying, and the conversation leaves
  /// those out altogether (see `ConversationRows.build`). Every one of these
  /// used to be drawn as an empty padded line, so a public group — mostly
  /// joins — read as blank gaps under date headers with nothing in them.
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
