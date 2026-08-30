import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';

/// How long typing must pause before a query reaches Telegram.
///
/// The same 300 ms every text field in this app owes TDLib. Searching a chat is
/// a networked `SearchChatMessages`, and a ten-character query undebounced is
/// ten of them.
const Duration chatSearchDebounce = Duration(milliseconds: 300);

/// What is being searched for in one conversation.
///
/// Null when the search bar is closed, which is a different state from an empty
/// query: closed means the header is a header again, empty means the field is
/// open and waiting.
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

    // Keep showing the last settled query while the reader is still typing,
    // so results do not blank between keystrokes.
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
/// **Deliberately not auto-disposed.** Asking costs a request even when the
/// answer is "none" — TDLib 2.x has no free way to ask — so the answer is held
/// for the session rather than re-fetched every time the reader reopens the
/// same conversation. One chat's pinned message is one object; the leak is
/// bounded by how many chats somebody opens.
final pinnedMessageProvider = FutureProvider.family<ChatMessage?, int>((
  ref,
  chatId,
) async {
  return ref.read(chatsRepositoryProvider).pinnedMessage(chatId);
});
