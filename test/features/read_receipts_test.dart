import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/presentation/read_receipt_queue.dart';

/// Records read acknowledgements instead of sending them.
///
/// `implements` plus `noSuchMethod` so the fake doesn't have to stand up a
/// TDLib client, a database and a sync service just to answer one method.
class _RecordingRepository implements FeedRepository {
  final List<({int chatId, List<int> messageIds, bool forceRead})> calls = [];

  /// Error returned by the next call, then cleared — for testing the retry.
  String? nextError;

  @override
  Future<String?> markMessagesRead({
    required int chatId,
    required List<int> messageIds,
    bool forceRead = true,
  }) async {
    calls.add((chatId: chatId, messageIds: messageIds, forceRead: forceRead));
    final error = nextError;
    nextError = null;
    return error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

void main() {
  group('groupReadReceipts', () {
    // Read state in Telegram is a cursor per chat. Six posts of one channel are
    // one acknowledgement, not six requests through the same flood gate.
    test('collapses posts into one batch per chat', () {
      final batch = groupReadReceipts([
        '-100111_10',
        '-100111_12',
        '-100222_4',
      ]);

      expect(batch.keys, unorderedEquals([-100111, -100222]));
      expect(batch[-100111], [10, 12]);
      expect(batch[-100222], [4]);
    });

    test('sorts ascending, so the id that moves the cursor is the last', () {
      expect(groupReadReceipts(['-100111_30', '-100111_9'])[-100111], [9, 30]);
    });

    test('the same post twice is acknowledged once', () {
      expect(groupReadReceipts(['-100111_10', '-100111_10'])[-100111], [10]);
    });

    // Losing one malformed receipt beats losing the batch it was in.
    test('ids that are not chatId_messageId are dropped, not thrown', () {
      final batch = groupReadReceipts(['nonsense', '', '_5', '-100111_10']);
      expect(batch, {-100111: [10]});
    });
  });

  group('ReadReceiptQueue', () {
    late _RecordingRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = _RecordingRepository();
      container = ProviderContainer(overrides: [
        feedRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
    });

    test('sends one request per chat', () async {
      final queue = container.read(readReceiptQueueProvider.notifier);
      queue.add('-100111_10');
      queue.add('-100111_12');
      queue.add('-100222_4');
      await queue.flush();

      expect(repo.calls, hasLength(2));
      expect(repo.calls.first.messageIds, [10, 12]);
    });

    // TDLib takes an open chat as genuine reading; everywhere else it has to be
    // told to write the read through.
    test('forces the read except for the chat being read', () async {
      final queue = container.read(readReceiptQueueProvider.notifier);
      queue.setOpenChat(-100111);
      queue.add('-100111_10');
      queue.add('-100222_4');
      await queue.flush();

      final open = repo.calls.firstWhere((c) => c.chatId == -100111);
      final other = repo.calls.firstWhere((c) => c.chatId == -100222);
      expect(open.forceRead, isFalse);
      expect(other.forceRead, isTrue);
    });

    test('a flush with nothing held spends no requests', () async {
      await container.read(readReceiptQueueProvider.notifier).flush();
      expect(repo.calls, isEmpty);
    });

    test('flushing twice does not acknowledge the same post again', () async {
      final queue = container.read(readReceiptQueueProvider.notifier);
      queue.add('-100111_10');
      await queue.flush();
      await queue.flush();

      expect(repo.calls, hasLength(1));
    });

    // The bug this queue exists for: a failed acknowledgement used to vanish
    // into a debug line, and the reader's Telegram stayed unread.
    test('a failure is retried', () async {
      final queue = container.read(readReceiptQueueProvider.notifier);
      repo.nextError = 'FLOOD_WAIT_12';
      queue.add('-100111_10');
      await queue.flush();
      expect(repo.calls, hasLength(1));

      await Future<void>.delayed(ReadReceiptQueue.retryDelay +
          const Duration(milliseconds: 50));

      expect(repo.calls, hasLength(2));
      expect(repo.calls.last.messageIds, [10]);
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}
