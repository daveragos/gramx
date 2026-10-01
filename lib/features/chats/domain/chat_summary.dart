import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:gramx/features/chats/domain/chat_message.dart';

part 'chat_summary.freezed.dart';
part 'chat_summary.g.dart';

/// What sort of conversation a row in the chat list is. Bots are private chats
/// in TDLib but get their own kind here.
enum ChatKind {
  /// The private chat with yourself (Saved Messages).
  savedMessages,

  /// A one-to-one chat with another person.
  direct,

  /// A one-to-one chat with a bot.
  bot,

  /// A basic group or a supergroup that is not a broadcast channel.
  group;

  /// Whether this kind counts as "Direct" in the filter menu. Bots are not
  /// direct; they have their own filter.
  bool get isDirect =>
      this == ChatKind.direct || this == ChatKind.savedMessages;
}

/// Whether the other side is around. An enum, since a hidden last-seen time
/// only comes through as a bucket such as [recently].
enum ChatPresence {
  online,
  offline,
  recently,
  lastWeek,
  lastMonth,

  /// No status at all: a group, a bot, or a user TDLib hasn't described yet.
  unknown,
}

/// One row of the chat list, built only from [ChatCache] so drawing the list
/// costs no TDLib requests.
@freezed
abstract class ChatSummary with _$ChatSummary {
  const factory ChatSummary({
    required int chatId,
    required String title,
    required ChatKind kind,
    String? username,
    String? avatarPath,
    int? avatarFileId,
    String? avatarColorHex,

    /// The one-line preview under the title, already collapsed by
    /// `TdlibMappers.excerptOf`.
    String? preview,

    /// The sender's name, prefixed to [preview] in a group ("Ada: on my way").
    /// Null in a private chat.
    String? previewSender,

    /// Set when [preview] is an unsent draft rather than a received message.
    @Default(false) bool previewIsDraft,

    /// Delivery state of the last message, only when this account sent it.
    /// Uses the same state as the bubbles so the row and the conversation agree.
    MessageSendState? previewSendState,

    /// The user's personal channel, shown as a badge on the row. Read only
    /// from the cached `UserFullInfo`, never fetched per row.
    int? affiliatedChannelId,
    String? affiliatedChannelTitle,
    String? affiliatedChannelAvatarPath,
    int? affiliatedChannelAvatarFileId,
    String? affiliatedChannelAvatarColorHex,
    DateTime? lastMessageAt,
    @Default(0) int unreadCount,

    /// Marked unread by hand. It carries no count, so a row checking only
    /// [unreadCount] would show it as read.
    @Default(false) bool isMarkedAsUnread,
    @Default(0) int unreadMentionCount,

    /// Unseen reactions to this account's own messages. Comes on the update
    /// stream like [unreadMentionCount], and feeds the Activity screen.
    @Default(0) int unreadReactionCount,
    @Default(false) bool isMuted,
    @Default(false) bool isVerified,

    /// A Telegram Premium account. The row shows the Premium star, never
    /// [emojiStatusId], to keep the list easy to scan.
    @Default(false) bool isPremium,

    /// The unexpired custom emoji a Premium account shows in place of the star.
    /// Used in the conversation header only.
    int? emojiStatusId,

    /// A chat from somebody not in the user's contacts, the kind Telegram
    /// shows its "report / add / block" bar on.
    @Default(false) bool isRequest,
    @Default(ChatPresence.unknown) ChatPresence presence,

    /// TDLib's ordering value for the main chat list. Pinned chats get a very
    /// high order, so sorting by this puts them first.
    @Default(0) int mainListOrder,

    /// Pinned in the main chat list, so the row can show a pin.
    @Default(false) bool isPinned,

    /// An end-to-end encrypted chat, drawn with a lock.
    @Default(false) bool isSecret,

    /// True while a secret chat's key exchange is pending. Telegram refuses
    /// messages until the other device comes online.
    @Default(false) bool isSecretPending,
  }) = _ChatSummary;

  factory ChatSummary.fromJson(Map<String, dynamic> json) =>
      _$ChatSummaryFromJson(json);
}
