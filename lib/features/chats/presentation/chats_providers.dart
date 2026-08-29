import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chat_list_builder.dart';
import 'package:gramx/features/chats/domain/chat_filter.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// The whole chat list, rebuilt when the cache changes.
///
/// **The recompute is debounced, and that is load-bearing** — the same lesson
/// `ComposeTargetsNotifier` records. Building this list filters and sorts every
/// cached chat and allocates a [ChatSummary] per survivor, while
/// `ChatCache.changes` fires once per *chat update*, and the sync after signing
/// in delivers hundreds of them in a burst. Recomputing on each is hundreds of
/// sorts on the UI thread, which freezes the first frame after sign-in.
///
/// Costs no TDLib requests at any point: every field comes from the cache the
/// update stream already fills.
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
        // ChatSummary has value equality, so a burst that changed nothing
        // relevant is not a new state — otherwise the list would rebuild under
        // the reader's thumb.
        if (!listEquals(next, state)) state = next;
      });
    });

    // Riverpod fires onDispose on a rebuild too, so this is also what stops a
    // pending recompute from the previous dependencies landing on the new one.
    ref.onDispose(() {
      _settle?.cancel();
      _settle = null;
      sub.cancel();
    });

    return current();
  }

  /// Acknowledges every unread conversation.
  ///
  /// The one place in this feature that touches more than one chat, and it is
  /// still bounded and user-driven: it is the "Mark all as read" menu item, it
  /// runs over chats with something unread rather than over the whole list, and
  /// it stops on the first flood wait rather than pushing through it. Read
  /// state is written to every client this account owns, so it is spaced the
  /// same way the feed's backfill is.
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
        // One request per chat, not per unread message: the read cursor moves
        // to the highest id it is given, so the last message covers the rest.
        final error = await repository.markChatRead(row.chatId);
        if (error != null) break;
      }
      done++;
      await Future<void>.delayed(_markAllSpacing);
    }
    return done;
  }

  /// Spacing between chats in [markAllRead]. Same order as the feed's backfill
  /// throttle: enough that a hundred chats cannot become a hundred requests in
  /// a second.
  static const Duration _markAllSpacing = Duration(milliseconds: 120);
}

final chatListProvider = NotifierProvider<ChatListNotifier, List<ChatSummary>>(
  ChatListNotifier.new,
);

/// Which filter the header pill is showing. See [ChatFilter].
class ChatFilterNotifier extends Notifier<ChatFilter> {
  @override
  ChatFilter build() => ChatFilter.all;

  void select(ChatFilter filter) => state = filter;
}

final chatFilterProvider = NotifierProvider<ChatFilterNotifier, ChatFilter>(
  ChatFilterNotifier.new,
);

/// What is typed in the chat list's search box.
///
/// Not debounced, and it does not need to be: it filters rows already in
/// memory and issues no request, so a keystroke costs a rebuild and nothing
/// else. The debounce rule in `docs/TDLIB.md` is about requests.
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

/// How many conversations have something unread — the number on the tab badge.
///
/// Counted off the unfiltered list on purpose: a badge that changed when the
/// reader picked a filter would be reporting on the filter rather than on their
/// messages.
final unreadChatCountProvider = Provider<int>((ref) {
  if (!ref.watch(readerCapabilitiesProvider).canMessage) return 0;
  return ChatListBuilder.unreadChatCount(ref.watch(chatListProvider));
});

/// One chat's row, for the conversation header.
///
/// Watches the list rather than the cache directly, so the header's title,
/// avatar and presence come from exactly the same place the list's do and
/// cannot disagree with it.
final chatSummaryProvider = Provider.family<ChatSummary?, int>((ref, chatId) {
  for (final row in ref.watch(chatListProvider)) {
    if (row.chatId == chatId) return row;
  }
  // Not in the conversation list — a chat opened by id before the cache knew
  // it, which the repository can still describe.
  return ref
      .watch(chatsRepositoryProvider)
      .summary(chatId, selfUserId: ref.watch(selfUserIdProvider));
});

/// Bumped when the Messages tab is re-tapped.
///
/// A counter rather than a flag, so two consecutive taps are two requests. The
/// feed's [FeedScrollToTopNotifier] is the same shape and exists for the same
/// reason: re-tapping the tab you are already on means "take me back to the
/// top", and `goBranch` alone only resets the branch's route stack.
class ChatsScrollToTopNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state = state + 1;
}

final chatsScrollToTopProvider =
    NotifierProvider<ChatsScrollToTopNotifier, int>(
      ChatsScrollToTopNotifier.new,
    );

/// The raw TDLib update stream, for the conversation notifier.
///
/// Exposed as a provider so the notifier depends on a stream rather than on
/// [TdlibService] itself — the "widgets never call TdlibService directly" rule
/// applies to notifiers too, and this keeps the seam narrow enough to fake.
final chatUpdatesProvider = Provider<Stream<td.TdObject>>((ref) {
  return ref.watch(tdlibServiceProvider).updatesStream;
});
