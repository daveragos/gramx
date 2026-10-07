import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';

/// How long typing must pause before a query goes to Telegram. Each search is
/// a networked `SearchChatMessages` request.
const Duration chatSearchDebounce = Duration(milliseconds: 300);

/// What is being searched for in one conversation. Null when the search bar
/// is closed; empty when it is open with no query.
class InChatSearchQuery extends Notifier<String?> {
  Timer? _timer;

  @override
  String? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void open() => state = '';

  void close() {
    _timer?.cancel();
    state = null;
  }

  void setQuery(String query) => state = query;
}

final inChatSearchQueryProvider =
    NotifierProvider.autoDispose<InChatSearchQuery, String?>(
      InChatSearchQuery.new,
    );

/// The query with the network debounce applied.
class DebouncedInChatSearchQuery extends Notifier<String> {
  Timer? _timer;
  String _emitted = '';

  @override
  String build() {
    final query = (ref.watch(inChatSearchQueryProvider) ?? '').trim();

    _timer?.cancel();
    ref.onDispose(() => _timer?.cancel());

    if (query.isEmpty) {
      _emitted = '';
      return '';
    }
    if (query == _emitted) return _emitted;

    _timer = Timer(chatSearchDebounce, () {
      _emitted = query;
      state = query;
    });

    // Keep the last settled query so results don't blank between keystrokes.
    return _emitted;
  }
}

final debouncedInChatSearchQueryProvider =
    NotifierProvider.autoDispose<DebouncedInChatSearchQuery, String>(
      DebouncedInChatSearchQuery.new,
    );

/// Matches for the settled query, in one chat.
final inChatSearchResultsProvider = FutureProvider.autoDispose
    .family<List<ChatMessage>, int>((ref, chatId) async {
      final query = ref.watch(debouncedInChatSearchQueryProvider);
      if (query.isEmpty) return const [];

      final page = await ref
          .read(chatsRepositoryProvider)
          .searchInChat(chatId, query);
      return page.messages;
    });

/// The message pinned in one chat.
///
/// Not auto-disposed: each lookup costs a request even when there is no pin,
/// so the answer is kept for the session. It is looked up again when a
/// message in the chat is pinned, unpinned or deleted, here or elsewhere; it
/// used to keep showing the first answer.
final pinnedMessageProvider = FutureProvider.family<ChatMessage?, int>((
  ref,
  chatId,
) async {
  final pinned = ref.read(chatsRepositoryProvider).pinnedMessage(chatId);
  final sub = ref.read(chatUpdatesProvider).listen((update) async {
    final changed = switch (update) {
      td.UpdateMessageIsPinned(chatId: final id) => id == chatId,
      td.UpdateDeleteMessages(chatId: final id, :final isPermanent) =>
        id == chatId &&
            isPermanent &&
            update.messageIds.contains((await pinned)?.messageId),
      _ => false,
    };
    if (changed) ref.invalidateSelf();
  });
  ref.onDispose(sub.cancel);
  return pinned;
});
