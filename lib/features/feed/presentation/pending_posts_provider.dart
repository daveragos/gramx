import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';

/// Posts that arrived while the user was reading, held until they tap the
/// "N new posts" pill so the list doesn't shift under them.
class PendingPostsNotifier extends Notifier<List<Post>> {
  /// Album members arrive as separate `UpdateNewMessage` events; waiting this
  /// long lets them merge into one card.
  static const Duration albumCoalesceWindow = Duration(milliseconds: 400);

  /// Upper bound on held arrivals.
  static const int maxPending = 200;

  final List<td.Message> _buffer = [];
  Timer? _coalesceTimer;

  @override
  List<Post> build() {
    final sub = ref.watch(syncServiceProvider).livePostUpdates.listen((update) {
      if (update is LiveNewMessage) _enqueue(update.message);
    });

    ref.onDispose(() {
      sub.cancel();
      _coalesceTimer?.cancel();
    });

    return const [];
  }

  void _enqueue(td.Message message) {
    _buffer.add(message);
    _coalesceTimer?.cancel();
    _coalesceTimer = Timer(albumCoalesceWindow, _flush);
  }

  Future<void> _flush() async {
    if (_buffer.isEmpty) return;
    final batch = List<td.Message>.from(_buffer);
    _buffer.clear();

    try {
      final posts = await ref
          .read(feedRepositoryProvider)
          .mapIncomingMessages(batch);
      if (posts.isEmpty) return;

      // Skip posts a racing refresh already added to the feed.
      final live = ref.read(feedPostsProvider).value ?? const <Post>[];
      final known = {...live.map((p) => p.id), ...state.map((p) => p.id)};

      final additions = posts.where((p) => !known.contains(p.id)).toList();
      if (additions.isEmpty) return;

      final merged = [...state, ...additions]
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

      state = merged.length > maxPending
          ? merged.sublist(0, maxPending)
          : merged;
    } catch (e) {
      debugPrint('[PendingPosts] Failed to map arrivals: $e');
    }
  }

  /// Moves everything pending into the feed and clears the pill.
  void accept() {
    if (state.isEmpty) return;
    ref.read(feedPostsProvider.notifier).prependPosts(state);
    state = const [];
  }

  /// Drops arrivals without showing them, for when a refresh already
  /// includes them.
  void discard() {
    _buffer.clear();
    state = const [];
  }
}

/// The posts whose channel avatars appear on the "N new posts" pill, newest
/// first: one per channel, at most [max].
List<Post> pillAvatarPosts(List<Post> pending, {int max = 3}) {
  if (pending.isEmpty || max <= 0) return const [];

  final seen = <int>{};
  final faces = <Post>[];
  for (final post in pending) {
    if (!seen.add(post.chatId)) continue;
    faces.add(post);
    if (faces.length == max) break;
  }
  return faces;
}

final pendingPostsProvider = NotifierProvider<PendingPostsNotifier, List<Post>>(
  PendingPostsNotifier.new,
);

/// Pending arrivals for one folder tab, so each tab's pill counts only its own.
final pendingPostsForFolderProvider = Provider.family<List<Post>, String>((
  ref,
  folderId,
) {
  final pending = ref.watch(pendingPostsProvider);
  if (pending.isEmpty) return const [];
  return filterPostsForFolder(ref, pending, folderId);
});
