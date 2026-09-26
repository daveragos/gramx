import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:gramx/features/chats/domain/message_place.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/poll.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

/// Where a message is on its way to Telegram.
///
/// `SendMessage` answers as soon as the message is queued, not when it lands —
/// so a bubble has to be able to say "on its way" rather
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

    /// The poll this message is, if it is one.
    ///
    /// Carried rather than flattened to its question text. A poll bubble used
    /// to render as an empty box: `MessagePoll` is content the feed draws in
    /// full, so it had no fallback label to borrow, and nothing here knew what
    /// to do with it — a message with no words, no media and no poll is a
    /// bubble with nothing in it.
    @JsonKey(fromJson: _pollFromJson, toJson: _pollToJson) Poll? poll,

    /// A place somebody sent: a location, or a venue with a name on it.
    ///
    /// Drawn as a card rather than reduced to the words "📍 Location", which
    /// is what a conversation showed for one — a label with the coordinates
    /// thrown away, so the one thing a location is for could not be done with
    /// it.
    @JsonKey(fromJson: _placeFromJson, toJson: _placeToJson) MessagePlace? place,

    /// A contact card somebody sent.
    @JsonKey(fromJson: _contactFromJson, toJson: _contactToJson)
    MessageContactCard? contact,

    /// True while this message's media is Telegram's tap-to-view kind and has
    /// not been opened. The bubble draws a cover rather than the picture, which
    /// is the whole point of it.
    @Default(false) bool isSecretMedia,

    /// True when the media is "view once": gone when the viewer closes it,
    /// however long they looked. Mutually exclusive with
    /// [selfDestructSeconds] — Telegram's type is one or the other.
    @Default(false) bool isViewOnce,

    /// How long the viewer gets once they open it, in seconds. Zero for
    /// [isViewOnce] media and for anything that does not self-destruct.
    @Default(0) int selfDestructSeconds,
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

    /// Whether this message is pinned to the top of the chat.
    ///
    /// Read so the long-press menu can offer the right one of Pin and Unpin.
    /// It arrives on `updateMessageIsPinned` rather than as a content change,
    /// because nothing about the message itself moved.
    @Default(false) bool isPinned,

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

  /// Whether this message's media disappears after it is opened.
  ///
  /// True for both shapes — view once and a countdown — because every caller
  /// that asks wants the same answer: draw a cover, not the picture.
  bool get selfDestructs => isViewOnce || selfDestructSeconds > 0;
}

/// A place round-trips through a plain map. It is never actually persisted —
/// nothing writes a `ChatMessage` to disk — but `json_serializable` generates
/// a converter call for every field, so one has to exist.
MessagePlace? _placeFromJson(dynamic json) {
  if (json == null) return null;
  final map = json as Map<String, dynamic>;
  return MessagePlace(
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
    title: map['title'] as String?,
    address: map['address'] as String?,
    livePeriod: map['livePeriod'] as int? ?? 0,
    expiresIn: map['expiresIn'] as int? ?? 0,
  );
}

Map<String, dynamic>? _placeToJson(MessagePlace? place) => place == null
    ? null
    : {
        'latitude': place.latitude,
        'longitude': place.longitude,
        'title': place.title,
        'address': place.address,
        'livePeriod': place.livePeriod,
        'expiresIn': place.expiresIn,
      };

MessageContactCard? _contactFromJson(dynamic json) {
  if (json == null) return null;
  final map = json as Map<String, dynamic>;
  return MessageContactCard(
    firstName: map['firstName'] as String? ?? '',
    lastName: map['lastName'] as String? ?? '',
    phoneNumber: map['phoneNumber'] as String? ?? '',
    userId: map['userId'] as int? ?? 0,
  );
}

Map<String, dynamic>? _contactToJson(MessageContactCard? contact) =>
    contact == null
    ? null
    : {
        'firstName': contact.firstName,
        'lastName': contact.lastName,
        'phoneNumber': contact.phoneNumber,
        'userId': contact.userId,
      };

Poll? _pollFromJson(dynamic json) =>
    json == null ? null : Poll.fromJson(json as Map<String, dynamic>);

Map<String, dynamic>? _pollToJson(Poll? poll) =>
    poll == null ? null : (poll as dynamic).toJson() as Map<String, dynamic>;
