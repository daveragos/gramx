import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter/widgets.dart';

import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/features/feed/presentation/feed_focus_tracker.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/read_receipt_queue.dart';
import 'package:gramx/features/feed/presentation/seen_posts_provider.dart';

/// Drives read tracking and chat focus from what is on screen, using the
/// rules in [FeedFocusTracker]. Posts are marked read after a dwell, since
/// Flutter builds items ahead of the viewport. The most visible post's chat
/// is opened, since TDLib only streams live counts for open chats.
class FeedFocusController extends Notifier<String?> {
  /// How often settled dwells are checked.
  static const Duration tickInterval = Duration(milliseconds: 200);

  final FeedFocusTracker _tracker = FeedFocusTracker();
  Timer? _ticker;
  int? _openChatId;

  /// Guards the late `OpenChat` confirmation; reading a provider after
  /// dispose throws.
  bool _disposed = false;

  @override
  String? build() {
    ref.onDispose(() {
      _disposed = true;
      _ticker?.cancel();
      _ticker = null;
      // Send anything held back now, since the queue's timer won't fire again.
      ref.read(readReceiptQueueProvider.notifier).flush();

      final chatId = _openChatId;
      if (chatId != null) {
        ref.read(feedRepositoryProvider).closeChat(chatId);
        _openChatId = null;
      }
    });
    return null;
  }

  /// Reports how much of a post is on screen.
  void reportVisibility(String postId, double visibleFraction) {
    _tracker.onVisibilityChanged(postId, visibleFraction, DateTime.now());
    _ensureTicking();
  }

  void reportDisposed(String postId) => _tracker.onDisposed(postId);

  /// Seeds posts Telegram already considers read so they aren't sent again.
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
    // A guest has no account to mark anything read on.
    if (!ref.read(readerCapabilitiesProvider).canMarkRead) return;

    final chatId = _chatIdOf(postId);
    if (chatId == null) return;

    // Telegram may already consider this read.
    final posts = ref.read(feedPostsProvider).value;
    final known = posts?.where((p) => p.id == postId).firstOrNull;
    final seenBefore = ref
        .read(seenPostsProvider.notifier)
        .containsPost(postId);
    if ((known != null && known.isRead) || seenBefore) {
      _tracker.markAlreadyRead(postId);
      return;
    }

    ref.read(optimisticPostUpdatesProvider.notifier).markRead(postId);
    ref.read(feedPostsProvider.notifier).markReadOptimistic(postId);

    // Queued so acks are batched per chat and retried on failure.
    ref.read(readReceiptQueueProvider.notifier).add(postId);
  }

  /// Keeps at most one chat open.
  void _swapOpenChat(String? postId) {
    // Guest posts carry a synthetic chat id that TDLib doesn't know.
    if (!ref.read(readerCapabilitiesProvider).canMarkRead) return;

    final nextChatId = postId == null ? null : _chatIdOf(postId);
    if (nextChatId == _openChatId) return;

    final repo = ref.read(feedRepositoryProvider);
    final previous = _openChatId;
    if (previous != null) repo.closeChat(previous);

    _openChatId = nextChatId;

    // TDLib drops receipts for a chat before confirming it open, so until
    // then a read ack forces the write.
    ref.read(readReceiptQueueProvider.notifier).setOpenChat(null);
    if (nextChatId == null) return;

    repo.openChat(nextChatId).then((opened) {
      // The user may have scrolled on while the request was in flight.
      if (_disposed || !opened || _openChatId != nextChatId) return;
      ref.read(readReceiptQueueProvider.notifier).setOpenChat(nextChatId);
    });
  }

  /// Post ids are `"<chatId>_<messageId>"`.
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

/// Wraps a post card and reports how much of it is on screen. The key is
/// stable per post, since a changing key would restart the dwell.
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
  // `ref` is unusable in dispose(), so the notifier is captured here.
  late final FeedFocusController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(feedFocusControllerProvider.notifier);
  }

  @override
  void dispose() {
    _controller.reportDisposed(widget.postId);
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
