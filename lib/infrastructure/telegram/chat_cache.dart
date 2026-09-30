import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/core/diagnostics/startup_trace.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';
import 'package:handy_tdlib/api.dart' as td;

/// One of Telegram's per-kind send permissions.
///
/// Telegram does not have a single "may write here" flag: a group can allow
/// photos and forbid voice messages, and each of those is its own bit on
/// `chatPermissions`. Naming them as a type is what lets one function answer
/// for all of them without six near-identical copies.
/// One kind of thing a chat may or may not take. [stickers] covers GIFs too:
/// Telegram files both under one permission, "other messages", alongside
/// games and inline bots.
enum ChatSendRight {
  photos,
  videos,
  documents,
  voiceNotes,
  videoNotes,
  polls,
  stickers,
}

/// The chat map and the rules for folding TDLib updates into it.
///
/// Pure state with no I/O, so the folding logic — which is where the subtle
/// cold-start bugs live — is testable without a TDLib client.
class ChatCacheState {
  final Map<int, td.Chat> chats = {};

  /// Supergroup records keyed by supergroup id (not chat id).
  ///
  /// TDLib volunteers these through `UpdateSupergroup`, and they carry the
  /// member count, verified flag and username that the channel list shows — so
  /// mirroring them removes a `GetSupergroup` per channel.
  final Map<int, td.Supergroup> supergroups = {};

  /// User records keyed by user id.
  ///
  /// TDLib volunteers these through `UpdateUser` for every user it loads a chat
  /// for, so a private chat's name, username, verified flag, bot-ness and
  /// online status are all already here — mirroring them is what lets the chat
  /// list draw without a `GetUser` per row, which would be the same per-chat
  /// fan-out the request budget forbids.
  final Map<int, td.User> users = {};

  /// Full user records, keyed by user id.
  ///
  /// What TDLib has volunteered — `UpdateUserFullInfo` arrives for users the
  /// client has loaded fully, which happens when a profile or a conversation
  /// is opened — plus what `AffiliationPrefetcher` has asked for one row at a
  /// time as the messages list is scrolled. **Nothing here ever asks for
  /// one**, and nothing asks for the whole list's worth at once: a
  /// `GetUserFullInfo` per row of the chat list, all together, is the
  /// per-chat fan-out the request budget exists to forbid. Anything read from
  /// this map has to be optional in the UI for that reason.
  final Map<int, td.UserFullInfo> userFullInfos = {};

  /// Secret chat records keyed by **secret chat id**, not chat id.
  ///
  /// TDLib volunteers these through `UpdateSecretChat`, and they carry the one
  /// thing a `td.Chat` does not: the state. A secret chat is *pending* until
  /// the other device comes online and the key exchange finishes, and messages
  /// sent into a pending one are refused — so a client that cannot tell pending
  /// from ready offers a composer that silently fails.
  final Map<int, td.SecretChat> secretChats = {};

  /// `UpdateChatLastMessage` can arrive before the `UpdateNewChat` that
  /// introduces its chat. Stash those and flush them when the chat lands,
  /// otherwise the newest post of a channel is silently dropped on cold start.
  final Map<int, td.UpdateChatLastMessage> pendingLastMessages = {};

  /// Every cached chat, most recently active first.
  ///
  /// Includes groups and private chats, which the feed ignores but the forward
  /// picker needs — and they are already here, so listing them costs nothing.
  List<td.Chat> get allChats {
    final list = chats.values.toList();
    list.sort((a, b) => mainListOrder(b).compareTo(mainListOrder(a)));
    return list;
  }

  /// Broadcast channels the user is actually subscribed to, most recent first.
  ///
  /// Membership matters as much as type here. TDLib emits `UpdateNewChat` for
  /// *any* chat it learns about, not just ones the user joined — resolving a
  /// forwarded post's origin, or searching public channels, both pull strangers
  /// into the cache. Without the [isSubscribed] check their posts end up in the
  /// feed, which is how a channel nobody follows starts appearing in it.
  List<td.Chat> get channels {
    final list = chats.values
        .where((c) => isChannel(c) && isSubscribed(c))
        .toList();
    list.sort((a, b) => mainListOrder(b).compareTo(mainListOrder(a)));
    return list;
  }

  /// Whether [channels] would be non-empty, without building it.
  ///
  /// Asked once per chat update while the list loads — thousands of times on
  /// an account with a long chat list — so it stops at the first channel
  /// rather than filtering and sorting every chat to learn one bit.
  bool get hasChannels =>
      chats.values.any((c) => isChannel(c) && isSubscribed(c));

  /// Everything that is a conversation rather than a broadcast: private chats,
  /// bot chats, basic groups, non-broadcast supergroups and secret chats. Most
  /// recent first.
  List<td.Chat> get conversations {
    final list = chats.values
        .where((c) => isConversation(c) && isSubscribed(c))
        .toList();
    list.sort((a, b) => mainListOrder(b).compareTo(mainListOrder(a)));
    return list;
  }

  /// Whether a chat belongs in the messages list. Pure, so the rule is testable
  /// without a client.
  static bool isConversation(td.Chat chat) {
    final type = chat.type;
    if (type is td.ChatTypePrivate) return true;
    if (type is td.ChatTypeBasicGroup) return true;
    if (type is td.ChatTypeSecret) return true;
    if (type is td.ChatTypeSupergroup) return !type.isChannel;
    // Anything a future TDLib adds: not ours to draw.
    return false;
  }

  /// The secret chat behind a chat, if it is one and TDLib has described it.
  td.SecretChat? secretChatFor(td.Chat chat) {
    final type = chat.type;
    if (type is! td.ChatTypeSecret) return null;
    return secretChats[type.secretChatId];
  }

  /// Whether a secret chat's key exchange has finished.
  ///
  /// The state lives on the `SecretChat` record, not on the `Chat`, and it is
  /// the difference between a composer that works and one that is refused: a
  /// chat stays *pending* until the other device comes online, which can be
  /// hours.
  static bool isSecretChatReady(td.SecretChat? secret) =>
      secret?.state is td.SecretChatStateReady;

  /// The user record behind a private chat, if TDLib has volunteered it.
  td.User? userForChat(td.Chat chat) {
    final type = chat.type;
    if (type is! td.ChatTypePrivate) return null;
    return users[type.userId];
  }

  /// Whether the user is a member of this chat.
  ///
  /// A chat list position is the signal: TDLib places a chat in Main or Archive
  /// only for chats the user is in. A chat merely resolved by id has none.
  static bool isSubscribed(td.Chat chat) => chat.positions.isNotEmpty;

  /// A chat's sort order within the main chat list, or 0 if it isn't in it.
  static int mainListOrder(td.Chat chat) {
    for (final position in chat.positions) {
      if (position.list is td.ChatListMain) return position.order;
    }
    return 0;
  }

  static bool isChannel(td.Chat chat) {
    final type = chat.type;
    return type is td.ChatTypeSupergroup && type.isChannel;
  }

  /// Chats this account can actually post into.
  ///
  /// The forward picker used to list every chat in the cache, which is mostly
  /// broadcast channels the reader only subscribes to — picking one failed, or
  /// silently did nothing. The rules mirror Telegram's own:
  ///
  /// * private chats and saved messages always work;
  /// * a group works if members may send messages, or if you run it;
  /// * a channel only works if you can post to it, which means being its
  ///   creator or an admin with posting rights.
  ///
  /// Chats the user is not in are excluded outright — they are in the cache
  /// only because something resolved them by id.
  List<td.Chat> get forwardTargets {
    final list = chats.values
        .where((c) => isSubscribed(c) && canPostIn(c, supergroupForChat(c)))
        .toList();
    list.sort((a, b) => mainListOrder(b).compareTo(mainListOrder(a)));
    return list;
  }

  /// Whether a message can be sent into [chat]. Pure, so the rules are testable.
  static bool canPostIn(td.Chat chat, td.Supergroup? supergroup) {
    final type = chat.type;

    if (type is td.ChatTypePrivate) return true;
    // A secret chat takes messages only once its key exchange has finished.
    // Before that Telegram refuses the send, so the composer must not offer
    // one. `canPostIn` has no secret chat record to consult — the forward
    // picker deliberately still excludes them, because a forwarded channel post
    // cannot go into one at all.
    if (type is td.ChatTypeSecret) return false;

    // Basic groups: the cache holds no BasicGroup record, so the chat's
    // default permissions are all there is to go on.
    if (type is td.ChatTypeBasicGroup) {
      return chat.permissions.canSendBasicMessages;
    }

    if (type is td.ChatTypeSupergroup) {
      final status = supergroup?.status;
      if (type.isChannel) return _canPostAsAdmin(status);
      return chat.permissions.canSendBasicMessages || _canPostAsAdmin(status);
    }

    return false;
  }

  /// Whether one kind of thing may be sent into [chat]. Pure, so the rules are
  /// testable.
  ///
  /// Telegram permissions media by *kind*, and a group can permit one and
  /// forbid the next — photos allowed, voice messages not, is a common setting.
  /// So this is one function with a right rather than a bool per control, and
  /// it is held here rather than at the repositories that ask, because a second
  /// copy is how the composer and the conversation come to disagree about which
  /// buttons belong.
  ///
  /// A private chat allows everything except a poll, which Telegram takes only
  /// in a chat with a bot. A channel is an admin question. A group is the
  /// chat's own permission, or admin rights over it.
  static bool canSendIn(
    td.Chat chat,
    td.Supergroup? supergroup,
    ChatSendRight right,
  ) {
    final type = chat.type;
    // A secret chat takes every media kind and no poll — TDLib's own line is
    // that polls cannot be sent to secret chats. Whether it is *ready* is a
    // separate question, asked by the screen through [isSecretChatReady].
    if (type is td.ChatTypeSecret) return right != ChatSendRight.polls;
    if (type is td.ChatTypePrivate) return right != ChatSendRight.polls;

    if (type is td.ChatTypeSupergroup && type.isChannel) {
      return _canPostAsAdmin(supergroup?.status);
    }

    final permissions = chat.permissions;
    final permitted = switch (right) {
      ChatSendRight.photos => permissions.canSendPhotos,
      ChatSendRight.videos => permissions.canSendVideos,
      ChatSendRight.documents => permissions.canSendDocuments,
      ChatSendRight.voiceNotes => permissions.canSendVoiceNotes,
      ChatSendRight.videoNotes => permissions.canSendVideoNotes,
      ChatSendRight.polls => permissions.canSendPolls,
      ChatSendRight.stickers => permissions.canSendOtherMessages,
    };
    // An admin is not bound by the members' default permissions.
    return permitted || _canPostAsAdmin(supergroup?.status);
  }

  /// Whether a poll may be sent into [chat].
  ///
  /// Kept as its own name because it is asked from two features and reads
  /// better than the general form at those call sites.
  static bool canSendPollsIn(td.Chat chat, td.Supergroup? supergroup) =>
      canSendIn(chat, supergroup, ChatSendRight.polls);

  /// Whether this account may change the chat's auto-delete timer.
  ///
  /// A one-to-one chat always may — the timer is a property both people share
  /// and either may set. Anywhere else it is an admin power, and the specific
  /// right Telegram checks is the one to delete messages, because that is what
  /// the timer does on everybody's behalf. A member of a group who tapped it
  /// would get a refusal, so the menu is absent for them instead.
  static bool canSetAutoDeleteIn(td.Chat chat, td.Supergroup? supergroup) {
    final type = chat.type;
    if (type is td.ChatTypePrivate) return true;
    if (type is td.ChatTypeSecret) return false;

    final status = supergroup?.status;
    if (status is td.ChatMemberStatusCreator) return true;
    if (status is td.ChatMemberStatusAdministrator) {
      return status.rights.canDeleteMessages;
    }
    return false;
  }

  static bool _canPostAsAdmin(td.ChatMemberStatus? status) {
    if (status is td.ChatMemberStatusCreator) return true;
    if (status is td.ChatMemberStatusAdministrator) {
      return status.rights.canPostMessages;
    }
    return false;
  }

  /// Folds one update in. Returns true if anything actually changed.
  bool apply(td.TdObject update) {
    switch (update) {
      case td.UpdateNewChat():
        chats[update.chat.id] = update.chat;
        _flushPendingLastMessage(update.chat.id);
        return true;

      case td.UpdateChatLastMessage():
        final existing = chats[update.chatId];
        if (existing == null) {
          pendingLastMessages[update.chatId] = update;
          return false;
        }
        chats[update.chatId] =
            withCleared(
              existing,
              'last_message',
              when: update.lastMessage == null,
            ).copyWith(
              lastMessage: update.lastMessage,
              positions: update.positions,
            );
        return true;

      case td.UpdateChatPosition():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        chats[update.chatId] = existing.copyWith(
          positions: mergePosition(existing.positions, update.position),
        );
        return true;

      case td.UpdateChatReadInbox():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        // The cursor matters as much as the count: a post counts as read when
        // its id is behind `lastReadInboxMessageId`. Folding in only the count
        // left every post read during a session still looking unread, so a
        // refresh handed the reader back what they had just finished.
        chats[update.chatId] = existing.copyWith(
          unreadCount: update.unreadCount,
          lastReadInboxMessageId: update.lastReadInboxMessageId,
        );
        return true;

      // The state of an end-to-end chat, which lives nowhere else. Mirrored so
      // the composer can tell "waiting for them to come online" from "ready",
      // and so closing one is reflected without a refetch.
      case td.UpdateSecretChat():
        secretChats[update.secretChat.id] = update.secretChat;
        return true;

      case td.UpdateChatTitle():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        chats[update.chatId] = existing.copyWith(title: update.title);
        return true;

      case td.UpdateChatPhoto():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        chats[update.chatId] = withCleared(
          existing,
          'photo',
          when: update.photo == null,
        ).copyWith(photo: update.photo);
        return true;

      case td.UpdateSupergroup():
        supergroups[update.supergroup.id] = update.supergroup;
        return true;

      case td.UpdateUser():
        users[update.user.id] = update.user;
        return true;

      // Free when it arrives, never requested from here. It carries the
      // personal chat a user pins to their profile, which is what the chat
      // list shows beside their name.
      case td.UpdateUserFullInfo():
        userFullInfos[update.userId] = update.userFullInfo;
        return true;

      // Presence changes constantly and for people the reader is not looking
      // at, so it folds into the existing record rather than replacing it —
      // an UpdateUserStatus carries the status and nothing else.
      case td.UpdateUserStatus():
        final existing = users[update.userId];
        if (existing == null) return false;
        users[update.userId] = existing.copyWith(status: update.status);
        return true;

      // The outbox cursor is what turns a sent tick into a read one. Without
      // it every message this account sends stays "sent" for the session,
      // however long ago the other side read it.
      case td.UpdateChatReadOutbox():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        chats[update.chatId] = existing.copyWith(
          lastReadOutboxMessageId: update.lastReadOutboxMessageId,
        );
        return true;

      case td.UpdateChatNotificationSettings():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        chats[update.chatId] = existing.copyWith(
          notificationSettings: update.notificationSettings,
        );
        return true;

      // A chat marked unread by hand carries no count, so a list reading only
      // unreadCount draws it as read — which is the opposite of what the
      // reader asked for when they marked it.
      case td.UpdateChatIsMarkedAsUnread():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        chats[update.chatId] = existing.copyWith(
          isMarkedAsUnread: update.isMarkedAsUnread,
        );
        return true;

      // The chat's auto-delete timer, which either side can change from any
      // client. Mirrored so the sheet that sets it opens showing what is
      // actually set rather than what it was when the chat was first cached.
      case td.UpdateChatMessageAutoDeleteTime():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        chats[update.chatId] = existing.copyWith(
          messageAutoDeleteTime: update.messageAutoDeleteTime,
        );
        return true;

      // Whether this chat has messages waiting to be sent. The header's
      // "Scheduled" row is drawn from it, so a chat with nothing queued offers
      // no way into an empty screen.
      case td.UpdateChatHasScheduledMessages():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        chats[update.chatId] = existing.copyWith(
          hasScheduledMessages: update.hasScheduledMessages,
        );
        return true;

      case td.UpdateChatUnreadMentionCount():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        chats[update.chatId] = existing.copyWith(
          unreadMentionCount: update.unreadMentionCount,
        );
        return true;

      // The other half of the same fact, and it was arriving on this stream
      // already with nowhere to go. It is what lets the Activity screen know
      // which chats to ask about without a request per chat.
      case td.UpdateChatUnreadReactionCount():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        chats[update.chatId] = existing.copyWith(
          unreadReactionCount: update.unreadReactionCount,
        );
        return true;

      // Blocking is read off the chat, so a block made here or on another
      // device has to land on it — otherwise the profile's Block button would
      // keep offering what had already been done.
      case td.UpdateChatBlockList():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        // An unblock arrives as a null list. See [withCleared].
        chats[update.chatId] = withCleared(
          existing,
          'block_list',
          when: update.blockList == null,
        ).copyWith(blockList: update.blockList);
        return true;

      // The action bar is how Telegram says "this is somebody you don't know",
      // which is what the Requests filter is built on.
      case td.UpdateChatActionBar():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        // Dismissing it, adding the person, or blocking them all clear it
        // with a null. See [withCleared].
        chats[update.chatId] = withCleared(
          existing,
          'action_bar',
          when: update.actionBar == null,
        ).copyWith(actionBar: update.actionBar);
        return true;

      case td.UpdateChatDraftMessage():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        // Sending clears the draft with a null. Kept, it came back into the
        // composer the next time the chat was opened — the message the reader
        // had already sent, waiting to be sent again. See [withCleared].
        chats[update.chatId] =
            withCleared(
              existing,
              'draft_message',
              when: update.draftMessage == null,
            ).copyWith(
              draftMessage: update.draftMessage,
              positions: update.positions,
            );
        return true;

      default:
        return false;
    }
  }

  /// The supergroup record behind a chat, if TDLib has volunteered it.
  td.Supergroup? supergroupForChat(td.Chat chat) {
    final type = chat.type;
    if (type is! td.ChatTypeSupergroup) return null;
    return supergroups[type.supergroupId];
  }

  void _flushPendingLastMessage(int chatId) {
    final pending = pendingLastMessages.remove(chatId);
    if (pending == null) return;
    final existing = chats[chatId];
    if (existing == null) return;
    chats[chatId] = withCleared(
      existing,
      'last_message',
      when: pending.lastMessage == null,
    ).copyWith(lastMessage: pending.lastMessage, positions: pending.positions);
  }

  /// [chat] with one field set to null, when [when] is true.
  ///
  /// TDLib's generated `copyWith` reads a null argument as "keep what was
  /// there", so an update that *clears* a field — an unblock, a dismissed
  /// action bar, a draft sent, a photo removed — was silently ignored and the
  /// cache went on reporting the old value. Clearing is rare next to setting,
  /// so a round trip through TDLib's own JSON is the plain fix; everything
  /// else still goes through `copyWith`.
  @visibleForTesting
  static td.Chat withCleared(
    td.Chat chat,
    String jsonKey, {
    required bool when,
  }) {
    if (!when) return chat;
    return td.Chat.fromJson(chat.toJson()..[jsonKey] = null);
  }

  /// Replaces the position for one chat list, leaving the others alone.
  static List<td.ChatPosition> mergePosition(
    List<td.ChatPosition> current,
    td.ChatPosition incoming,
  ) {
    final merged = current
        .where((p) => p.list.runtimeType != incoming.list.runtimeType)
        .toList();
    // order 0 means "not in this list" — drop it rather than store a dead entry.
    if (incoming.order != 0) merged.add(incoming);
    return merged;
  }

  void clear() {
    chats.clear();
    secretChats.clear();
    supergroups.clear();
    users.clear();
    userFullInfos.clear();
    pendingLastMessages.clear();
  }
}

/// Live in-memory mirror of the chats TDLib has loaded, built entirely from the
/// update stream.
///
/// This is the load-bearing piece of the cold-start request budget. `LoadChats`
/// costs **one** request no matter how many chats it loads, and TDLib then
/// volunteers each chat through `UpdateNewChat` — including `lastMessage`, which
/// is a free first post per channel. The alternative (`GetChat` per chat) is a
/// per-channel fan-out that earns an account-global FLOOD_WAIT.
class ChatCache {
  final TdlibService _tdlib;

  /// The reducer state. Split out from the service so the update-folding logic
  /// can be tested without a live TDLib client.
  final ChatCacheState _state = ChatCacheState();

  StreamSubscription<td.TdObject>? _sub;
  final _changesController = StreamController<void>.broadcast();

  /// How many `LoadChats` rounds we are willing to issue. Each round pulls up to
  /// [_loadChatsPageSize] more chats, so this caps us at 500 chats for 5
  /// requests — versus 500 requests for the same coverage via `GetChat`.
  static const int _maxLoadChatsRounds = 5;
  static const int _loadChatsPageSize = 100;

  /// TDLib's "nothing left to load" reply to `LoadChats`.
  static const int _chatListExhaustedCode = 404;

  /// Ceiling on the emergency `GetChat` recovery path. Deliberately small —
  /// this is a bug-recovery route, not a loading strategy.
  static const int _recoveryChatLimit = 50;

  ChatCache(this._tdlib) {
    start();
  }

  /// Fires whenever a cached chat is added or changed.
  Stream<void> get changes => _changesController.stream;

  /// Begins mirroring the update stream. Safe to call more than once.
  void start() {
    _sub ??= _tdlib.updatesStream.listen(_handleUpdate);
  }

  td.Chat? chat(int chatId) => _state.chats[chatId];

  /// The supergroup record behind a chat, if TDLib has volunteered it.
  td.Supergroup? supergroupForChat(td.Chat chat) =>
      _state.supergroupForChat(chat);

  /// The end-to-end record behind a chat, if it is a secret one.
  td.SecretChat? secretChatFor(td.Chat chat) => _state.secretChatFor(chat);

  /// Every secret chat record, keyed by secret chat id.
  Map<int, td.SecretChat> get secretChatsById => _state.secretChats;

  td.Supergroup? supergroup(int supergroupId) =>
      _state.supergroups[supergroupId];

  /// The user record behind a private chat, if TDLib has volunteered it.
  td.User? userForChat(td.Chat chat) => _state.userForChat(chat);

  /// The mirrored user and supergroup records, for the pure builders that map a
  /// page of chats or messages at once. Handed over whole rather than looked up
  /// per row, because a lookup per row through this class is the shape that
  /// turns into a request per row the moment somebody adds a fallback to it.
  Map<int, td.User> get usersById => _state.users;

  /// Full user records TDLib has volunteered. See [ChatCacheState.userFullInfos]
  /// — reading this never costs a request, and it is often empty.
  Map<int, td.UserFullInfo> get userFullInfosById => _state.userFullInfos;

  /// Every cached chat, keyed by id. Handed over whole for the pure builders,
  /// which resolve one chat's reference to another — a person's channel, say —
  /// without a lookup, and therefore without a `GetChat`, per row.
  Map<int, td.Chat> get chatsById => _state.chats;

  Map<int, td.Supergroup> get supergroupsById => _state.supergroups;

  td.User? user(int userId) => _state.users[userId];

  /// Files a full user record fetched elsewhere.
  ///
  /// The profile screen pays one `GetUserFullInfo` when somebody opens a
  /// profile, and TDLib does not always follow that with an
  /// `UpdateUserFullInfo`. Handing it over here is what lets the chat list show
  /// that person's channel afterwards without ever asking for one itself —
  /// see [ChatSummary.affiliatedChannelId].
  void rememberUserFullInfo(int userId, td.UserFullInfo info) {
    _state.userFullInfos[userId] = info;
    _changesController.add(null);
  }

  /// Private chats, bot chats and groups — everything that is a conversation
  /// rather than a broadcast. See [ChatCacheState.conversations].
  List<td.Chat> get conversations => _state.conversations;

  /// Every cached chat that is a broadcast channel, most recently active first.
  List<td.Chat> get channels => _state.channels;

  /// Whether any subscribed channel is cached. See [ChatCacheState.hasChannels].
  bool get hasChannels => _state.hasChannels;

  /// Every cached chat, most recently active first — including groups and
  /// private chats, which the forward picker offers as destinations.
  List<td.Chat> get allChats => _state.allChats;

  /// Chats this account can forward a post into. See
  /// [ChatCacheState.forwardTargets].
  List<td.Chat> get forwardTargets => _state.forwardTargets;

  bool get isEmpty => _state.chats.isEmpty;

  /// Whether the main chat list has been loaded this session — the difference
  /// between "no channels" and "not asked yet". See [ensureLoaded].
  bool get isLoaded => _loaded;

  /// A chat's sort order within the main chat list, or 0 if it isn't in it.
  static int mainListOrder(td.Chat chat) => ChatCacheState.mainListOrder(chat);

  /// Asks TDLib to load the main chat list into memory, then waits for the
  /// resulting updates to settle.
  ///
  /// Costs at most [_maxLoadChatsRounds] requests total, regardless of how many
  /// chats the user has. Returns as soon as the cache stops growing.
  ///
  /// **Once per session, shared by everyone who asks.** Three repositories call
  /// this on the way to the first feed — channels, folders, posts — and each
  /// rebuilds when the first channel lands, so a cold start used to run the
  /// whole load five or six times over, back to back, every run paying its own
  /// `LoadChats` round trips and its own settle wait. That was most of the gap
  /// between the splash and the first post. Now the first caller runs it, the
  /// rest wait on the same future, and once the list is known everybody after
  /// that returns immediately. A load that found nothing is not remembered:
  /// before sign-in every request fails, and the next caller must try again.
  /// [clear] forgets it too, because the next account has its own list.
  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  /// Resolves once the first page of the main chat list is in, while the rest
  /// keeps loading behind it.
  ///
  /// The first page is the most recently active chats, which are the ones
  /// whose posts sit at the top of the feed. Everything after it only reaches
  /// further down, and on a long list the second round goes to the server:
  /// waiting for every round held the feed's first paint back by two and a
  /// half seconds on each launch, to add channels nobody would see before
  /// scrolling.
  ///
  /// Starts [ensureLoaded] if nobody has, so asking for the first page never
  /// leaves the rest of the list unasked for.
  Future<void> ensureFirstPage() {
    if (_loaded) return Future.value();
    final whole = ensureLoaded();
    final firstPage = _firstPage;
    if (firstPage == null) return whole;
    return Future.any([firstPage.future, whole]);
  }

  /// True once the main list has been loaded in this session.
  bool _loaded = false;

  /// The load in flight, if one is.
  Future<void>? _loading;

  /// Completed when the load in flight has its first page. See
  /// [ensureFirstPage].
  Completer<void>? _firstPage;

  Future<void> _load() async {
    final firstPage = _firstPage = Completer<void>();
    try {
      await _loadRounds(firstPage);
    } finally {
      // Whatever ended the load — the list running out, a failure, a flood
      // wait — nobody waiting for the first page waits past it.
      if (!firstPage.isCompleted) firstPage.complete();
    }
  }

  Future<void> _loadRounds(Completer<void> firstPage) async {
    var exhausted = false;
    for (var round = 0; round < _maxLoadChatsRounds; round++) {
      final before = _state.chats.length;
      try {
        await _tdlib.sendRequest(
          const td.LoadChats(
            chatList: td.ChatListMain(),
            limit: _loadChatsPageSize,
          ),
        );
      } on TdlibRequestException catch (e) {
        // 404 means the list is fully loaded — the expected exit, not a failure.
        if (e.code == _chatListExhaustedCode) {
          exhausted = true;
          break;
        }
        if (e.isFloodWait) {
          debugPrint(
            '[ChatCache] Rate limited during LoadChats — using what we have',
          );
          break;
        }
        debugPrint('[ChatCache] LoadChats failed: $e');
        break;
      } catch (e) {
        debugPrint('[ChatCache] LoadChats failed: $e');
        break;
      }

      await _awaitQuiescence();
      if (!firstPage.isCompleted) {
        StartupTrace.mark(
          'first page of the chat list (${_state.chats.length} chats)',
        );
        firstPage.complete();
      }
      // No new chats arrived; another round would return the same nothing.
      if (_state.chats.length == before) break;
    }

    if (_state.chats.isEmpty) await _recoverFromMissedUpdates();

    // Known, or known to be empty: TDLib said so with a 404. An empty answer
    // for any other reason — signed out, offline, rate limited — is a guess,
    // and the next caller asks again.
    _loaded = exhausted || _state.chats.isNotEmpty;
    if (_loaded) {
      StartupTrace.mark('chat list loaded (${_state.chats.length} chats)');
    }
  }

  /// Last resort when the update stream told us nothing.
  ///
  /// The cache being empty after [ensureLoaded] means we missed the
  /// `UpdateNewChat` burst — a bug, not a normal state, so it is logged loudly.
  /// Recovery is capped at [_recoveryChatLimit] chats: enough to leave the user
  /// with a working feed, small enough that a regression here can't turn into
  /// the fan-out this class exists to remove.
  Future<void> _recoverFromMissedUpdates() async {
    debugPrint(
      '[ChatCache] Empty after LoadChats — update stream was missed. '
      'Falling back to a capped GetChat recovery.',
    );
    try {
      final res = await _tdlib.sendRequest(
        const td.GetChats(
          chatList: td.ChatListMain(),
          limit: _recoveryChatLimit,
        ),
      );
      if (res is! td.Chats) return;

      for (final chatId in res.chatIds.take(_recoveryChatLimit)) {
        try {
          final chat = await _tdlib.sendRequest(td.GetChat(chatId: chatId));
          if (chat is td.Chat) _state.chats[chat.id] = chat;
        } on TdlibRequestException catch (e) {
          if (e.isFloodWait) break;
        } catch (_) {
          // Skip this chat; a partial recovery still beats an empty feed.
        }
      }
      _notify();
    } catch (e) {
      debugPrint('[ChatCache] Recovery failed: $e');
    }
  }

  /// Waits until the cache stops growing, or until we run out of patience.
  ///
  /// `LoadChats` can answer before every one of its updates has been folded
  /// in, so the reply alone is not the signal — the cache going quiet is.
  /// Quiet means [settle] without a change. This used to poll every 120 ms and
  /// insist on two empty polls, which put a quarter of a second on every round
  /// even when the updates had all landed before the reply did, which with the
  /// receiver isolate is the usual case: they travel the same queue, in order.
  Future<void> _awaitQuiescence({
    Duration settle = const Duration(milliseconds: 80),
    Duration limit = const Duration(milliseconds: 1500),
  }) async {
    final deadline = DateTime.now().add(limit);
    while (DateTime.now().isBefore(deadline)) {
      if (_changesController.isClosed) return;
      final changed = await _changesController.stream.first
          .then((_) => true, onError: (_) => false)
          .timeout(settle, onTimeout: () => false);
      if (!changed) return;
    }
  }

  void _handleUpdate(td.TdObject update) {
    if (_state.apply(update)) _notify();
  }

  void _notify() {
    if (!_changesController.isClosed) _changesController.add(null);
  }

  /// Drops every cached chat. Call on logout — chats are account-scoped.
  void clear() {
    _state.clear();
    _loaded = false;
    _notify();
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _changesController.close();
  }
}

/// Riverpod provider for [ChatCache].
///
/// Kept alive for the life of the container: the cache is only correct if it has
/// been listening since before the first `UpdateNewChat`, so letting it be
/// disposed and rebuilt would silently lose chats.
final chatCacheProvider = Provider<ChatCache>((ref) {
  final cache = ChatCache(ref.watch(tdlibServiceProvider));
  ref.onDispose(cache.dispose);
  return cache;
});

/// Whether the cache knows about any subscribed channel yet.
///
/// The answer to "what are this account's channels" is empty for a moment
/// after signing in, while `LoadChats` is still arriving — and a
/// `FutureProvider` that asked during that moment cached the emptiness for the
/// rest of the session. That is why the feed said "no posts" and folder tabs
/// vanished until the app was restarted.
///
/// Anything that would answer "nothing" from an unfilled cache watches this
/// and is rebuilt once, when the first channel lands. Synchronous on purpose:
/// a warm start reads `true` immediately and costs no extra rebuild.
class ChannelsKnownNotifier extends Notifier<bool> {
  @override
  bool build() {
    final cache = ref.watch(chatCacheProvider);

    final sub = cache.changes.listen((_) {
      final known = cache.hasChannels;
      if (known != state) state = known;
    });
    ref.onDispose(sub.cancel);

    return cache.hasChannels;
  }
}

final channelsKnownProvider = NotifierProvider<ChannelsKnownNotifier, bool>(
  ChannelsKnownNotifier.new,
);
