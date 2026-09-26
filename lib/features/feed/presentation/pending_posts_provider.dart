import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';

/// Posts that arrived while the user was reading, held back until they ask.
///
/// Arrivals are never spliced into the feed automatically. Inserting a post
/// above the reading position shifts everything under the user's thumb, which
/// is how a reader loses their place mid-sentence. They land here instead, the
/// feed shows a "N new posts" pill, and a tap commits them.
class PendingPostsNotifier extends Notifier<List<Post>> {
  /// Album members arrive as separate `UpdateNewMessage` events. Waiting a beat
  /// before mapping lets them merge into one card instead of appearing as
  /// several single-image posts.
  static const Duration albumCoalesceWindow = Duration(milliseconds: 400);

  /// Ceiling on how many arrivals we hold. A feed left open overnight should
  /// show "lots of new posts", not accumulate an unbounded list.
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

      // A post already in the feed is not an arrival — this happens when the
      // update races a refresh that already picked it up.
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

  /// Drops arrivals without showing them — used when a refresh has just
  /// re-fetched the feed and would include them anyway.
  void discard() {
    _buffer.clear();
    state = const [];
  }
}

/// The channels to show as faces on the "N new posts" pill, newest first.
///
/// into information: "12 new posts" says how much, three faces say from whom,
/// which is what decides whether it is worth tapping now or later.
///
/// One face per channel — a channel that just posted six times is one source,
/// not six — and at most [max] of them, because past three or four the row
/// stops being readable and starts being a texture.
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
