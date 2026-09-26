import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/compose/data/compose_media_picker.dart';
import 'package:gramx/features/compose/data/compose_repository.dart';
import 'package:gramx/features/compose/domain/compose_target.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';

final composeMediaPickerProvider = Provider<ComposeMediaPicker>(
  (ref) => ComposeMediaPicker(),
);

/// This account's own Telegram user id, or null while the record is loading.
///
/// Only used to recognise Saved Messages, which TDLib models as a private chat
/// with yourself. Stored as text in the accounts table, so it is parsed here
/// rather than at each call site.
final selfUserIdProvider = Provider<int?>((ref) {
  final id = ref.watch(activeAccountProvider).value?.telegramUserId;
  return id == null ? null : int.tryParse(id);
});

/// When the set of chats might have changed.
///
/// Split out from [chatCacheProvider] so the coalescing below can be tested
/// without a TDLib client — the notifier's job is deciding *when* to rebuild,
/// and that decision is the part that was wrong.
final chatCacheChangesProvider = Provider<Stream<void>>(
  (ref) => ref.watch(chatCacheProvider).changes,
);

/// The destination list as it stands right now.
///
/// A function rather than a value: calling it is the expensive part, and the
/// point of [ComposeTargetsNotifier] is to call it rarely.
final composeTargetsSourceProvider = Provider<List<ComposeTarget> Function()>((
  ref,
) {
  final repository = ref.watch(composeRepositoryProvider);
  final selfUserId = ref.watch(selfUserIdProvider);
  return () => repository.targets(selfUserId: selfUserId);
});

/// Where this account may post, best destination first.
///
/// Watches the chat cache rather than reading it once, for the same reason
/// [ChannelsKnownNotifier] does: the cache is empty for a moment after signing
/// in, and a list captured during that moment would leave the writer with
/// nowhere to post for the rest of the session.
///
/// **The recompute is debounced, and that is load-bearing.** Building this list
/// filters and sorts every cached chat and allocates a [ComposeTarget] per
/// survivor. `ChatCache.changes` fires once per *chat update*, and the initial
/// sync after signing in delivers hundreds of them in a burst — so recomputing
/// on each one is hundreds of sorts over hundreds of chats, synchronously, on
/// the UI thread. That is enough to freeze the first frame after sign-in, and a
/// frozen UI keeps painting whatever it last drew: the "Loading account
/// profile" screen, long after the account had in fact loaded.
///
/// Coalescing the burst costs a few hundred milliseconds before the compose
/// button appears, which nobody is waiting on, and it is the same shape as the
/// album coalesce in `PendingPostsNotifier`.
class ComposeTargetsNotifier extends Notifier<List<ComposeTarget>> {
  /// How long a burst of chat updates settles before the list is rebuilt.
  static const Duration settleWindow = Duration(milliseconds: 300);

  Timer? _settle;

  @override
  List<ComposeTarget> build() {
    final current = ref.watch(composeTargetsSourceProvider);

    final sub = ref.watch(chatCacheChangesProvider).listen((_) {
      _settle?.cancel();
      _settle = Timer(settleWindow, () {
        final next = current();
        // ComposeTarget has value equality, so a burst that changed nothing
        // relevant is not a new state — otherwise the picker would rebuild
        // under the writer's finger.
        if (!_sameList(next, state)) state = next;
      });
    });

    // Riverpod fires onDispose on a *rebuild* too, keeping the notifier
    // instance. Cancelling here is
    // therefore also what stops a pending recompute from the previous
    // dependencies landing on the new one, or on a disposed notifier.
    ref.onDispose(() {
      _settle?.cancel();
      _settle = null;
      sub.cancel();
    });

    return current();
  }

  static bool _sameList(List<ComposeTarget> a, List<ComposeTarget> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final composeTargetsProvider =
    NotifierProvider<ComposeTargetsNotifier, List<ComposeTarget>>(
      ComposeTargetsNotifier.new,
    );

/// Whether the compose button should exist at all.
///
/// Two ways for the answer to be no, and both of them mean the button would be
/// a control that renders and does nothing: a guest has no account to post as,
/// and a reader who runs no channel and shares no group has nowhere for a post
/// to go. Saved Messages keeps the second case rare rather than impossible —
/// it is only absent before the chat cache has filled.
final canComposeProvider = Provider<bool>((ref) {
  if (!ref.watch(readerCapabilitiesProvider).canPost) return false;
  return ref.watch(composeTargetsProvider).isNotEmpty;
});
