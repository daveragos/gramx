import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// Fetches `UserFullInfo` for people in the messages list as their rows are
/// built, so the channel badge shows for chats not yet opened. One request per
/// person per session, [spacing] apart, stopping at [maxPerSession] or the
/// first flood wait.
class AffiliationPrefetcher {
  final ChatsRepository _repository;
  final ChatCache _cache;
  final int? Function() _selfUserId;

  /// The gap between two requests.
  final Duration spacing;

  /// How many people one session will ask about.
  final int maxPerSession;

  final Queue<int> _queue = Queue();
  final Set<int> _asked = {};
  bool _running = false;
  bool _stopped = false;

  AffiliationPrefetcher(
    this._repository,
    this._cache, {
    required int? Function() selfUserId,
    this.spacing = const Duration(milliseconds: 180),
    this.maxPerSession = 80,
  }) : _selfUserId = selfUserId;

  /// Queues a request for the person behind [chatId], if needed. Cheap enough
  /// to call from a row builder.
  void request(int chatId) {
    if (_stopped) return;
    final chat = _cache.chat(chatId);
    if (chat == null) return;
    final userId = userToAskAbout(
      chat,
      users: _cache.usersById,
      known: _cache.userFullInfosById,
      selfUserId: _selfUserId(),
    );
    if (userId == null || !_asked.add(userId)) return;
    if (_asked.length > maxPerSession) {
      _stopped = true;
      return;
    }
    _queue.add(userId);
    _drain();
  }

  /// The user to ask about for a row: a person (not a bot, group or Saved
  /// Messages) whose full info the cache doesn't have yet.
  @visibleForTesting
  static int? userToAskAbout(
    td.Chat chat, {
    required Map<int, td.User> users,
    required Map<int, td.UserFullInfo> known,
    int? selfUserId,
  }) {
    final type = chat.type;
    if (type is! td.ChatTypePrivate) return null;
    final userId = type.userId;
    if (userId == selfUserId) return null;
    if (known.containsKey(userId)) return null;
    if (users[userId]?.type is td.UserTypeBot) return null;
    return userId;
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    try {
      while (_queue.isNotEmpty && !_stopped) {
        final userId = _queue.removeFirst();
        try {
          await _repository.ensureUserFullInfo(userId);
        } on TdlibRequestException catch (e) {
          if (e.isFloodWait) {
            // Flood waits apply to the user's account, so stop for the session.
            debugPrint('[Affiliation] rate limited — stopping: $e');
            _stopped = true;
            _queue.clear();
            return;
          }
          debugPrint('[Affiliation] $userId: $e');
        } catch (e) {
          debugPrint('[Affiliation] $userId: $e');
        }
        if (_queue.isNotEmpty) await Future<void>.delayed(spacing);
      }
    } finally {
      _running = false;
    }
  }
}

final affiliationPrefetcherProvider = Provider<AffiliationPrefetcher>((ref) {
  return AffiliationPrefetcher(
    ref.watch(chatsRepositoryProvider),
    ref.watch(chatCacheProvider),
    selfUserId: () => ref.read(selfUserIdProvider),
  );
});
