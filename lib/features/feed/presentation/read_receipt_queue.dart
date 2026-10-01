import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/presentation/seen_posts_provider.dart';

/// Groups post ids into one batch of message ids per chat, since Telegram's
/// read state is a cursor per chat. Ids not shaped `"<chatId>_<messageId>"`
/// are skipped.
Map<int, List<int>> groupReadReceipts(Iterable<String> postIds) {
  final grouped = <int, List<int>>{};

  for (final postId in postIds) {
    final separator = postId.indexOf('_');
    if (separator <= 0) continue;
    final chatId = int.tryParse(postId.substring(0, separator));
    final messageId = int.tryParse(postId.substring(separator + 1));
    if (chatId == null || messageId == null) continue;

    final ids = grouped.putIfAbsent(chatId, () => <int>[]);
    if (!ids.contains(messageId)) ids.add(messageId);
  }

  // Ascending, so the last id is the one that moves the read cursor.
  for (final ids in grouped.values) {
    ids.sort();
  }
  return grouped;
}

/// Sends read acknowledgements to Telegram: held for [flushDelay], sent as
/// one request per chat, and retried once on failure.
class ReadReceiptQueue extends Notifier<void> {
  /// Long enough to batch a scroll through one channel, short enough to send
  /// before the app is closed.
  static const Duration flushDelay = Duration(seconds: 2);

  /// How long to wait before the one retry.
  static const Duration retryDelay = Duration(seconds: 5);

  final Set<String> _pending = {};

  /// Chats TDLib has confirmed open, whose acks can use `forceRead: false`.
  /// Only confirmed chats count: TDLib answers `Ok` but ignores a non-forced
  /// read for a chat it doesn't consider open yet.
  final Set<int> _openChats = {};

  Timer? _flushTimer;

  @override
  void build() {
    ref.onDispose(() {
      _flushTimer?.cancel();
      _flushTimer = null;
    });
  }

  /// Sets the chat TDLib has confirmed open. Pass null while a swap is in
  /// flight; other chats use `forceRead: true`.
  void setOpenChat(int? chatId) {
    _openChats.clear();
    if (chatId != null) _openChats.add(chatId);
  }

  /// Records a seen post and queues an acknowledgement. Idempotent. The post
  /// is marked seen locally at once, even if the ack waits for older posts.
  void add(String postId) {
    ref.read(seenPostsProvider.notifier).add(postId);
    _pending.add(postId);
    _flushTimer ??= Timer(flushDelay, flush);
  }

  /// Sends everything held. Called by the timer and when a post is opened.
  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pending.isEmpty) return;

    final batch = groupReadReceipts(_pending);
    _pending.clear();

    final repo = ref.read(feedRepositoryProvider);
    for (final chatId in batch.keys) {
      await _send(repo, chatId, isRetry: false);
    }
  }

  /// Moves [chatId]'s read cursor over what the user has seen, and no further.
  ///
  /// Acknowledging a post marks everything before it read, and the feed shows
  /// newest first, so only the unbroken run of seen posts above the cursor is
  /// sent (see [FeedRepository.readableRun]).
  Future<void> _send(
    FeedRepository repo,
    int chatId, {
    required bool isRetry,
  }) async {
    final seen = ref.read(seenPostsProvider.notifier);
    final messageIds = await repo.readableRun(chatId, seen.idsIn(chatId));
    if (messageIds.isEmpty) return;

    final error = await repo.markMessagesRead(
      chatId: chatId,
      messageIds: messageIds,
      forceRead: !_openChats.contains(chatId),
    );
    if (error == null) {
      seen.settle(chatId, messageIds.last);
      return;
    }

    debugPrint(
      '[Read] chat $chatId × ${messageIds.length} failed: $error'
      '${isRetry ? ' (final)' : ' — retrying'}',
    );
    if (isRetry) return;

    // One retry, spaced past a short flood wait.
    Future<void>.delayed(retryDelay, () {
      _send(repo, chatId, isRetry: true);
    });
  }
}

final readReceiptQueueProvider = NotifierProvider<ReadReceiptQueue, void>(
  ReadReceiptQueue.new,
);
