import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/domain/chat_filter.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';

/// Turns cached chats into the rows of the messages list, and filters them.
///
/// Pure by construction — every input is passed in — because this is where the
/// interesting decisions live: what counts as a bot, what counts as a request,
/// what a row says when there is a draft, and how the list is ordered. All of
/// that is worth a test, and none of it needs a TDLib client. `ChatCacheState`
/// is the pattern being copied.
///
/// Costs no requests. Everything it reads is already in [ChatCache], put there
/// by the update stream — see `docs/TDLIB.md`.
abstract class ChatListBuilder {
  /// Builds one row per chat.
  ///
  /// [selfUserId] is the only way to tell Saved Messages from a chat with
  /// somebody else: TDLib models it as a private chat with yourself. Null while
  /// the account record is loading, in which case that chat simply reads as a
  /// direct one.
  static List<ChatSummary> build(
    List<td.Chat> chats, {
    required Map<int, td.User> users,
    required Map<int, td.Supergroup> supergroups,
    int? selfUserId,

    /// Full user records, for the affiliated-channel badge. Only the ones
    /// TDLib has already volunteered — see [ChatSummary.affiliatedChannelId].
    Map<int, td.UserFullInfo> userFullInfos = const {},

    /// Every cached chat, keyed by id, so a personal chat id can be turned
    /// into a name and a picture without a lookup — and without a `GetChat`,
    /// which per row would be the fan-out this class exists to avoid.
    Map<int, td.Chat> chatsById = const {},
  }) {
    final rows = [
      for (final chat in chats)
        if (hasContent(chat))
          summaryFor(
            chat,
            users: users,
            supergroups: supergroups,
            selfUserId: selfUserId,
            userFullInfos: userFullInfos,
            chatsById: chatsById,
          ),
    ];
    rows.sort(compare);
    return rows;
  }

  /// Chats keyed by id, for resolving an affiliated channel without a request.
  static Map<int, td.Chat> byId(Iterable<td.Chat> chats) => {
    for (final chat in chats) chat.id: chat,
  };

  /// Newest activity first, which is TDLib's own `order` — and because Telegram
  /// expresses a pinned chat as a very high order, sorting by it pins the
  /// pinned chats for free, exactly where every other client puts them.
  ///
  /// Ties break on chat id rather than being left to the sort's stability, so
  /// two chats with no activity can't swap places between rebuilds under the
  /// reader's thumb.
  static int compare(ChatSummary a, ChatSummary b) {
    final byOrder = b.mainListOrder.compareTo(a.mainListOrder);
    if (byOrder != 0) return byOrder;

    final at = a.lastMessageAt;
    final bt = b.lastMessageAt;
    if (at != null && bt != null) {
      final byTime = bt.compareTo(at);
      if (byTime != 0) return byTime;
    } else if (at != bt) {
      return at == null ? 1 : -1;
    }
    return a.chatId.compareTo(b.chatId);
  }

  static ChatSummary summaryFor(
    td.Chat chat, {
    required Map<int, td.User> users,
    required Map<int, td.Supergroup> supergroups,
    int? selfUserId,
    Map<int, td.UserFullInfo> userFullInfos = const {},
    Map<int, td.Chat> chatsById = const {},
  }) {
    final type = chat.type;
    final user = type is td.ChatTypePrivate ? users[type.userId] : null;
    final supergroup = type is td.ChatTypeSupergroup
        ? supergroups[type.supergroupId]
        : null;

    final draft = chat.draftMessage;
    final draftText = draft == null ? null : _draftText(draft);

    // A draft wins the preview line: it is the thing the reader left unfinished,
    // and showing the last received message instead is how somebody forgets
    // they were mid-sentence with someone.
    final lastMessage = chat.lastMessage;
    final preview =
        draftText ??
        (lastMessage == null ? null : TdlibMappers.excerptOf(lastMessage));

    final fullInfo = type is td.ChatTypePrivate
        ? userFullInfos[type.userId]
        : null;
    final personalChatId = fullInfo?.personalChatId ?? 0;
    final personalChat = personalChatId == 0 ? null : chatsById[personalChatId];

    return ChatSummary(
      chatId: chat.id,
      title: chat.title,
      kind: kindOf(chat, user: user, selfUserId: selfUserId),
      username: _usernameOf(user: user, supergroup: supergroup),
      avatarPath: chat.photo?.small.local.path.isNotEmpty == true
          ? chat.photo!.small.local.path
          : null,
      avatarFileId: chat.photo?.small.id,
      avatarColorHex: TdlibMappers.avatarColorFor(chat.id),
      preview: preview,
      previewSender: draftText != null
          ? null
          : _previewSender(chat, lastMessage, users: users),
      previewIsDraft: draftText != null,
      // A draft has not been sent, so it has no delivery state — a tick beside
      // one would claim the other side had seen something nobody sent.
      previewSendState: draftText != null
          ? null
          : sendStateOf(chat, lastMessage),
      affiliatedChannelId: personalChatId == 0 ? null : personalChatId,
      affiliatedChannelTitle: personalChat?.title,
      affiliatedChannelAvatarPath:
          personalChat?.photo?.small.local.path.isNotEmpty == true
          ? personalChat!.photo!.small.local.path
          : null,
      affiliatedChannelAvatarFileId: personalChat?.photo?.small.id,
      affiliatedChannelAvatarColorHex: personalChatId == 0
          ? null
          : TdlibMappers.avatarColorFor(personalChatId),
      lastMessageAt: lastMessage == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastMessage.date * 1000),
      unreadCount: chat.unreadCount,
      isMarkedAsUnread: chat.isMarkedAsUnread,
      unreadMentionCount: chat.unreadMentionCount,
      unreadReactionCount: chat.unreadReactionCount,
      isMuted: isMuted(chat.notificationSettings),
      isVerified: user?.isVerified ?? supergroup?.isVerified ?? false,
      isRequest: isRequest(chat),
      presence: presenceOf(user),
      mainListOrder: ChatCacheState.mainListOrder(chat),
      isPinned: isPinned(chat),
    );
  }

  /// The tick beside the preview, for a last message this account sent.
  ///
  /// Null for anything incoming: the whole point of the mark is that it is a
  /// statement about *your* message, and a double tick on somebody else's
  /// would read as them having read their own words. The read cursor is the
  /// chat's `lastReadOutboxMessageId`, which is the same value the bubbles in
  /// the conversation use — so a row and the chat it opens cannot disagree.
  static MessageSendState? sendStateOf(td.Chat chat, td.Message? message) {
    if (message == null || !message.isOutgoing) return null;

    final sending = message.sendingState;
    if (sending is td.MessageSendingStateFailed) return MessageSendState.failed;
    if (sending is td.MessageSendingStatePending) {
      return MessageSendState.sending;
    }

    return message.id <= chat.lastReadOutboxMessageId
        ? MessageSendState.read
        : MessageSendState.sent;
  }

  /// Whether Telegram has this chat pinned to the top of the main list.
  ///
  /// Read off the main-list position specifically. A chat can be pinned in the
  /// archive and not in the main list, and treating those the same would put a
  /// pin marker on a row that is not pinned where the reader is looking.
  static bool isPinned(td.Chat chat) {
    for (final position in chat.positions) {
      if (position.list is td.ChatListMain) return position.isPinned;
    }
    return false;
  }

  /// Whether a chat has anything in it worth listing.
  ///
  /// Telegram creates a chat the moment it has *anything* to say about someone,
  /// conversation with them. Those arrive with `messageContactRegistered` as
  /// their only message and fill the list with people nobody has ever spoken
  /// to. Same for a chat with no last message at all.
  ///
  /// Deliberately narrow: only that one content type, and only when it is the
  /// *last* message, which for a chat containing nothing else it always is. The
  /// tempting generalisation — "hide any chat whose last message is a service
  /// notice" — would hide a real group the moment somebody changed its photo.
  static bool hasContent(td.Chat chat) {
    final last = chat.lastMessage;
    if (last == null) return false;
    if (last.content is td.MessageContactRegistered) return false;
    return true;
  }

  /// Which bucket a chat belongs in.
  ///
  /// A bot is a private chat whose user is one, so the user record is what
  /// decides — not the chat. Without it every bot reads as a person, and the
  /// reader gets "last seen recently" under a piece of software.
  static ChatKind kindOf(td.Chat chat, {td.User? user, int? selfUserId}) {
    final type = chat.type;
    if (type is td.ChatTypePrivate) {
      if (selfUserId != null && type.userId == selfUserId) {
        return ChatKind.savedMessages;
      }
      if (user?.type is td.UserTypeBot) return ChatKind.bot;
      return ChatKind.direct;
    }
    return ChatKind.group;
  }

  /// Whether notifications for this chat are silenced.
  ///
  /// `muteFor` is a number of seconds and zero means "not muted". When
  /// `useDefaultMuteFor` is set the chat follows the account-wide default,
  /// which this app does not read — so it reports unmuted rather than guessing,
  /// because a bell struck through is a claim about somebody's settings.
  static bool isMuted(td.ChatNotificationSettings settings) {
    if (settings.useDefaultMuteFor) return false;
    return settings.muteFor > 0;
  }

  /// Whether this chat is a message request.
  ///
  /// it has is the bar it raises over a chat from somebody who is not a
  /// contact — report / add contact / block — and that is the same population:
  /// a stranger who wrote to you first. A pending join request on a group is
  /// the group-shaped version of it.
  static bool isRequest(td.Chat chat) {
    final bar = chat.actionBar;
    return bar is td.ChatActionBarReportAddBlock ||
        bar is td.ChatActionBarJoinRequest;
  }

  static ChatPresence presenceOf(td.User? user) {
    if (user == null) return ChatPresence.unknown;
    // A bot's "status" is meaningless — it answers instantly and always — so
    // reporting one is noise dressed as information.
    if (user.type is td.UserTypeBot) return ChatPresence.unknown;

    return switch (user.status) {
      td.UserStatusOnline() => ChatPresence.online,
      td.UserStatusOffline() => ChatPresence.offline,
      td.UserStatusRecently() => ChatPresence.recently,
      td.UserStatusLastWeek() => ChatPresence.lastWeek,
      td.UserStatusLastMonth() => ChatPresence.lastMonth,
      _ => ChatPresence.unknown,
    };
  }

  /// Applies the header filter and the search box, in that order.
  ///
  /// [query] matches the title and the username, case-insensitively. It filters
  /// what is already loaded and issues no request, which is what makes typing
  /// in the search box free — see the per-keystroke rule in `docs/TDLIB.md`.
  static List<ChatSummary> filter(
    List<ChatSummary> rows, {
    ChatFilter filter = ChatFilter.all,
    String query = '',
  }) {
    final needle = query.trim().toLowerCase();

    return [
      for (final row in rows)
        if (matchesFilter(row, filter) && matchesQuery(row, needle)) row,
    ];
  }

  static bool matchesFilter(ChatSummary row, ChatFilter filter) =>
      switch (filter) {
        ChatFilter.all => true,
        ChatFilter.unread => row.unreadCount > 0 || row.isMarkedAsUnread,
        ChatFilter.direct => row.kind.isDirect,
        ChatFilter.groups => row.kind == ChatKind.group,
        ChatFilter.bots => row.kind == ChatKind.bot,
      };

  static bool matchesQuery(ChatSummary row, String needle) {
    if (needle.isEmpty) return true;
    if (row.title.toLowerCase().contains(needle)) return true;
    final username = row.username;
    return username != null && username.toLowerCase().contains(needle);
  }

  /// The number on the tab badge: chats with something unread, not messages.
  ///
  /// three people are waiting, which is the number a reader can act on.
  static int unreadChatCount(List<ChatSummary> rows) =>
      rows.where((r) => r.unreadCount > 0 || r.isMarkedAsUnread).length;

  static String? _usernameOf({td.User? user, td.Supergroup? supergroup}) {
    final names =
        user?.usernames?.activeUsernames ??
        supergroup?.usernames?.activeUsernames;
    if (names == null || names.isEmpty) return null;
    return names.first;
  }

  /// The "Ada: " prefix on a group's preview line.
  ///
  /// Only in groups, and never for your own messages — Telegram writes "You: "
  /// there, and so does this, because otherwise the last thing *you* said looks
  /// like something you received.
  static String? _previewSender(
    td.Chat chat,
    td.Message? message, {
    required Map<int, td.User> users,
  }) {
    if (message == null) return null;
    if (!ChatCacheState.isConversation(chat)) return null;
    if (chat.type is td.ChatTypePrivate) return null;
    if (message.isOutgoing) return 'You';

    final sender = message.senderId;
    if (sender is td.MessageSenderUser) {
      final user = users[sender.userId];
      if (user == null) return null;
      return displayNameOf(user);
    }
    // A channel posting into its discussion group, or an anonymous admin.
    return null;
  }

  /// A person's name as Telegram gives it: two fields, either of which can be
  /// empty. A deleted account has both, which is why the fallback exists.
  ///
  /// The rule itself moved to [TdlibMappers.userDisplayName] once the comment
  /// thread needed the same answer — a feature may not import another
  /// feature's data layer, and two copies of this would drift.
  static String displayNameOf(td.User user) =>
      TdlibMappers.userDisplayName(user);

  /// The text of an unsent draft, or null when it isn't a text draft.
  ///
  /// A draft can hold media, and TDLib models that as an input content this
  /// cannot turn into a line — showing nothing beats showing "InputMessagePhoto".
  static String? _draftText(td.DraftMessage draft) {
    final content = draft.inputMessageText;
    if (content is! td.InputMessageText) return null;
    final text = content.text.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.isEmpty ? null : text;
  }
}
