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

/// This account's Telegram user id, or null while the record is loading.
/// Used to recognise Saved Messages, a private chat with yourself in TDLib.
final selfUserIdProvider = Provider<int?>((ref) {
  final id = ref.watch(activeAccountProvider).value?.telegramUserId;
  return id == null ? null : int.tryParse(id);
});

/// Fires when the set of chats might have changed. Separate from
/// [chatCacheProvider] so the debounce can be tested without TDLib.
final chatCacheChangesProvider = Provider<Stream<void>>(
  (ref) => ref.watch(chatCacheProvider).changes,
);

/// Builds the destination list on demand. A function because building it is
/// expensive and [ComposeTargetsNotifier] calls it rarely.
final composeTargetsSourceProvider = Provider<List<ComposeTarget> Function()>((
  ref,
) {
  final repository = ref.watch(composeRepositoryProvider);
  final selfUserId = ref.watch(selfUserIdProvider);
  return () => repository.targets(selfUserId: selfUserId);
});

/// Where this account may post, best destination first. Rebuilt from the
/// chat cache with a debounce, since the sync after sign-in sends hundreds
/// of chat updates in a burst and rebuilding on each can freeze the UI.
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
        // Skip identical lists so the picker doesn't rebuild under a finger.
        if (!_sameList(next, state)) state = next;
      });
    });

    // Riverpod also calls onDispose on a rebuild, so this stops a pending
    // recompute from landing on the new dependencies or a disposed notifier.
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

/// Whether to show the compose button. False for a guest, or when there is
/// nowhere to post (rare, since Saved Messages appears once the cache fills).
final canComposeProvider = Provider<bool>((ref) {
  if (!ref.watch(readerCapabilitiesProvider).canPost) return false;
  return ref.watch(composeTargetsProvider).isNotEmpty;
});
