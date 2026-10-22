import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';
import 'package:handy_tdlib/api.dart' as td;

/// A followed chat with a live on.
@immutable
class LiveChat {
  final int chatId;
  final int groupCallId;
  final String title;
  final String? username;
  final String? avatarPath;
  final int? avatarFileId;
  final String? avatarColorHex;

  const LiveChat({
    required this.chatId,
    required this.groupCallId,
    required this.title,
    this.username,
    this.avatarPath,
    this.avatarFileId,
    this.avatarColorHex,
  });

  @override
  bool operator ==(Object other) =>
      other is LiveChat &&
      other.chatId == chatId &&
      other.groupCallId == groupCallId &&
      other.title == title &&
      other.username == username &&
      other.avatarPath == avatarPath &&
      other.avatarFileId == avatarFileId &&
      other.avatarColorHex == avatarColorHex;

  @override
  int get hashCode => Object.hash(
    chatId,
    groupCallId,
    title,
    username,
    avatarPath,
    avatarFileId,
    avatarColorHex,
  );
}

/// The live chats among [chats], in their order.
///
/// A channel counts while anyone is in its video chat. A group counts only
/// while it streams over RTMP ([rtmpGroupCalls] says which group calls do),
/// since a group's voice chat isn't a live. Many chats keep an empty video
/// chat open, which never counts.
@visibleForTesting
List<LiveChat> selectLiveChats(
  Iterable<td.Chat> chats, {
  required Map<int, bool> rtmpGroupCalls,
  td.Supergroup? Function(td.Chat chat)? supergroupFor,
}) {
  return [
    for (final chat in chats)
      if (_isLive(chat, rtmpGroupCalls)) _liveChat(chat, supergroupFor?.call(chat)),
  ];
}

/// Group calls of followed groups whose kind isn't known yet.
@visibleForTesting
Set<int> groupCallsToLookUp(
  Iterable<td.Chat> chats, {
  required Map<int, bool> rtmpGroupCalls,
}) => {
  for (final chat in chats)
    if (_hasLiveVideoChat(chat) &&
        !ChatCacheState.isChannel(chat) &&
        !rtmpGroupCalls.containsKey(chat.videoChat.groupCallId))
      chat.videoChat.groupCallId,
};

bool _hasLiveVideoChat(td.Chat chat) =>
    ChatCacheState.isSubscribed(chat) &&
    chat.videoChat.groupCallId != 0 &&
    chat.videoChat.hasParticipants &&
    (chat.type is td.ChatTypeSupergroup || chat.type is td.ChatTypeBasicGroup);

bool _isLive(td.Chat chat, Map<int, bool> rtmpGroupCalls) {
  if (!_hasLiveVideoChat(chat)) return false;
  if (ChatCacheState.isChannel(chat)) return true;
  return rtmpGroupCalls[chat.videoChat.groupCallId] ?? false;
}

LiveChat _liveChat(td.Chat chat, td.Supergroup? supergroup) {
  final channel = TdlibMappers.mapChatToChannel(chat, supergroup: supergroup);
  return LiveChat(
    chatId: chat.id,
    groupCallId: chat.videoChat.groupCallId,
    title: chat.title,
    username: channel.username,
    avatarPath: channel.avatarUrl,
    avatarFileId: channel.avatarFileId,
    avatarColorHex: channel.avatarColor,
  );
}

/// Followed chats with a live on, for Home's live row. Rebuilt from the chat
/// cache with a short debounce, since the sync after sign-in sends hundreds
/// of updates.
class LiveChatsNotifier extends Notifier<List<LiveChat>> {
  static const Duration settleWindow = Duration(milliseconds: 250);

  Timer? _settle;

  /// Whether each group call seen in a group is an RTMP stream.
  final Map<int, bool> _rtmpGroupCalls = {};
  final Set<int> _lookingUp = {};

  @override
  List<LiveChat> build() {
    final cache = ref.watch(chatCacheProvider);
    final tdlib = ref.watch(tdlibServiceProvider);

    List<LiveChat> current() {
      final chats = cache.allChats;
      _lookUp(
        tdlib,
        groupCallsToLookUp(chats, rtmpGroupCalls: _rtmpGroupCalls),
      );
      return selectLiveChats(
        chats,
        rtmpGroupCalls: _rtmpGroupCalls,
        supergroupFor: cache.supergroupForChat,
      );
    }

    void refresh() {
      _settle?.cancel();
      _settle = Timer(settleWindow, () {
        final next = current();
        if (!listEquals(next, state)) state = next;
      });
    }

    final changes = cache.changes.listen((_) => refresh());
    final updates = tdlib.updatesStream.listen((update) {
      if (update is! td.UpdateGroupCall) return;
      final call = update.groupCall;
      if (_rtmpGroupCalls[call.id] == call.isRtmpStream) return;
      if (!_rtmpGroupCalls.containsKey(call.id) && !_lookingUp.contains(call.id)) {
        return;
      }
      _rtmpGroupCalls[call.id] = call.isRtmpStream;
      refresh();
    });

    ref.onDispose(() {
      _settle?.cancel();
      _settle = null;
      changes.cancel();
      updates.cancel();
    });

    return current();
  }

  /// Asks TDLib whether each of [groupCallIds] is an RTMP stream, then
  /// rebuilds once the answers are in.
  void _lookUp(TdlibService tdlib, Set<int> groupCallIds) {
    for (final id in groupCallIds) {
      if (!_lookingUp.add(id)) continue;
      tdlib
          .sendRequest(td.GetGroupCall(groupCallId: id))
          .then((call) {
            if (!ref.mounted || call is! td.GroupCall) return;
            _rtmpGroupCalls[id] = call.isRtmpStream;
            final next = selectLiveChats(
              ref.read(chatCacheProvider).allChats,
              rtmpGroupCalls: _rtmpGroupCalls,
              supergroupFor: ref.read(chatCacheProvider).supergroupForChat,
            );
            if (!listEquals(next, state)) state = next;
          })
          .catchError((Object _) {
            _rtmpGroupCalls[id] = false;
          })
          .whenComplete(() => _lookingUp.remove(id));
    }
  }
}

final liveChatsProvider = NotifierProvider<LiveChatsNotifier, List<LiveChat>>(
  LiveChatsNotifier.new,
);
