import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/activity/data/activity_repository.dart';
import 'package:gramx/features/activity/domain/activity_item.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

import '../support/td_fixtures.dart';

/// Records what is asked of it and answers everything with Ok.
class _RecordingTdlib implements TdlibService {
  final List<td.TdFunction> asked = [];
  final _updates = StreamController<td.TdObject>.broadcast();

  @override
  Stream<td.TdObject> get updatesStream => _updates.stream;

  @override
  Future<td.TdObject> sendRequest(
    td.TdFunction function, {
    String? extraId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    asked.add(function);
    return const td.Ok();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

ChatSummary _chat(
  int id, {
  int mentions = 0,
  int reactions = 0,
  DateTime? at,
}) => ChatSummary(
  chatId: id,
  kind: ChatKind.group,
  title: 'Chat $id',
  unreadMentionCount: mentions,
  unreadReactionCount: reactions,
  lastMessageAt: at,
);

void main() {
  // This is the budget argument for the whole screen. A list of everything
  // that has happened to you is a request per chat over the whole chat list,
  // which the request budget forbids — unless something already knows which chats
  // have anything in them. The update stream does, for free.
  group('ActivityPlan.queriesFor', () {
    test('a chat with nothing waiting is never asked about', () {
      final queries = ActivityPlan.queriesFor([
        _chat(1),
        _chat(2),
        _chat(3, mentions: 1),
      ]);

      expect(queries.map((q) => q.chatId), [3]);
    });

    test('each count asks its own question, and only its own', () {
      final queries = ActivityPlan.queriesFor([
        _chat(1, mentions: 2),
        _chat(2, reactions: 5),
        _chat(3, mentions: 1, reactions: 1),
      ]);

      final byChat = {for (final q in queries) q.chatId: q};
      expect(byChat[1]!.wantsMentions, isTrue);
      expect(byChat[1]!.wantsReactions, isFalse);
      expect(byChat[2]!.wantsMentions, isFalse);
      expect(byChat[2]!.wantsReactions, isTrue);
      expect(byChat[3]!.requestCount, 2);
      expect(byChat[1]!.requestCount, 1);
    });

    // An account in fifty busy groups should cost the same as any other.
    test('the number of chats asked is capped', () {
      final chats = [
        for (var i = 0; i < ActivityPlan.maxChats + 20; i++)
          _chat(i, mentions: 1),
      ];

      expect(
        ActivityPlan.queriesFor(chats),
        hasLength(ActivityPlan.maxChats),
      );
    });

    // When the cap bites it should keep the chats the reader most likely
    // cares about, which is the ones that have moved most recently.
    test('the cap keeps the most recent chats', () {
      final chats = [
        for (var i = 0; i < ActivityPlan.maxChats + 5; i++)
          _chat(i, mentions: 1, at: DateTime(2026, 8, 1).add(Duration(days: i))),
      ];

      final kept = ActivityPlan.queriesFor(chats).map((q) => q.chatId).toSet();
      // The newest is the highest index; the oldest five are the ones dropped.
      expect(kept, contains(ActivityPlan.maxChats + 4));
      expect(kept, isNot(contains(0)));
    });

    test('a chat that has never had a message sorts last, not first', () {
      final queries = ActivityPlan.queriesFor([
        _chat(1, mentions: 1),
        _chat(2, mentions: 1, at: DateTime(2026, 8, 30)),
      ]);

      expect(queries.first.chatId, 2);
    });
  });

  group('ActivityPlan.badgeCount', () {
    test('sums both kinds across every chat', () {
      expect(
        ActivityPlan.badgeCount([
          _chat(1, mentions: 2),
          _chat(2, reactions: 3),
          _chat(3),
        ]),
        5,
      );
    });

    test('nothing waiting is no badge', () {
      expect(ActivityPlan.badgeCount([_chat(1), _chat(2)]), 0);
    });
  });

  group('ActivityRepository.itemFor', () {
    td.Message message({int id = 1, int? replyTo}) => TdFixtures.chatMessage(
      id: id,
      chatId: -100500,
      senderUserId: 7,
      text: 'hey @me look at this',
      replyToMessageId: replyTo,
    );

    test('a mention is a mention', () {
      final item = ActivityRepository.itemFor(
        message(),
        chatTitle: 'Flutter Devs',
        isChannelPost: false,
        isReaction: false,
      );

      expect(item.kind, ActivityKind.mention);
      expect(item.chatTitle, 'Flutter Devs');
      expect(item.preview, 'hey @me look at this');
    });

    // Telegram carries both facts on one message. The reply pointer is the
    // more specific of the two, so it wins — "replied to you" says more than
    // "mentioned you" about the same event.
    test('a mention that is also a reply is a reply', () {
      final item = ActivityRepository.itemFor(
        message(replyTo: 99),
        chatTitle: 'Flutter Devs',
        isChannelPost: false,
        isReaction: false,
      );

      expect(item.kind, ActivityKind.reply);
    });

    test('a reaction is a reaction whatever the message is', () {
      final item = ActivityRepository.itemFor(
        message(replyTo: 99),
        chatTitle: 'Flutter Devs',
        isChannelPost: false,
        isReaction: true,
      );

      expect(item.kind, ActivityKind.reaction);
    });

    // One message can be both a mention of you and a reaction to you, and
    // those are two things that happened rather than one row.
    test('the id separates the kinds on one message', () {
      final mention = ActivityRepository.itemFor(
        message(),
        chatTitle: '',
        isChannelPost: false,
        isReaction: false,
      );
      final reaction = ActivityRepository.itemFor(
        message(),
        chatTitle: '',
        isChannelPost: false,
        isReaction: true,
      );

      expect(mention.id, isNot(reaction.id));
      expect(mention, isNot(reaction));
    });

    test('a sender the cache does not know leaves the row without a name', () {
      final item = ActivityRepository.itemFor(
        message(),
        chatTitle: 'Flutter Devs',
        isChannelPost: false,
        isReaction: false,
      );

      expect(item.senderName, isNull);
      // The colour still has to follow something, or every unnamed row is the
      // same colour.
      expect(item.senderColorSeed, -100500);
    });
  });

  group('ActivityRepository.previewOf', () {
    test('a text message is its own words, on one line', () {
      final message = TdFixtures.chatMessage(
        id: 1,
        chatId: -100,
        senderUserId: 7,
        text: 'first line\n\n  second line ',
      );

      expect(
        ActivityRepository.previewOf(message),
        'first line second line',
      );
    });

    // A photo somebody tagged you under still happened. An empty row would
    // say nothing at all about it.
    test('a photo with no caption still says something', () {
      final message = TdFixtures.photoMessage(
        id: 1,
        chatId: -100,
        fileIds: [9],
      );

      expect(ActivityRepository.previewOf(message), isNotEmpty);
    });

    test('a captioned photo prefers the caption', () {
      final message = TdFixtures.photoMessage(
        id: 1,
        chatId: -100,
        fileIds: [9],
        caption: 'look at this',
      );

      expect(ActivityRepository.previewOf(message), 'look at this');
    });
  });

  // The bell counts unread mentions and reactions, and only Telegram can
  // take them off it. Seeing the list is what does so — for exactly the
  // chats the list asked about, and without touching any chat's read cursor.
  group('ActivityRepository.markSeen', () {
    test('acknowledges each kind in each chat that had it', () async {
      final tdlib = _RecordingTdlib();
      final repository = ActivityRepository(tdlib, ChatCache(tdlib));

      await repository.markSeen([
        _chat(1, mentions: 2),
        _chat(2, reactions: 1),
        _chat(3, mentions: 1, reactions: 1),
        _chat(4),
      ]);

      final mentions = tdlib.asked.whereType<td.ReadAllChatMentions>();
      final reactions = tdlib.asked.whereType<td.ReadAllChatReactions>();
      expect(mentions.map((r) => r.chatId), [1, 3]);
      expect(reactions.map((r) => r.chatId), [2, 3]);
      // Nothing else — in particular nothing that moves a read cursor.
      expect(tdlib.asked, hasLength(4));
    });

    test('a chat with nothing waiting is not touched', () async {
      final tdlib = _RecordingTdlib();
      final repository = ActivityRepository(tdlib, ChatCache(tdlib));

      await repository.markSeen([_chat(1), _chat(2)]);

      expect(tdlib.asked, isEmpty);
    });
  });
}
