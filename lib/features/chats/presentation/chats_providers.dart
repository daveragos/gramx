import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chat_list_builder.dart';
import 'package:gramx/features/chats/domain/chat_filter.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/features/chats/domain/user_profile.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// The whole chat list, rebuilt from the cache with no TDLib requests.
///
/// Rebuilds are debounced: `ChatCache.changes` fires once per chat update, and
/// the sync after sign-in sends hundreds in a burst, which would otherwise
/// freeze the UI thread.
class ChatListNotifier extends Notifier<List<ChatSummary>> {
  /// How long a burst of chat updates settles before the list is rebuilt.
  static const Duration settleWindow = Duration(milliseconds: 250);

  Timer? _settle;

  @override
  List<ChatSummary> build() {
    final repository = ref.watch(chatsRepositoryProvider);
    final selfUserId = ref.watch(selfUserIdProvider);
    List<ChatSummary> current() => repository.chatList(selfUserId: selfUserId);

    final sub = ref.watch(chatCacheProvider).changes.listen((_) {
      _settle?.cancel();
      _settle = Timer(settleWindow, () {
        final next = current();
        // Skip bursts that changed nothing visible.
        if (!listEquals(next, state)) state = next;
      });
    });

    // Also runs on rebuild, so a pending recompute can't land on new
    // dependencies.
    ref.onDispose(() {
      _settle?.cancel();
      _settle = null;
      sub.cancel();
    });

    return current();
  }

  /// Marks every unread conversation read, for the "Mark all as read" menu
  /// item. Spaced out, and stops at the first error (such as a flood wait).
  Future<int> markAllRead() async {
    final repository = ref.read(chatsRepositoryProvider);
    final unread = [
      for (final row in state)
        if (row.unreadCount > 0 || row.isMarkedAsUnread) row,
    ];

    var done = 0;
    for (final row in unread) {
      if (row.isMarkedAsUnread) {
        await repository.setMarkedAsUnread(row.chatId, value: false);
      }
      if (row.unreadCount > 0) {
        // One request per chat: marking the newest message read covers the rest.
        final error = await repository.markChatRead(row.chatId);
        if (error != null) break;
      }
      done++;
      await Future<void>.delayed(_markAllSpacing);
    }
    return done;
  }

  /// Spacing between chats in [markAllRead], to stay under rate limits.
  static const Duration _markAllSpacing = Duration(milliseconds: 120);
}

final chatListProvider = NotifierProvider<ChatListNotifier, List<ChatSummary>>(
  ChatListNotifier.new,
);

/// The filter shown in the chat list header. Starts on [ChatFilter.direct],
/// since most chats on a typical account are bots and groups.
class ChatFilterNotifier extends Notifier<ChatFilter> {
  @override
  ChatFilter build() => ChatFilter.direct;

  void select(ChatFilter filter) => state = filter;
}

final chatFilterProvider = NotifierProvider<ChatFilterNotifier, ChatFilter>(
  ChatFilterNotifier.new,
);

/// What is typed in the chat list's search box. Not debounced, since it only
/// filters rows in memory.
class ChatSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
  void clear() => state = '';
}

final chatSearchQueryProvider =
    NotifierProvider<ChatSearchQueryNotifier, String>(
      ChatSearchQueryNotifier.new,
    );

/// The rows actually on screen: the list, through the filter and the search.
final visibleChatsProvider = Provider<List<ChatSummary>>((ref) {
  return ChatListBuilder.filter(
    ref.watch(chatListProvider),
    filter: ref.watch(chatFilterProvider),
    query: ref.watch(chatSearchQueryProvider),
  );
});

/// How many conversations have something unread, for the tab badge. Counts
/// through the selected filter (but not the search box), so it matches the
/// list the tab shows.
final unreadChatCountProvider = Provider<int>((ref) {
  if (!ref.watch(readerCapabilitiesProvider).canMessage) return 0;
  return ChatListBuilder.unreadChatCount(
    ref.watch(chatListProvider),
    filter: ref.watch(chatFilterProvider),
  );
});

/// One chat's row, for the conversation header. Read from the list so the
/// header and the list always agree.
final chatSummaryProvider = Provider.family<ChatSummary?, int>((ref, chatId) {
  for (final row in ref.watch(chatListProvider)) {
    if (row.chatId == chatId) return row;
  }
  // Not in the list, e.g. a chat opened by id before the cache knew it.
  return ref
      .watch(chatsRepositoryProvider)
      .summary(chatId, selfUserId: ref.watch(selfUserIdProvider));
});

/// Bumped when the Messages tab is re-tapped, to scroll back to the top. A
/// counter so that every tap is a new request.
class ChatsScrollToTopNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state = state + 1;
}

final chatsScrollToTopProvider =
    NotifierProvider<ChatsScrollToTopNotifier, int>(
      ChatsScrollToTopNotifier.new,
    );

/// The raw TDLib update stream, for the conversation notifier. A provider so
/// tests can fake the stream without a [TdlibService].
final chatUpdatesProvider = Provider<Stream<td.TdObject>>((ref) {
  return ref.watch(tdlibServiceProvider).updatesStream;
});

/// This account's Telegram contacts, for the contact picker. One `GetContacts`
/// request; the users themselves are already in [ChatCache]. Auto-disposed so
/// the list isn't kept after the picker closes.
final contactsProvider = FutureProvider.autoDispose<List<UserProfile>>((
  ref,
) async {
  return ref.watch(chatsRepositoryProvider).contacts();
});

/// One chat's scheduled messages, fetched once with
/// `GetChatScheduledMessages`. Nothing keeps it current, so the screen
/// invalidates it after each change it makes.
final scheduledMessagesProvider = FutureProvider.autoDispose
    .family<List<ChatMessage>, int>((ref, chatId) async {
      return ref.watch(chatsRepositoryProvider).scheduledMessages(chatId);
    });
