import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter/widgets.dart';

import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/presentation/feed_focus_tracker.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/read_receipt_queue.dart';

/// Drives read tracking and chat focus from what is actually on screen.
///
/// Owns the timers and the TDLib side effects; the rules themselves live in
/// [FeedFocusTracker] so they can be tested. State is the focused post id.
///
/// Two jobs, both of which the app previously got wrong:
///
/// * **Read tracking** — posts are marked read after a real dwell, not from
///   `build()`. Flutter builds list items ahead of the viewport, so the old
///   approach marked posts the user never saw and pushed that to every
///   Telegram client they own.
/// * **Chat focus** — TDLib only streams view and reaction counts for chats
///   that are open, and the merged feed never opened one, so all the live-update
///   plumbing sat idle. This opens the dominant-visible post's chat.
class FeedFocusController extends Notifier<String?> {
  /// How often settled dwells are checked. Fine-grained enough that the 500 ms
  /// read dwell lands promptly, coarse enough not to be a per-frame wakeup.
  static const Duration tickInterval = Duration(milliseconds: 200);

  final FeedFocusTracker _tracker = FeedFocusTracker();
  Timer? _ticker;
  int? _openChatId;

  @override
  String? build() {
    ref.onDispose(() {
      _ticker?.cancel();
      _ticker = null;
      // Anything held back must go out now: the reader has left the feed, and
      // a receipt that waits for a timer that will never fire is a lost read.
      ref.read(readReceiptQueueProvider.notifier).flush();

      final chatId = _openChatId;
      if (chatId != null) {
        // Fire-and-forget: the container is going away either way.
        ref.read(feedRepositoryProvider).closeChat(chatId);
        _openChatId = null;
      }
    });
    return null;
  }

  /// Reports how much of a post is on screen. Called by the visibility wrapper.
  void reportVisibility(String postId, double visibleFraction) {
    _tracker.onVisibilityChanged(postId, visibleFraction, DateTime.now());
    _ensureTicking();
  }

  /// Stops tracking a post whose card has left the tree.
  void reportDisposed(String postId) => _tracker.onDisposed(postId);

  /// Seeds posts Telegram already considers read so we never re-ack them.
  void seedAlreadyRead(Iterable<String> postIds) {
    for (final id in postIds) {
      _tracker.markAlreadyRead(id);
    }
  }

  void _ensureTicking() {
    _ticker ??= Timer.periodic(tickInterval, (_) => _onTick());
  }

  void _onTick() {
    final now = DateTime.now();

    for (final postId in _tracker.takeNewlyRead(now)) {
      _markRead(postId);
    }

    if (_tracker.settleFocus(now) || _tracker.releaseFocusIfNothingVisible()) {
      state = _tracker.focusedPostId;
      _swapOpenChat(_tracker.focusedPostId);
    }

    if (!_tracker.hasPendingWork) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _markRead(String postId) {
    final chatId = _chatIdOf(postId);
    if (chatId == null) return;

    // Telegram may already consider this read — from another client, or from an
    // earlier session. Re-acking it spends a request to change nothing.
    final posts = ref.read(feedPostsProvider).value;
    final known = posts?.where((p) => p.id == postId).firstOrNull;
    if (known != null && known.isRead) {
      _tracker.markAlreadyRead(postId);
      return;
    }

    ref.read(optimisticPostUpdatesProvider.notifier).markRead(postId);
    ref.read(feedPostsProvider.notifier).markReadOptimistic(postId);

    // Queued rather than sent: a scroll through six posts of one channel is one
    // acknowledgement, and the queue retries the ones that fail. Read state is
    // the reader's, on every device they own — losing it to a flood wait is not
    // acceptable, and it used to be silent.
    ref.read(readReceiptQueueProvider.notifier).add(postId);
  }

  /// Keeps at most one chat open, as TDLib expects.
  void _swapOpenChat(String? postId) {
    final nextChatId = postId == null ? null : _chatIdOf(postId);
    if (nextChatId == _openChatId) return;

    final repo = ref.read(feedRepositoryProvider);
    final previous = _openChatId;
    if (previous != null) repo.closeChat(previous);

    _openChatId = nextChatId;
    if (nextChatId != null) repo.openChat(nextChatId);
    // The queue needs this to know whether an ack has to force the read.
    ref.read(readReceiptQueueProvider.notifier).setOpenChat(nextChatId);
  }

  /// Post ids are `"<chatId>_<messageId>"` — the format the router, the
  /// bookmark table and the override map all key on.
  static int? _chatIdOf(String postId) {
    final separator = postId.indexOf('_');
    if (separator <= 0) return null;
    return int.tryParse(postId.substring(0, separator));
  }

  @visibleForTesting
  FeedFocusTracker get tracker => _tracker;
}

final feedFocusControllerProvider =
    NotifierProvider<FeedFocusController, String?>(FeedFocusController.new);

/// Wraps a post card and reports how much of it is on screen.
///
/// Uses a stable key per post id so the detector survives list rebuilds; a
/// changing key restarts the dwell and posts would never settle.
class PostVisibilityReporter extends ConsumerStatefulWidget {
  final String postId;
  final Widget child;

  const PostVisibilityReporter({
    super.key,
    required this.postId,
    required this.child,
  });

  @override
  ConsumerState<PostVisibilityReporter> createState() =>
      _PostVisibilityReporterState();
}

class _PostVisibilityReporterState
    extends ConsumerState<PostVisibilityReporter> {
  @override
  void dispose() {
    ref
        .read(feedFocusControllerProvider.notifier)
        .reportDisposed(widget.postId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('post-visibility-${widget.postId}'),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        ref
            .read(feedFocusControllerProvider.notifier)
            .reportVisibility(widget.postId, info.visibleFraction);
      },
      child: widget.child,
    );
  }
}
