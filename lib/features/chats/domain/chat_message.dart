import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

/// Where a message is on its way to Telegram.
///
/// `SendMessage` answers as soon as the message is queued, not when it lands —
/// see `docs/TDLIB.md` — so a bubble has to be able to say "on its way" rather
/// than claiming delivery it cannot know about. [failed] is a real state a
/// reader can act on: Telegram rejected it, and it will not retry itself.
enum MessageSendState {
  /// Queued locally, not acknowledged by the server yet.
  sending,

  /// Accepted by Telegram, not yet read by the recipient.
  sent,

  /// Behind the chat's outbox read cursor — the other side has seen it.
  read,

  /// Telegram refused it.
  failed,
}

/// One bubble in a conversation.
///
/// Deliberately its own model rather than a reuse of `Post`. A post is a
/// broadcast with view counts, a channel byline and a bookmark; a message is a
/// two-sided thing with a send state, a per-message sender and an edit history.
/// Bending one into the other would put six always-null fields on every bubble
/// and a send state on every feed card.
///
/// Content that both share — media, entities — uses the same models, so the
/// existing renderers work untouched.
@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    /// `"<chatId>_<messageId>"`, the same key shape the rest of the app uses.
    required String id,
    required int chatId,
    required int messageId,

    /// Album members share this. Zero when the message stands alone.
    @Default(0) int mediaAlbumId,

    /// True when this account sent it. Decides which side the bubble sits on,
    /// and whether a send state is drawn at all.
    required bool isOutgoing,

    /// Who sent it. Null for a message from an anonymous admin or a channel
    /// posting into its discussion group.
    int? senderId,

    /// The sender's display name. Only drawn in groups — in a private chat the
    /// two possible senders are the two people looking at it.
    String? senderName,
    String? senderAvatarPath,
    int? senderAvatarFileId,
    String? senderAvatarColorHex,
    String? text,
    @Default([]) List<TextEntity> entities,
    @Default([]) List<MediaItem> media,
    required DateTime sentAt,

    /// When Telegram says the message was edited, if it was.
    DateTime? editedAt,
    @Default(MessageSendState.sent) MessageSendState sendState,
    @Default({}) Map<String, int> reactions,
    @Default({}) Set<String> chosenReactions,

    /// The message this one replies to, when there is one.
    int? replyToMessageId,
    String? replyToText,
    String? replyToAuthorName,

    /// The chat the replied-to message lives in, when it isn't this one.
    /// Telegram allows replies across chats, and assuming otherwise sends the
    /// reader to a message id in the wrong chat.
    int? replyToChatId,
    int? replyToThumbnailFileId,

    /// Where a forwarded message came from, as Telegram will name it. Null
    /// when the origin is hidden, which Telegram allows.
    String? forwardedFromTitle,
    String? linkPreviewUrl,
    String? linkPreviewTitle,
    String? linkPreviewDescription,
    int? linkPreviewFileId,

    /// Telegram's own notice about the chat — "you joined", "photo changed".
    /// Drawn as a centred line rather than a bubble, the way every Telegram
    /// client does it, so it reads as narration and not as something somebody
    /// said.
    @Default(false) bool isService,

    /// Set when Telegram sent content this build cannot draw: the TDLib type
    /// name, so the bubble can offer Telegram rather than showing an empty box.
    String? unsupportedKind,
  }) = _ChatMessage;

  const ChatMessage._();

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);

  /// Whether the bubble has anything but text in it. Decides the layout, since
  /// a media bubble drops its padding and lets the picture reach the edges.
  bool get hasMedia => media.isNotEmpty;

  /// no bubble at all — the media *is* the message.
  bool get isMediaOnly => hasMedia && (text == null || text!.isEmpty);
}
