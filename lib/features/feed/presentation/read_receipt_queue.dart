import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/feed/data/feed_repository.dart';

/// Groups post ids into one batch of message ids per chat.
///
/// Read state in Telegram is a cursor per chat, not a flag per message, so a
/// scroll through six posts of one channel is one acknowledgement — not six
/// requests racing each other through the flood gate.
///
/// Ids that aren't `"<chatId>_<messageId>"` are dropped rather than throwing:
/// losing one receipt is better than losing the batch.
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

  // Ascending, so the highest id — the one that actually moves the chat's read
  // cursor — is unambiguous in the log and in the request.
  for (final ids in grouped.values) {
    ids.sort();
  }
  return grouped;
}

/// Sends read acknowledgements to Telegram, batched and retried.
///
/// Reads are the one thing this app writes back on the reader's behalf, and
/// they were fire-and-forget: one request per post, failures swallowed into a
/// debug line. A flood wait, or a moment offline, silently lost them — and the
/// reader's Telegram kept showing everything unread with nothing to explain it.
///
/// So: hold receipts for [flushDelay], send one request per chat, retry once,
/// and say loudly which chat failed and why.
class ReadReceiptQueue extends Notifier<void> {
  /// How long receipts are held before being sent.
  ///
  /// Long enough that a scroll through several posts of one channel becomes a
  /// single request, short enough that closing the app straight after reading
  /// still gets them out.
  static const Duration flushDelay = Duration(seconds: 2);

  /// How long to wait before the one retry.
  static const Duration retryDelay = Duration(seconds: 5);

  final Set<String> _pending = {};

  /// Chats TDLib has **confirmed** are open, so the ack can be sent with
  /// `forceRead: false` — for an open chat it is the honest signal rather than
  /// an assertion.
  ///
  /// Confirmed, not merely requested. `OpenChat` used to be fire-and-forget and
  /// this set was filled the moment it was dispatched, so a receipt flushed in
  /// the gap went out against a chat TDLib did not yet consider open. TDLib
  /// declines to write that through but still answers `Ok`, so the retry never
  /// fired and the read was lost in silence.
  final Set<int> _openChats = {};

  Timer? _flushTimer;

  @override
  void build() {
    ref.onDispose(() {
      _flushTimer?.cancel();
      _flushTimer = null;
    });
  }

  /// Tells the queue which chat TDLib has confirmed open.
  ///
  /// Pass null while a swap is in flight: an unconfirmed chat falls back to
  /// `forceRead: true`, which is the honest reading of what happened — the
  /// reader did read the post, whatever TDLib currently thinks is open.
  void setOpenChat(int? chatId) {
    _openChats.clear();
    if (chatId != null) _openChats.add(chatId);
  }

  /// Queues a post as read. Safe to call repeatedly for the same post.
  void add(String postId) {
    _pending.add(postId);
    _flushTimer ??= Timer(flushDelay, flush);
  }

  /// Sends everything held, now. Called on the timer, and by anything that
  /// wants the reader's state out before it stops caring — opening a post.
  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pending.isEmpty) return;

    final batch = groupReadReceipts(_pending);
    _pending.clear();

    final repo = ref.read(feedRepositoryProvider);
    for (final entry in batch.entries) {
      await _send(repo, entry.key, entry.value, isRetry: false);
    }
  }

  Future<void> _send(
    FeedRepository repo,
    int chatId,
    List<int> messageIds, {
    required bool isRetry,
  }) async {
    final error = await repo.markMessagesRead(
      chatId: chatId,
      messageIds: messageIds,
      // "Take my word for it" only where it has to be taken: for the chat the
      // reader is actually in, the open chat is the honest signal.
      forceRead: !_openChats.contains(chatId),
    );
    if (error == null) return;

    debugPrint('[Read] chat $chatId × ${messageIds.length} failed: $error'
        '${isRetry ? ' (final)' : ' — retrying'}');
    if (isRetry) return;

    // One retry, spaced past a short flood wait. Two would be a queue that
    // hammers a rate limit the user is already sitting behind.
    Future<void>.delayed(retryDelay, () {
      _send(repo, chatId, messageIds, isRetry: true);
    });
  }
}

final readReceiptQueueProvider =
    NotifierProvider<ReadReceiptQueue, void>(ReadReceiptQueue.new);
