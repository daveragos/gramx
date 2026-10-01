import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:gramx/features/chats/domain/message_place.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/poll.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

/// Where a message is on its way to Telegram. `SendMessage` returns once the
/// message is queued, so [sending] covers the time until the server confirms.
enum MessageSendState {
  /// Queued locally, not acknowledged by the server yet.
  sending,

  /// Accepted by Telegram, not yet read by the recipient.
  sent,

  /// Behind the chat's outbox read cursor: the other side has seen it.
  read,

  /// Telegram refused it and will not retry.
  failed,
}

/// One bubble in a conversation. Separate from `Post`, but shares its media
/// and entity models so the same renderers draw both.
@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    /// `"<chatId>_<messageId>"`, the same key shape the rest of the app uses.
    required String id,
    required int chatId,
    required int messageId,

    /// Album members share this. Zero when the message stands alone.
    @Default(0) int mediaAlbumId,

    /// True when this account sent it.
    required bool isOutgoing,

    /// Who sent it. Null for a message from an anonymous admin or a channel
    /// posting into its discussion group.
    int? senderId,

    /// The sender's display name. Only drawn in groups.
    String? senderName,
    String? senderAvatarPath,
    int? senderAvatarFileId,
    String? senderAvatarColorHex,
    String? text,
    @Default([]) List<TextEntity> entities,
    @Default([]) List<MediaItem> media,

    /// The poll this message is, if it is one.
    @JsonKey(fromJson: _pollFromJson, toJson: _pollToJson) Poll? poll,

    /// A place somebody sent: a location, or a venue with a name on it.
    @JsonKey(fromJson: _placeFromJson, toJson: _placeToJson)
    MessagePlace? place,

    /// A contact card somebody sent.
    @JsonKey(fromJson: _contactFromJson, toJson: _contactToJson)
    MessageContactCard? contact,

    /// True while this message's media is Telegram's tap-to-view kind and has
    /// not been opened. The bubble draws a cover instead of the picture.
    @Default(false) bool isSecretMedia,

    /// True when the media is "view once": gone when the viewer closes it.
    /// Mutually exclusive with [selfDestructSeconds].
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
    /// Telegram allows replies across chats.
    int? replyToChatId,
    int? replyToThumbnailFileId,

    /// The forwarded message's origin as Telegram names it. Null when hidden.
    String? forwardedFromTitle,
    String? linkPreviewUrl,
    String? linkPreviewTitle,
    String? linkPreviewDescription,
    int? linkPreviewFileId,

    /// Whether this message is pinned in the chat. Changes arrive on
    /// `updateMessageIsPinned`, not as a content change.
    @Default(false) bool isPinned,

    /// Telegram's own notice about the chat ("you joined", "photo changed").
    /// Drawn as a centred line instead of a bubble.
    @Default(false) bool isService,

    /// The TDLib type name of content this build cannot draw, so the bubble
    /// can offer to open it in Telegram.
    String? unsupportedKind,
  }) = _ChatMessage;

  const ChatMessage._();

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);

  /// Whether the bubble has media. A media bubble drops its padding so the
  /// picture reaches the edges.
  bool get hasMedia => media.isNotEmpty;

  /// Media with no text, drawn without a bubble around it.
  bool get isMediaOnly => hasMedia && (text == null || text!.isEmpty);

  /// Whether this message's media disappears after it is opened, either view
  /// once or on a countdown.
  bool get selfDestructs => isViewOnce || selfDestructSeconds > 0;
}

// Never persisted, but `json_serializable` needs a converter for every field.
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
