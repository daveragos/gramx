import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/presentation/read_receipt_queue.dart';
import 'package:gramx/features/feed/presentation/seen_posts_provider.dart';

/// Records read acknowledgements instead of sending them.
class _RecordingRepository implements FeedRepository {
  final List<({int chatId, List<int> messageIds, bool forceRead})> calls = [];

  /// Error returned by the next call, then cleared.
  String? nextError;

  /// Chats where nothing can be acknowledged yet.
  final Set<int> blocked = {};

  @override
  Future<List<int>> readableRun(int chatId, Set<int> seen) async =>
      blocked.contains(chatId) ? const [] : (seen.toList()..sort());

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
  // The record of seen posts reaches for the documents directory.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('groupReadReceipts', () {
    // Telegram tracks reads as a cursor per chat, so one request covers a chat.
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
      expect(batch, {
        -100111: [10],
      });
    });
  });

  group('ReadReceiptQueue', () {
    late _RecordingRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = _RecordingRepository();
      container = ProviderContainer(
        overrides: [feedRepositoryProvider.overrideWithValue(repo)],
      );
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

    // TDLib counts reads in an open chat itself; other chats need forceRead.
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

    // A chat is not open until TDLib confirms OpenChat, so the read is forced.
    test('an unconfirmed open chat still forces the read', () async {
      final queue = container.read(readReceiptQueueProvider.notifier);
      // As FeedFocusController does when focus moves.
      queue.setOpenChat(null);
      queue.add('-100111_10');
      await queue.flush();

      expect(repo.calls.single.forceRead, isTrue);
    });

    test('confirming a different chat does not soften the ack', () async {
      final queue = container.read(readReceiptQueueProvider.notifier);
      queue.setOpenChat(-100222);
      queue.add('-100111_10');
      await queue.flush();

      expect(repo.calls.single.forceRead, isTrue);
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

    // Telegram's cursor marks everything below it read, so it must not move
    // past an older post the user has not reached.
    test('sends nothing past a post the reader has not reached', () async {
      final queue = container.read(readReceiptQueueProvider.notifier);
      repo.blocked.add(-100111);
      queue.add('-100111_12');
      await queue.flush();

      expect(repo.calls, isEmpty);
      // Still remembered, so the feed keeps it out on the next launch.
      expect(
        container.read(seenPostsProvider.notifier).containsPost('-100111_12'),
        isTrue,
      );
    });

    test('forgets what an acknowledgement covered', () async {
      final queue = container.read(readReceiptQueueProvider.notifier);
      queue.add('-100111_10');
      await queue.flush();

      expect(
        container.read(seenPostsProvider.notifier).idsIn(-100111),
        isEmpty,
      );
    });

    test('a failure is retried', () async {
      final queue = container.read(readReceiptQueueProvider.notifier);
      repo.nextError = 'FLOOD_WAIT_12';
      queue.add('-100111_10');
      await queue.flush();
      expect(repo.calls, hasLength(1));

      await Future<void>.delayed(
        ReadReceiptQueue.retryDelay + const Duration(milliseconds: 50),
      );

      expect(repo.calls, hasLength(2));
      expect(repo.calls.last.messageIds, [10]);
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}
