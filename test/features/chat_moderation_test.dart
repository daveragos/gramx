import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

import '../support/td_fixtures.dart';

/// Feeds the chat cache from [push] and answers every request with `ok`,
/// remembering each one.
class _RecordingTdlib implements TdlibService {
  final _updates = StreamController<td.TdObject>.broadcast();
  final List<td.TdFunction> asked = [];

  Future<void> push(td.TdObject update) async {
    _updates.add(update);
    await Future<void>.delayed(Duration.zero);
  }

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

void main() {
  late _RecordingTdlib tdlib;
  late ChatCache cache;
  late ChatsRepository repository;

  setUp(() {
    tdlib = _RecordingTdlib();
    cache = ChatCache(tdlib);
    repository = ChatsRepository(tdlib, cache);
  });

  group('leaving', () {
    test('a group can be left; a one-to-one chat cannot', () async {
      await tdlib.push(TdFixtures.newChat(TdFixtures.groupChat(id: -100300)));
      await tdlib.push(TdFixtures.newChat(TdFixtures.basicGroupChat(id: -300)));
      await tdlib.push(TdFixtures.newChat(TdFixtures.privateChat(id: 42)));

      expect(repository.canLeave(-100300), isTrue);
      expect(repository.canLeave(-300), isTrue);
      expect(repository.canLeave(42), isFalse);
    });

    // Telegram keeps a basic group you left as a read-only chat on the list.
    // Leaving has to take it off, or "Leave" looks like it did nothing.
    test('a basic group is taken off the list as well as left', () async {
      await tdlib.push(TdFixtures.newChat(TdFixtures.basicGroupChat(id: -300)));

      expect(await repository.leaveChat(-300), isTrue);

      expect(tdlib.asked.first, isA<td.LeaveChat>());
      final removal = tdlib.asked.whereType<td.DeleteChatHistory>().single;
      expect(removal.removeFromChatList, isTrue);
      expect(removal.revoke, isFalse);
    });

    test(
      'a supergroup drops off by itself, so leaving is all it takes',
      () async {
        await tdlib.push(TdFixtures.newChat(TdFixtures.groupChat(id: -100300)));

        await repository.leaveChat(-100300);

        expect(tdlib.asked, [isA<td.LeaveChat>()]);
      },
    );
  });

  group('deleting a chat', () {
    test('removes it from the list, for both sides only when asked', () async {
      await tdlib.push(TdFixtures.newChat(TdFixtures.privateChat(id: 42)));

      await repository.deleteChat(42, revoke: false);
      await repository.deleteChat(42, revoke: true);

      final calls = tdlib.asked.whereType<td.DeleteChatHistory>().toList();
      expect(calls.map((c) => c.removeFromChatList), [true, true]);
      expect(calls.map((c) => c.revoke), [false, true]);
    });

    // Deleting the history of a live end-to-end session would leave the
    // session itself open on both devices.
    test('closes a secret chat before deleting it', () async {
      await tdlib.push(
        TdFixtures.newChat(TdFixtures.secretChat(id: 77, userId: 42)),
      );

      await repository.deleteChat(77, revoke: false);

      expect(tdlib.asked, [
        isA<td.CloseSecretChat>(),
        isA<td.DeleteChatHistory>(),
      ]);
    });
  });

  group('blocking', () {
    test('blocks into the main list, and unblocks by clearing it', () async {
      await repository.setBlocked(42, isBlocked: true);
      await repository.setBlocked(42, isBlocked: false);

      final calls = tdlib.asked.whereType<td.SetMessageSenderBlockList>();
      expect(calls.first.blockList, isA<td.BlockListMain>());
      expect(calls.last.blockList, isNull);
      expect(calls.map((c) => (c.senderId as td.MessageSenderUser).userId), [
        42,
        42,
      ]);
    });

    // Read off the chat record, so a block made anywhere has to land on it.
    test('is read from the chat, and follows TDLib when it changes', () async {
      await tdlib.push(TdFixtures.newChat(TdFixtures.privateChat(id: 42)));
      expect(repository.isBlocked(42), isFalse);

      await tdlib.push(
        const td.UpdateChatBlockList(chatId: 42, blockList: td.BlockListMain()),
      );
      expect(repository.isBlocked(42), isTrue);

      await tdlib.push(const td.UpdateChatBlockList(chatId: 42));
      expect(repository.isBlocked(42), isFalse);
    });
  });

  // Telegram refuses to turn media into text, so "Edit" on a photo always
  // failed while it sent EditMessageText.
  group('editing', () {
    test('text is edited as text, and media by its caption', () async {
      await repository.editText(chatId: 42, messageId: 1, text: 'words');
      await repository.editText(
        chatId: 42,
        messageId: 2,
        text: 'a caption',
        isCaption: true,
      );

      expect(tdlib.asked, [
        isA<td.EditMessageText>(),
        isA<td.EditMessageCaption>().having(
          (c) => c.caption?.text,
          'caption',
          'a caption',
        ),
      ]);
    });
  });
}
