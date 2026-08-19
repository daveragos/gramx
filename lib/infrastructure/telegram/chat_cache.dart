import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

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
    final list =
        chats.values.where((c) => isChannel(c) && isSubscribed(c)).toList();
    list.sort((a, b) => mainListOrder(b).compareTo(mainListOrder(a)));
    return list;
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
        chats[update.chatId] = existing.copyWith(
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
        chats[update.chatId] = existing.copyWith(unreadCount: update.unreadCount);
        return true;

      case td.UpdateChatTitle():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        chats[update.chatId] = existing.copyWith(title: update.title);
        return true;

      case td.UpdateChatPhoto():
        final existing = chats[update.chatId];
        if (existing == null) return false;
        chats[update.chatId] = existing.copyWith(photo: update.photo);
        return true;

      case td.UpdateSupergroup():
        supergroups[update.supergroup.id] = update.supergroup;
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
    chats[chatId] = existing.copyWith(
      lastMessage: pending.lastMessage,
      positions: pending.positions,
    );
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
    supergroups.clear();
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
///
/// See `docs/TDLIB.md` → The request budget.
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

  td.Supergroup? supergroup(int supergroupId) => _state.supergroups[supergroupId];

  /// Every cached chat that is a broadcast channel, most recently active first.
  List<td.Chat> get channels => _state.channels;

  /// Every cached chat, most recently active first — including groups and
  /// private chats, which the forward picker offers as destinations.
  List<td.Chat> get allChats => _state.allChats;

  bool get isEmpty => _state.chats.isEmpty;

  /// A chat's sort order within the main chat list, or 0 if it isn't in it.
  static int mainListOrder(td.Chat chat) => ChatCacheState.mainListOrder(chat);

  /// Asks TDLib to load the main chat list into memory, then waits for the
  /// resulting updates to settle.
  ///
  /// Costs at most [_maxLoadChatsRounds] requests total, regardless of how many
  /// chats the user has. Returns as soon as the cache stops growing.
  Future<void> ensureLoaded() async {
    for (var round = 0; round < _maxLoadChatsRounds; round++) {
      final before = _state.chats.length;
      try {
        await _tdlib.sendRequest(const td.LoadChats(
          chatList: td.ChatListMain(),
          limit: _loadChatsPageSize,
        ));
      } on TdlibRequestException catch (e) {
        // 404 means the list is fully loaded — the expected exit, not a failure.
        if (e.code == _chatListExhaustedCode) break;
        if (e.isFloodWait) {
          debugPrint('[ChatCache] Rate limited during LoadChats — using what we have');
          break;
        }
        debugPrint('[ChatCache] LoadChats failed: $e');
        break;
      } catch (e) {
        debugPrint('[ChatCache] LoadChats failed: $e');
        break;
      }

      await _awaitQuiescence();
      // No new chats arrived; another round would return the same nothing.
      if (_state.chats.length == before) break;
    }

    if (_state.chats.isEmpty) await _recoverFromMissedUpdates();
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
      final res = await _tdlib.sendRequest(const td.GetChats(
        chatList: td.ChatListMain(),
        limit: _recoveryChatLimit,
      ));
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
  /// `LoadChats` returns before its updates have been drained by the polling
  /// loop, so we have to watch the cache rather than trust the reply.
  Future<void> _awaitQuiescence({
    Duration step = const Duration(milliseconds: 120),
    Duration limit = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(limit);
    var stableRounds = 0;
    var lastCount = _state.chats.length;

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(step);
      if (_state.chats.length == lastCount) {
        if (++stableRounds >= 2) return;
      } else {
        stableRounds = 0;
        lastCount = _state.chats.length;
      }
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
