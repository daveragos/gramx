import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

import '../support/td_fixtures.dart';

const int _chatId = -100700;

/// Answers `GetChatHistory` like TDLib: newest first, back from
/// `fromMessageId` (exclusive), at most [batchCap] at a time, since TDLib often
/// returns fewer messages than asked for.
class _HistoryTdlib implements TdlibService {
  final List<int> ids;
  final int batchCap;
  final List<int> asked = [];
  final List<List<int>> fetched = [];

  /// Which loaded messages reply to which, by id.
  final Map<int, int> replies = {};

  _HistoryTdlib(this.ids, {this.batchCap = 100});

  @override
  Stream<td.TdObject> get updatesStream => const Stream.empty();

  @override
  Future<td.TdObject> sendRequest(
    td.TdFunction function, {
    String? extraId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (function is td.GetMessages) {
      fetched.add(function.messageIds);
      return td.Messages(
        totalCount: function.messageIds.length,
        messages: [
          for (final id in function.messageIds)
            TdFixtures.chatMessage(
              id: id,
              chatId: _chatId,
              senderUserId: 2,
              text: 'older message $id',
            ),
        ],
      );
    }
    if (function is! td.GetChatHistory) {
      throw UnimplementedError('unexpected ${function.runtimeType}');
    }
    asked.add(function.fromMessageId);
    final from = function.fromMessageId;
    final older = [
      for (final id in ids.reversed)
        if (from == 0 || id < from) id,
    ];
    final page = older.take(function.limit).take(batchCap);
    return td.Messages(
      totalCount: ids.length,
      messages: [
        for (final id in page)
          TdFixtures.chatMessage(
            id: id,
            chatId: _chatId,
            senderUserId: 2,
            replyToMessageId: replies[id],
          ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

ChatsRepository _repository(_HistoryTdlib tdlib) =>
    ChatsRepository(tdlib, ChatCache(tdlib));

void main() {
  // An unread chat loads from the read cursor through to the newest message.
  group('opening an unread chat', () {
    test(
      'loads everything from the read line down to the newest message',
      () async {
        // 200 messages, read up to 150, so 50 are unread.
        final ids = [for (var i = 1; i <= 200; i++) i];
        final tdlib = _HistoryTdlib(ids, batchCap: 40);

        final page = await _repository(
          tdlib,
        ).historyReaching(_chatId, messageId: 150);
        final loaded = page.messages.map((m) => m.messageId).toList();

        expect(loaded.last, 200, reason: 'the newest message is there');
        expect(
          loaded.first,
          lessThanOrEqualTo(150),
          reason: 'the read line is covered',
        );
        // One unbroken run: no hole between the read line and the bottom.
        for (var i = 1; i < loaded.length; i++) {
          expect(loaded[i], loaded[i - 1] + 1);
        }
        expect(page.reachedTop, isFalse);
      },
    );

    test('stops at the cap when the backlog is enormous', () async {
      final ids = [for (var i = 1; i <= 5000; i++) i];
      final tdlib = _HistoryTdlib(ids, batchCap: 40);

      final page = await _repository(
        tdlib,
      ).historyReaching(_chatId, messageId: 10);

      expect(page.messages.last.messageId, 5000);
      expect(
        page.messages.length,
        lessThanOrEqualTo(
          ChatsRepository.backlogMaxMessages + ChatsRepository.historyPageSize,
        ),
      );
      // Bounded requests, however far back the read line is.
      expect(tdlib.asked.length, lessThan(10));
    });

    // One request fetches every reply target older than the page.
    test('fetches what replies are answering, once per page', () async {
      final ids = [for (var i = 1; i <= 60; i++) i];
      final tdlib = _HistoryTdlib(ids, batchCap: 100)
        ..replies.addAll({55: 3, 58: 4, 59: 55});

      final page = await _repository(tdlib).history(_chatId, limit: 20);
      final byId = {for (final m in page.messages) m.messageId: m};

      expect(tdlib.fetched, hasLength(1), reason: 'one request, not one each');
      expect(tdlib.fetched.single, unorderedEquals([3, 4]));
      expect(byId[55]?.replyToText, 'older message 3');
      expect(byId[58]?.replyToText, 'older message 4');
      // On the page already: filled without asking.
      expect(byId[59]?.replyToText, isNotNull);
    });

    test('says when it reached the top of a short chat', () async {
      final tdlib = _HistoryTdlib([1, 2, 3, 4, 5], batchCap: 2);

      final page = await _repository(
        tdlib,
      ).historyReaching(_chatId, messageId: 1);

      expect(page.messages.map((m) => m.messageId), [1, 2, 3, 4, 5]);
    });
  });
}
