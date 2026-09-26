import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// Learns which channel the people in the messages list run, as the list is
/// scrolled.
///
/// The badge beside a person's name — see `ChatSummary.affiliatedChannelId` —
/// comes from their `UserFullInfo`, which TDLib only volunteers once their
/// chat or profile has been opened. So the badge appeared for the three
/// people the reader had talked to today and for nobody else, and a list
/// meant to show who somebody is showed it only after you already knew.
///
/// **Why this is not the fan-out `docs/TDLIB.md` forbids.** It is driven by
/// rows being *built*, which `ListView.builder` does for what is on or near
/// the screen — not by the list existing. Each person is asked about once a
/// session, one at a time, [spacing] apart, and the whole thing stops at
/// [maxPerSession] or the first flood wait. Scrolling a screen of twelve
/// conversations costs twelve requests spread over two seconds; scrolling
/// nowhere costs nothing.
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

  /// Asks about the person behind [chatId], if there is one worth asking about.
  ///
  /// Cheap to call from a row builder: everything that would make the
  /// request pointless is answered here from the cache, and the request
  /// itself is queued rather than sent.
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

  /// Who a row is about, when asking would tell the list something new.
  ///
  /// Pure, so the rule is testable: a person — not a bot, not the reader's
  /// own Saved Messages, not a group — whose full record the cache does not
  /// hold yet.
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
    // A bot has no channel of its own to run; asking would only ever say so.
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
            // The penalty lands on the reader's account, not on this app.
            // Whatever is queued is dropped and nothing more is asked.
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
