import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:gramx/features/chats/domain/chat_message.dart';

part 'chat_summary.freezed.dart';
part 'chat_summary.g.dart';

/// What sort of conversation a row in the chat list is.
///
/// Ordered the way the filter menu reads it: your own notes first, then people,
/// then bots, then rooms with more than one person in them. A bot is a private
/// chat in TDLib's model, and it is split out here because the reader treats one
/// differently from a person — it is the difference between a conversation and
/// a tool.
enum ChatKind {
  /// The private chat with yourself. Telegram's notes-to-self.
  savedMessages,

  /// A one-to-one chat with another person.
  direct,

  /// A one-to-one chat with a bot.
  bot,

  /// A basic group or a supergroup that is not a broadcast channel.
  group;

  /// Whether this kind counts as "Direct" in the filter menu.
  ///
  /// A bot is deliberately **not** direct. It is a private chat in Telegram's
  /// model, but it is not a person, and Bots is its own filter — folding them
  /// in here would leave that filter's contents also showing up under Direct,
  /// which makes both of them mean less.
  bool get isDirect =>
      this == ChatKind.direct || this == ChatKind.savedMessages;
}

/// Whether the other side is around, as far as Telegram will say.
///
/// Telegram deliberately blurs this — a contact who hides their last-seen time
/// reports [recently] rather than a timestamp — so this is an enum rather than
/// a `DateTime?`. Rendering "last seen recently" from a null date is how a
/// privacy setting turns into a lie about someone being offline.
enum ChatPresence {
  online,
  offline,
  recently,
  lastWeek,
  lastMonth,

  /// No status at all: a group, a bot, or a user TDLib hasn't described yet.
  unknown,
}

/// One row of the chat list.
///
/// Built entirely from what [ChatCache] already holds, so drawing the whole
/// list costs zero TDLib requests — see `docs/TDLIB.md`. Nothing here is
/// fetched per-chat; if a field cannot be answered from the cache it is null
/// and the row draws without it.
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

    /// The one-line preview under the title. Already collapsed to a single
    /// line by `TdlibMappers.excerptOf`.
    String? preview,

    /// The sender's name, prefixed to [preview] in a group — "Ada: on my way".
    /// Null in a private chat, where the only two possible senders are obvious.
    String? previewSender,

    /// Set when [preview] is an unsent draft rather than a received message.
    /// something you already said otherwise.
    @Default(false) bool previewIsDraft,

    /// Delivery state of the last message, when **this account** sent it.
    ///
    /// Null in every other case — a message from the other side, a draft, an
    /// empty chat — because the tick is a claim about your own message, and
    /// drawing one over somebody else's says they read their own words. It is
    /// the same state the bubbles use, so a row and the conversation it opens
    /// cannot disagree about whether something has been read.
    MessageSendState? previewSendState,

    /// The channel this person runs, when Telegram has said so.
    ///
    /// Telegram calls it a *personal chat*: a channel a user pins to their own
    /// it is shown in the same place for the same reason — who somebody speaks
    /// for is part of who they are.
    ///
    /// **Only ever read from what is already cached.** It lives on
    /// `UserFullInfo`, which TDLib volunteers through `UpdateUserFullInfo` for
    /// users it has loaded fully and otherwise costs one `GetUserFullInfo` per
    /// user — and a request per row down a scrolling list is precisely the
    /// fan-out `docs/TDLIB.md` forbids. So the badge appears for people whose
    /// profile the reader has actually opened, and is simply absent otherwise.
    ///
    /// The title is carried for the label and the tooltip rather than for the
    /// row: the badge is the channel's *picture*, because a second name beside
    /// somebody's own name is two names competing for one line, and the row
    /// already has a timestamp and a pin to fit.
    int? affiliatedChannelId,
    String? affiliatedChannelTitle,
    String? affiliatedChannelAvatarPath,
    int? affiliatedChannelAvatarFileId,
    String? affiliatedChannelAvatarColorHex,
    DateTime? lastMessageAt,
    @Default(0) int unreadCount,

    /// Someone marked the chat unread by hand. It carries no count, so a row
    /// showing only [unreadCount] renders it as read.
    @Default(false) bool isMarkedAsUnread,
    @Default(0) int unreadMentionCount,

    /// How many reactions to this account's own messages are still unseen.
    ///
    /// Arrives free on the update stream, exactly like [unreadMentionCount].
    /// It is what the Activity screen counts as "somebody reacted to you",
    @Default(0) int unreadReactionCount,
    @Default(false) bool isMuted,
    @Default(false) bool isVerified,

    /// A chat from somebody not in the reader's contacts — Telegram raises its
    /// "report / add / block" bar for these. It is the nearest thing Telegram
    @Default(false) bool isRequest,
    @Default(ChatPresence.unknown) ChatPresence presence,

    /// TDLib's own ordering value for the main chat list. Carried so the list
    /// can sort exactly the way every other Telegram client does — pinned
    /// chats included, since Telegram expresses a pin as a very high order.
    @Default(0) int mainListOrder,

    /// Pinned to the top of the main chat list.
    ///
    /// The ordering already follows from [mainListOrder] — Telegram expresses a
    /// pin as a very high order — but the *reason* a chat is at the top does
    /// not, and without saying so a pinned chat is indistinguishable from a
    /// busy one.
    @Default(false) bool isPinned,
  }) = _ChatSummary;

  factory ChatSummary.fromJson(Map<String, dynamic> json) =>
      _$ChatSummaryFromJson(json);
}
