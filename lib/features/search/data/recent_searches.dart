import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:path_provider/path_provider.dart';

import 'package:gramx/core/navigation/deep_link_handler.dart';
import 'package:gramx/core/telegram/telegram_ids.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// Search text typed recently, newest first, kept in a JSON file. Telegram
/// keeps the chats found by search (see [RecentChatsRepository]) but not
/// the words, so these stay on the device.
class RecentQueryStore {
  static const String fileName = 'recent_searches.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  Future<List<String>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString());
      return decoded is List ? decoded.whereType<String>().toList() : const [];
    } catch (e) {
      debugPrint('[RecentSearches] Could not read: $e');
      return const [];
    }
  }

  Future<void> save(List<String> queries) async {
    try {
      final file = await _file();
      if (queries.isEmpty) {
        if (await file.exists()) await file.delete();
        return;
      }
      await file.writeAsString(jsonEncode(queries));
    } catch (e) {
      debugPrint('[RecentSearches] Could not save: $e');
    }
  }
}

final recentQueryStoreProvider = Provider<RecentQueryStore>(
  (ref) => RecentQueryStore(),
);

/// The recent search text, restored from disk and saved on each change.
class RecentQueries extends Notifier<List<String>> {
  /// How many are kept.
  static const int limit = 10;

  /// Counts clears, so a restore that finishes after one is dropped.
  int _clears = 0;

  @override
  List<String> build() {
    unawaited(_restore());
    return const [];
  }

  Future<void> _restore() async {
    final clears = _clears;
    final saved = await ref.read(recentQueryStoreProvider).load();
    // Cleared while the file loaded, as on signing out: the old searches
    // used to come back.
    if (clears != _clears) return;
    // Anything added while the file loaded comes first.
    if (saved.isNotEmpty) state = _merged(state, saved);
  }

  /// Puts [query] first, dropping an earlier copy whatever its case.
  void add(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _set(_merged([trimmed], state));
  }

  void remove(String query) => _set([
    for (final q in state)
      if (q != query) q,
  ]);

  /// Forgets them all, as on clearing recent searches or signing out.
  Future<void> clear() async {
    _clears++;
    state = const [];
    await ref.read(recentQueryStoreProvider).save(const []);
  }

  void _set(List<String> next) {
    state = next;
    unawaited(ref.read(recentQueryStoreProvider).save(next));
  }

  static List<String> _merged(List<String> first, List<String> rest) {
    final seen = <String>{};
    return [
      for (final q in [...first, ...rest])
        if (seen.add(q.toLowerCase())) q,
    ].take(limit).toList();
  }
}

final recentQueriesProvider = NotifierProvider<RecentQueries, List<String>>(
  RecentQueries.new,
);

/// A chat opened from search, as the row of recent searches shows it.
@immutable
class RecentChat {
  final int chatId;
  final String title;
  final String? username;
  final String? avatarPath;
  final int? avatarFileId;
  final ResolvedChatKind kind;

  /// The person's user id, for a private chat.
  final int? userId;

  const RecentChat({
    required this.chatId,
    required this.title,
    required this.kind,
    this.username,
    this.avatarPath,
    this.avatarFileId,
    this.userId,
  });
}

/// Telegram's own list of chats found by search, which TDLib keeps per
/// account.
class RecentChatsRepository {
  final TdlibService _tdlib;
  final ChatCache _chatCache;

  RecentChatsRepository(this._tdlib, this._chatCache);

  /// How many are shown.
  static const int limit = 20;

  Future<List<RecentChat>> load() async {
    try {
      final res = await _tdlib.sendRequest(
        const td.SearchRecentlyFoundChats(query: '', limit: limit),
      );
      if (res is! td.Chats) return const [];
      return [
        for (final chatId in res.chatIds)
          if (_chatCache.chat(chatId) case final chat?) _recentChat(chat),
      ];
    } catch (e) {
      debugPrint('[RecentSearches] recent chats unavailable: $e');
      return const [];
    }
  }

  RecentChat _recentChat(td.Chat chat) {
    final type = chat.type;
    final photo = chat.photo?.small;
    String? username;
    int? userId;
    if (type is td.ChatTypePrivate) {
      userId = type.userId;
      username = _chatCache
          .user(type.userId)
          ?.usernames
          ?.activeUsernames
          .firstOrNull;
    } else if (TelegramIds.supergroupId(chat.id) case final id?) {
      username = _chatCache
          .supergroup(id)
          ?.usernames
          ?.activeUsernames
          .firstOrNull;
    }
    return RecentChat(
      chatId: chat.id,
      title: chat.title,
      username: username,
      userId: userId,
      avatarPath: photo != null && photo.local.path.isNotEmpty
          ? photo.local.path
          : null,
      avatarFileId: photo?.id,
      kind: ChatsRepository.resolvedKindOf(type),
    );
  }

  /// Puts [chatId] first in Telegram's list.
  Future<void> add(int chatId) async {
    try {
      await _tdlib.sendRequest(td.AddRecentlyFoundChat(chatId: chatId));
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      await _tdlib.sendRequest(const td.ClearRecentlyFoundChats());
    } catch (_) {}
  }
}

final recentChatsRepositoryProvider = Provider<RecentChatsRepository>(
  (ref) => RecentChatsRepository(
    ref.watch(tdlibServiceProvider),
    ref.watch(chatCacheProvider),
  ),
);

/// The recent chats, or none for a guest, who has no Telegram account.
final recentChatsProvider = FutureProvider<List<RecentChat>>((ref) async {
  if (!ref.watch(readerCapabilitiesProvider).canSearchServerSide) {
    return const [];
  }
  return ref.watch(recentChatsRepositoryProvider).load();
});

/// Records a search the user acted on: its text, and the chat it led to.
void rememberSearch(WidgetRef ref, {String? query, int? chatId}) {
  if (query != null) ref.read(recentQueriesProvider.notifier).add(query);
  if (chatId != null &&
      ref.read(readerCapabilitiesProvider).canSearchServerSide) {
    unawaited(
      ref
          .read(recentChatsRepositoryProvider)
          .add(chatId)
          .then((_) => ref.invalidate(recentChatsProvider)),
    );
  }
}

/// Clears both lists.
Future<void> clearRecentSearches(WidgetRef ref) async {
  await ref.read(recentQueriesProvider.notifier).clear();
  if (ref.read(readerCapabilitiesProvider).canSearchServerSide) {
    await ref.read(recentChatsRepositoryProvider).clear();
  }
  ref.invalidate(recentChatsProvider);
}
