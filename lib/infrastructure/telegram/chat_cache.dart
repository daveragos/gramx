import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/core/diagnostics/startup_trace.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';
import 'package:handy_tdlib/api.dart' as td;

/// A per-kind send permission. [stickers] also covers GIFs.
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
class ChatCacheState {
  final Map<int, td.Chat> chats = {};

  /// Supergroups from `UpdateSupergroup`, keyed by supergroup id, not chat id.
  final Map<int, td.Supergroup> supergroups = {};

  /// Users from `UpdateUser`, so the chat list needs no `GetUser` per row.
  final Map<int, td.User> users = {};

  /// Full user records from `UpdateUserFullInfo` and `AffiliationPrefetcher`.
  /// Never fetched for a whole list, so entries are optional in the UI.
  final Map<int, td.UserFullInfo> userFullInfos = {};

  /// Secret chats keyed by secret chat id. They hold the pending or ready
  /// state, which `td.Chat` lacks.
  final Map<int, td.SecretChat> secretChats = {};

  /// Last-message updates that arrived before their chat's `UpdateNewChat`.
  final Map<int, td.UpdateChatLastMessage> pendingLastMessages = {};

  /// The account-wide notification settings for private chats, groups and
  /// channels, which a chat on the default follows.
  final Map<NotificationScope, td.ScopeNotificationSettings> scopeSettings = {};

  /// Every cached chat, most recently active first.
  List<td.Chat> get allChats {
    final list = chats.values.toList();
    list.sort((a, b) => mainListOrder(b).compareTo(mainListOrder(a)));
    return list;
  }

  /// Subscribed broadcast channels, most recent first. TDLib also sends
  /// `UpdateNewChat` for chats the user is not in, such as search results.
  List<td.Chat> get channels {
    final list = chats.values
        .where((c) => isChannel(c) && isSubscribed(c))
        .toList();
    list.sort((a, b) => mainListOrder(b).compareTo(mainListOrder(a)));
    return list;
  }

  /// Whether [channels] would be non-empty, stopping at the first match.
  bool get hasChannels =>
      chats.values.any((c) => isChannel(c) && isSubscribed(c));

  /// Private, bot, group and secret chats, most recent first.
  List<td.Chat> get conversations {
    final list = chats.values
        .where((c) => isConversation(c) && isSubscribed(c))
        .toList();
    list.sort((a, b) => mainListOrder(b).compareTo(mainListOrder(a)));
    return list;
  }

  /// Whether a chat belongs in the messages list.
  static bool isConversation(td.Chat chat) {
    final type = chat.type;
    if (type is td.ChatTypePrivate) return true;
    if (type is td.ChatTypeBasicGroup) return true;
    if (type is td.ChatTypeSecret) return true;
    if (type is td.ChatTypeSupergroup) return !type.isChannel;
    // Unknown chat types are not shown.
    return false;
  }

  /// The secret chat behind a chat, if it is one and TDLib has described it.
  td.SecretChat? secretChatFor(td.Chat chat) {
    final type = chat.type;
    if (type is! td.ChatTypeSecret) return null;
    return secretChats[type.secretChatId];
  }

  /// Whether a secret chat's key exchange has finished.
  static bool isSecretChatReady(td.SecretChat? secret) =>
      secret?.state is td.SecretChatStateReady;

  /// The user record behind a private chat, if TDLib has volunteered it.
  td.User? userForChat(td.Chat chat) {
    final type = chat.type;
    if (type is! td.ChatTypePrivate) return null;
    return users[type.userId];
  }

  /// Whether the user is in this chat, judged by its chat list positions.
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

  /// Subscribed chats this account can post into, for the forward picker.
  List<td.Chat> get forwardTargets {
    final list = chats.values
        .where((c) => isSubscribed(c) && canPostIn(c, supergroupForChat(c)))
        .toList();
    list.sort((a, b) => mainListOrder(b).compareTo(mainListOrder(a)));
    return list;
  }

  /// Whether a message can be sent into [chat]. Groups need member send
  /// rights or admin rights; channels need posting rights.
  static bool canPostIn(td.Chat chat, td.Supergroup? supergroup) {
    final type = chat.type;

    if (type is td.ChatTypePrivate) return true;
    // There is no secret chat record here to check readiness, and channel
    // posts cannot be forwarded into a secret chat anyway.
    if (type is td.ChatTypeSecret) return false;

    // The cache holds no BasicGroup record, so use the chat's permissions.
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

  /// Whether one kind of content may be sent into [chat]. Private chats allow
  /// everything but polls, channels need admin posting rights, and groups use
  /// the chat's permission for that kind or admin rights.
  static bool canSendIn(
    td.Chat chat,
    td.Supergroup? supergroup,
    ChatSendRight right,
  ) {
    final type = chat.type;
    // Polls cannot be sent to secret chats.
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
  static bool canSendPollsIn(td.Chat chat, td.Supergroup? supergroup) =>
      canSendIn(chat, supergroup, ChatSendRight.polls);

  /// Whether this account may change the chat's auto-delete timer. Always in
  /// a private chat; elsewhere it needs the admin right to delete messages.
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

  /// Folds one update in. Returns true if anything changed.
  bool apply(td.TdObject update) {
    switch (update) {
      case td.UpdateScopeNotificationSettings():
        scopeSettings[NotificationScope.of(update.scope)] =
            update.notificationSettings;
        return true;

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
        // Keep the read cursor too; a post at or behind it is read.
        chats[update.chatId] = existing.copyWith(
          unreadCount: update.unreadCount,
          lastReadInboxMessageId: update.lastReadInboxMessageId,
        );
        return true;

      // Secret chat state is only available from this update.
      case td.UpdateSecretChat():
        secretChats[update.secretChat.id] = update.secretChat;
        return true;

      case td.UpdateChatTitle():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        chats[update.chatId] = existing.copyWith(title: update.title);
        return true;

      // What members may send. Without it, the composer kept the rights the
      // chat had when it loaded.
      case td.UpdateChatPermissions():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        chats[update.chatId] = existing.copyWith(
          permissions: update.permissions,
        );
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

      // Never requested from here. Carries the personal chat a user pins to
      // their profile, which the chat list shows beside their name.
      case td.UpdateUserFullInfo():
        userFullInfos[update.userId] = update.userFullInfo;
        return true;

      // Carries only the status, so it is merged into the existing record.
      case td.UpdateUserStatus():
        final existing = users[update.userId];
        if (existing == null) return false;
        users[update.userId] = existing.copyWith(status: update.status);
        return true;

      // The outbox cursor turns a sent tick into a read one.
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

      // A chat marked unread by hand has no unread count.
      case td.UpdateChatIsMarkedAsUnread():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        chats[update.chatId] = existing.copyWith(
          isMarkedAsUnread: update.isMarkedAsUnread,
        );
        return true;

      // Either side can change the auto-delete timer from any device.
      case td.UpdateChatMessageAutoDeleteTime():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        chats[update.chatId] = existing.copyWith(
          messageAutoDeleteTime: update.messageAutoDeleteTime,
        );
        return true;

      // Reading a mention or reaction one message at a time (viewing it here
      // or on another device, or the Activity screen's read-all over loaded
      // messages) reports the new count with the message, not on the chat.
      // Without these the bell's badge kept counting what was already read.
      case td.UpdateMessageMentionRead():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        chats[update.chatId] = existing.copyWith(
          unreadMentionCount: update.unreadMentionCount,
        );
        return true;

      case td.UpdateMessageUnreadReactions():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        chats[update.chatId] = existing.copyWith(
          unreadReactionCount: update.unreadReactionCount,
        );
        return true;

      // The header's "Scheduled" row is drawn from this.
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

      // Tells the Activity screen which chats to query.
      case td.UpdateChatUnreadReactionCount():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        chats[update.chatId] = existing.copyWith(
          unreadReactionCount: update.unreadReactionCount,
        );
        return true;

      // Keeps block state current, including blocks made on other devices.
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

      // The action bar marks a stranger's chat; the Requests filter uses it.
      case td.UpdateChatActionBar():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        // Dismissing, adding or blocking clears it with a null.
        chats[update.chatId] = withCleared(
          existing,
          'action_bar',
          when: update.actionBar == null,
        ).copyWith(actionBar: update.actionBar);
        return true;

      case td.UpdateChatDraftMessage():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        // Sending clears the draft with a null. See [withCleared].
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

  /// [chat] with one field set to null, when [when] is true. TDLib's
  /// generated `copyWith` treats null as "keep the old value", so
  /// clearing a field (an unblock, a sent draft, a removed photo) goes through
  /// a JSON round trip instead.
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
    // Order 0 means the chat is not in this list.
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
    scopeSettings.clear();
  }
}

/// The groups of chats Telegram has default notification settings for.
enum NotificationScope {
  privateChats,
  groups,
  channels;

  static NotificationScope of(td.NotificationSettingsScope scope) =>
      switch (scope) {
        td.NotificationSettingsScopePrivateChats() => privateChats,
        td.NotificationSettingsScopeGroupChats() => groups,
        td.NotificationSettingsScopeChannelChats() => channels,
      };

  /// The scope [chat] falls under, given its supergroup if it has one.
  static NotificationScope ofChat(td.Chat chat, td.Supergroup? supergroup) =>
      switch (chat.type) {
        td.ChatTypePrivate() || td.ChatTypeSecret() => privateChats,
        td.ChatTypeBasicGroup() => groups,
        td.ChatTypeSupergroup(:final isChannel) =>
          isChannel ? channels : groups,
      };
}

/// In-memory mirror of the chats TDLib has loaded, built from the update
/// stream. One `LoadChats` makes TDLib send every chat through
/// `UpdateNewChat`; a `GetChat` per chat would trigger FLOOD_WAIT.
class ChatCache {
  final TdlibService _tdlib;

  final ChatCacheState _state = ChatCacheState();

  StreamSubscription<td.TdObject>? _sub;
  final _changesController = StreamController<void>.broadcast();

  /// The most `LoadChats` rounds to issue, at [_loadChatsPageSize] chats each.
  static const int _maxLoadChatsRounds = 12;
  static const int _loadChatsPageSize = 100;

  /// TDLib's "nothing left to load" reply to `LoadChats`.
  static const int _chatListExhaustedCode = 404;

  /// Cap on the `GetChat` fallback in [_recoverFromMissedUpdates].
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

  /// Users by id, for the pure builders that map a page at once.
  Map<int, td.User> get usersById => _state.users;

  /// Full user records already cached; often empty.
  Map<int, td.UserFullInfo> get userFullInfosById => _state.userFullInfos;

  /// Every cached chat by id, for resolving references without `GetChat`.
  Map<int, td.Chat> get chatsById => _state.chats;

  Map<int, td.Supergroup> get supergroupsById => _state.supergroups;

  /// See [ChatCacheState.scopeSettings].
  Map<NotificationScope, td.ScopeNotificationSettings> get scopeSettings =>
      _state.scopeSettings;

  td.User? user(int userId) => _state.users[userId];

  /// Stores a full user record fetched elsewhere, since TDLib does not always
  /// send `UpdateUserFullInfo` after a `GetUserFullInfo`.
  void rememberUserFullInfo(int userId, td.UserFullInfo info) {
    _state.userFullInfos[userId] = info;
    _changesController.add(null);
  }

  /// Private chats, bot chats and groups. See [ChatCacheState.conversations].
  List<td.Chat> get conversations => _state.conversations;

  /// Subscribed broadcast channels, most recently active first.
  List<td.Chat> get channels => _state.channels;

  /// Whether any subscribed channel is cached.
  bool get hasChannels => _state.hasChannels;

  /// Every cached chat, most recently active first.
  List<td.Chat> get allChats => _state.allChats;

  /// Chats this account can forward a post into.
  List<td.Chat> get forwardTargets => _state.forwardTargets;

  bool get isEmpty => _state.chats.isEmpty;

  /// Whether the main chat list has been loaded this session, which tells "no
  /// channels" apart from "not loaded yet". See [ensureLoaded].
  bool get isLoaded => _loaded;

  /// Whether a load of the main chat list is in flight.
  bool get isLoading => _loading != null;

  /// Resolves when the load in flight settles its next round or ends, or at
  /// once if nothing is loading. Lets the feed show channels page by page.
  Future<void> nextRound() {
    final loading = _loading;
    if (loading == null) return Future.value();
    // The load ending also counts as the last round settling.
    return Future.any([_roundSettled.future, loading]);
  }

  /// A chat's sort order within the main chat list, or 0 if it isn't in it.
  static int mainListOrder(td.Chat chat) => ChatCacheState.mainListOrder(chat);

  /// Loads the main chat list and waits for the updates to settle, once per
  /// session, with concurrent callers sharing one future. An empty result is
  /// not remembered, and [clear] resets it for the next account.
  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  /// Resolves once the first page (the most recently active chats) is in,
  /// while the rest keeps loading. Starts [ensureLoaded] if needed.
  Future<void> ensureFirstPage() {
    if (_loaded) return Future.value();
    final whole = ensureLoaded();
    final firstPage = _firstPage;
    if (firstPage == null) return whole;
    return Future.any([firstPage.future, whole]);
  }

  bool _loaded = false;

  Future<void>? _loading;

  /// Completed when the load in flight has its first page.
  Completer<void>? _firstPage;

  /// Completed, and replaced, each time a round settles. See [nextRound].
  Completer<void> _roundSettled = Completer<void>();

  void _settleRound() {
    final settled = _roundSettled;
    _roundSettled = Completer<void>();
    settled.complete();
  }

  Future<void> _load() async {
    unawaited(_loadScopeSettings());
    final firstPage = _firstPage = Completer<void>();
    try {
      await _loadRounds(firstPage);
    } finally {
      // Release anyone waiting, however the load ended.
      if (!firstPage.isCompleted) firstPage.complete();
      _settleRound();
    }
  }

  /// Asks for the notification defaults, in case their updates came before
  /// the cache was listening.
  Future<void> _loadScopeSettings() async {
    for (final scope in const <td.NotificationSettingsScope>[
      td.NotificationSettingsScopePrivateChats(),
      td.NotificationSettingsScopeGroupChats(),
      td.NotificationSettingsScopeChannelChats(),
    ]) {
      try {
        final res = await _tdlib.sendRequest(
          td.GetScopeNotificationSettings(scope: scope),
        );
        if (res is! td.ScopeNotificationSettings) continue;
        _state.scopeSettings[NotificationScope.of(scope)] = res;
        _notify();
      } catch (e) {
        debugPrint('[ChatCache] notification defaults failed: $e');
      }
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
        // 404 means the list is fully loaded, which is the expected exit.
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
      _settleRound();
      // No new chats arrived, so another round would add nothing.
      if (_state.chats.length == before) break;
    }

    if (_state.chats.isEmpty) await _recoverFromMissedUpdates();

    // Only a 404 proves the list is empty. An empty result for any other
    // reason (signed out, offline, rate limited) is retried by the next caller.
    _loaded = exhausted || _state.chats.isNotEmpty;
    if (_loaded) {
      StartupTrace.mark('chat list loaded (${_state.chats.length} chats)');
    }
  }

  /// Last resort when the cache is still empty after loading, meaning the
  /// `UpdateNewChat` burst was missed. Capped at [_recoveryChatLimit] chats.
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
          // Skip this chat; a partial recovery is better than none.
        }
      }
      _notify();
    } catch (e) {
      debugPrint('[ChatCache] Recovery failed: $e');
    }
  }

  /// Waits until the cache has had no change for [settle], or until [limit].
  /// `LoadChats` can reply before all of its updates have been folded in.
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

  /// Drops every cached chat. Call on logout, since chats are per account.
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

/// Kept alive for the life of the container: the cache must be listening
/// before the first `UpdateNewChat`, so a rebuild would lose chats.
final chatCacheProvider = Provider<ChatCache>((ref) {
  final cache = ChatCache(ref.watch(tdlibServiceProvider));
  ref.onDispose(cache.dispose);
  return cache;
});

/// Whether the cache knows about any subscribed channel yet. Providers that
/// would otherwise cache the empty list seen just after sign-in watch this and
/// rebuild when the first channel lands.
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
