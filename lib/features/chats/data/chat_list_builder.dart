import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/data/chat_message_mapper.dart';
import 'package:gramx/features/chats/domain/chat_filter.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/message_content_support.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';

/// Turns cached chats into rows of the messages list, and filters them. Pure,
/// and costs no requests: everything it reads is already in [ChatCache].
abstract class ChatListBuilder {
  /// Builds one row per chat. [selfUserId] identifies Saved Messages, which
  /// TDLib models as a private chat with yourself; while it is null, that chat
  /// reads as a direct one.
  static List<ChatSummary> build(
    List<td.Chat> chats, {
    required Map<int, td.User> users,
    required Map<int, td.Supergroup> supergroups,
    int? selfUserId,

    /// Full user records TDLib has already sent, for the channel badge.
    Map<int, td.UserFullInfo> userFullInfos = const {},

    /// Cached chats by id, to name an affiliated channel without a request.
    Map<int, td.Chat> chatsById = const {},

    /// Secret chat records by secret chat id, read for their state.
    Map<int, td.SecretChat> secretChats = const {},
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
            secretChats: secretChats,
          ),
    ];
    rows.sort(compare);
    return rows;
  }

  /// Chats keyed by id, for resolving an affiliated channel without a request.
  static Map<int, td.Chat> byId(Iterable<td.Chat> chats) => {
    for (final chat in chats) chat.id: chat,
  };

  /// Newest activity first, by TDLib's `order`, which also puts pinned chats
  /// on top. Ties break on chat id so rows don't swap between rebuilds.
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
    Map<int, td.SecretChat> secretChats = const {},
  }) {
    final type = chat.type;
    // A secret chat carries the other person's id on its type, so it resolves
    // its user like a private chat.
    final user = switch (type) {
      td.ChatTypePrivate() => users[type.userId],
      td.ChatTypeSecret() => users[type.userId],
      _ => null,
    };
    final secret = type is td.ChatTypeSecret
        ? secretChats[type.secretChatId]
        : null;
    final supergroup = type is td.ChatTypeSupergroup
        ? supergroups[type.supergroupId]
        : null;

    final draft = chat.draftMessage;
    final draftText = draft == null ? null : _draftText(draft);

    // A draft takes over the preview line.
    final lastMessage = chat.lastMessage;
    // A service message (a join, a pin) has no excerpt, so it gets the line
    // the conversation draws for it.
    final lastIsService =
        lastMessage != null &&
        MessageContentSupport.isServiceMessage(lastMessage.content);
    final preview =
        draftText ??
        (lastMessage == null
            ? null
            : lastIsService
            ? ChatMessageMapper.serviceText(
                lastMessage,
                users: users,
                chats: chatsById,
              )
            : TdlibMappers.excerptOf(lastMessage));

    final fullInfo = type is td.ChatTypePrivate
        ? userFullInfos[type.userId]
        : null;
    final personalChatId = fullInfo?.personalChatId ?? 0;
    final personalChat = personalChatId == 0 ? null : chatsById[personalChatId];
    final kind = kindOf(chat, user: user, selfUserId: selfUserId);
    final isSaved = kind == ChatKind.savedMessages;

    return ChatSummary(
      chatId: chat.id,
      // TDLib titles this chat with your own name, which is easy to confuse
      // with a same-named channel when forwarding.
      title: isSaved ? AppStrings.savedMessagesTitle : chat.title,
      kind: kind,
      username: _usernameOf(user: user, supergroup: supergroup),
      avatarPath: chat.photo?.small.local.path.isNotEmpty == true
          ? chat.photo!.small.local.path
          : null,
      avatarFileId: chat.photo?.small.id,
      avatarColorHex: TdlibMappers.avatarColorFor(chat.id),
      preview: preview,
      previewSender: draftText != null || lastIsService
          ? null
          : _previewSender(chat, lastMessage, users: users),
      previewIsDraft: draftText != null,
      // A draft has no delivery state.
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
      // Saved Messages shows no Premium mark, emoji status or presence.
      isPremium: !isSaved && (user?.isPremium ?? false),
      emojiStatusId: isSaved ? null : emojiStatusOf(user),
      isRequest: isRequest(chat),
      presence: isSaved ? ChatPresence.unknown : presenceOf(user),
      mainListOrder: ChatCacheState.mainListOrder(chat),
      isPinned: isPinned(chat),
      isSecret: type is td.ChatTypeSecret,
      isSecretPending:
          type is td.ChatTypeSecret &&
          !ChatCacheState.isSecretChatReady(secret),
    );
  }

  /// The tick beside the preview for an outgoing last message (from
  /// `lastReadOutboxMessageId`); null for incoming ones.
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

  /// Whether this chat is pinned in the main list (not just the archive).
  static bool isPinned(td.Chat chat) {
    for (final position in chat.positions) {
      if (position.list is td.ChatListMain) return position.isPinned;
    }
    return false;
  }

  /// Whether a chat is worth listing. Hides chats with no last message, or
  /// whose last message is a "joined Telegram" notice
  /// (`messageContactRegistered`). Other service messages still count.
  static bool hasContent(td.Chat chat) {
    final last = chat.lastMessage;
    if (last == null) return false;
    if (last.content is td.MessageContactRegistered) return false;
    return true;
  }

  /// Which bucket a chat belongs in. Bots are told apart by the user record,
  /// not the chat.
  static ChatKind kindOf(td.Chat chat, {td.User? user, int? selfUserId}) {
    final type = chat.type;
    // A secret chat counts as `direct`, so presence and the profile header
    // work as for a private chat.
    if (type is td.ChatTypeSecret) return ChatKind.direct;
    if (type is td.ChatTypePrivate) {
      if (selfUserId != null && type.userId == selfUserId) {
        return ChatKind.savedMessages;
      }
      if (user?.type is td.UserTypeBot) return ChatKind.bot;
      return ChatKind.direct;
    }
    return ChatKind.group;
  }

  /// Whether notifications for this chat are silenced. A chat on the
  /// account-wide default reads as unmuted, since that default isn't loaded.
  static bool isMuted(td.ChatNotificationSettings settings) {
    if (settings.useDefaultMuteFor) return false;
    return settings.muteFor > 0;
  }

  /// Whether this chat is a message request: one with Telegram's non-contact
  /// bar (report, add contact, block) or a join request bar.
  static bool isRequest(td.Chat chat) {
    final bar = chat.actionBar;
    return bar is td.ChatActionBarReportAddBlock ||
        bar is td.ChatActionBarJoinRequest;
  }

  static ChatPresence presenceOf(td.User? user) {
    if (user == null) return ChatPresence.unknown;
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

  /// Applies the header filter, then [query] against title and username
  /// (case-insensitive). Works on loaded rows only, with no requests.
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

  /// The custom emoji [user] shows instead of the Premium star, or null. TDLib
  /// keeps an expired status on the record, so the expiry is checked here.
  static int? emojiStatusOf(td.User? user, {DateTime? now}) {
    final status = user?.emojiStatus;
    if (user == null || !user.isPremium || status == null) return null;
    if (status.customEmojiId == 0) return null;
    final expires = status.expirationDate;
    if (expires != 0) {
      final at = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
      if (expires <= at) return null;
    }
    return status.customEmojiId;
  }

  /// The tab badge: the number of unread chats (not messages) that [filter]
  /// lets through.
  static int unreadChatCount(
    List<ChatSummary> rows, {
    ChatFilter filter = ChatFilter.all,
  }) => rows
      .where(
        (r) =>
            matchesFilter(r, filter) &&
            (r.unreadCount > 0 || r.isMarkedAsUnread),
      )
      .length;

  static String? _usernameOf({td.User? user, td.Supergroup? supergroup}) {
    final names =
        user?.usernames?.activeUsernames ??
        supergroup?.usernames?.activeUsernames;
    if (names == null || names.isEmpty) return null;
    return names.first;
  }

  /// The "Ada: " prefix on a group's preview line, or "You" for your own
  /// messages.
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

  /// A person's display name, via [TdlibMappers.userDisplayName].
  static String displayNameOf(td.User user) =>
      TdlibMappers.userDisplayName(user);

  /// The text of an unsent draft, or null when it isn't a text draft.
  static String? _draftText(td.DraftMessage draft) {
    final content = draft.inputMessageText;
    if (content is! td.InputMessageText) return null;
    final text = content.text.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.isEmpty ? null : text;
  }
}
