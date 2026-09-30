import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

import '../support/td_fixtures.dart';

/// A TDLib that answers `LoadChats` the way the real one does: the chats
/// arrive as updates, the reply is `Ok`, and once there is nothing left the
/// reply is a 404.
class _ListTdlib implements TdlibService {
  final List<td.Chat> chats;
  final _updates = StreamController<td.TdObject>.broadcast();
  int loadChatsCalls = 0;
  bool signedIn = true;

  /// When set, the second `LoadChats` waits on it: a later page still on its
  /// way from the server.
  Completer<void>? holdSecondPage;

  _ListTdlib(this.chats);

  @override
  Stream<td.TdObject> get updatesStream => _updates.stream;

  @override
  Future<td.TdObject> sendRequest(
    td.TdFunction function, {
    String? extraId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (function is td.LoadChats) {
      loadChatsCalls++;
      if (!signedIn) throw const TdlibRequestException(401, 'Unauthorized');
      if (loadChatsCalls > 1) {
        await holdSecondPage?.future;
        throw const TdlibRequestException(404, 'Not Found');
      }
      for (final chat in chats) {
        _updates.add(TdFixtures.newChat(chat));
      }
      return const td.Ok();
    }
    throw UnimplementedError('unexpected ${function.runtimeType}');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  // The cold-start cost this guards: three repositories asked for the chat
  // list on the way to the first feed, and each rebuilt when the first
  // channel landed, so the whole load ran five or six times in a row.
  group('ChatCache.ensureLoaded', () {
    test('concurrent callers share one load', () async {
      final tdlib = _ListTdlib([
        TdFixtures.chat(id: -1001, mainOrder: 3),
        TdFixtures.chat(id: -1002, mainOrder: 2),
      ]);
      final cache = ChatCache(tdlib);

      await Future.wait([
        cache.ensureLoaded(),
        cache.ensureLoaded(),
        cache.ensureLoaded(),
      ]);

      // One round that loaded, one that answered 404 — and not per caller.
      expect(tdlib.loadChatsCalls, 2);
      expect(cache.isLoaded, isTrue);
      expect(cache.channels.length, 2);
    });

    test('once loaded, asking again costs nothing', () async {
      final tdlib = _ListTdlib([TdFixtures.chat(id: -1001, mainOrder: 1)]);
      final cache = ChatCache(tdlib);
      await cache.ensureLoaded();
      final after = tdlib.loadChatsCalls;

      await cache.ensureLoaded();
      await cache.ensureLoaded();

      expect(tdlib.loadChatsCalls, after);
    });

    // Before sign-in every request fails. An empty answer then is not "no
    // chats", and remembering it would leave the feed empty for the session.
    test('a load that could not ask is not remembered', () async {
      final tdlib = _ListTdlib([TdFixtures.chat(id: -1001, mainOrder: 1)])
        ..signedIn = false;
      final cache = ChatCache(tdlib);

      await cache.ensureLoaded();
      expect(cache.isLoaded, isFalse);

      tdlib
        ..signedIn = true
        ..loadChatsCalls = 0;
      await cache.ensureLoaded();
      expect(cache.isLoaded, isTrue);
      expect(cache.channels.length, 1);
    });

    test('signing out forgets the list', () async {
      final tdlib = _ListTdlib([TdFixtures.chat(id: -1001, mainOrder: 1)]);
      final cache = ChatCache(tdlib);
      await cache.ensureLoaded();

      cache.clear();

      expect(cache.isLoaded, isFalse);
      expect(cache.isEmpty, isTrue);
    });
  });

  // The feed's first paint waited on every round of the chat list, and on a
  // long list the second round goes to the server: two and a half seconds on
  // each launch, spent on channels far below the top of the feed.
  group('ChatCache.ensureFirstPage', () {
    test('resolves while later pages are still loading', () async {
      final tdlib = _ListTdlib([TdFixtures.chat(id: -1001, mainOrder: 1)])
        ..holdSecondPage = Completer<void>();
      final cache = ChatCache(tdlib);

      await cache.ensureFirstPage();

      expect(cache.channels.length, 1);
      expect(cache.isLoaded, isFalse);

      tdlib.holdSecondPage!.complete();
      await cache.ensureLoaded();
      expect(cache.isLoaded, isTrue);
    });

    test('starts the whole load, and shares it', () async {
      final tdlib = _ListTdlib([TdFixtures.chat(id: -1001, mainOrder: 1)]);
      final cache = ChatCache(tdlib);

      await Future.wait([cache.ensureFirstPage(), cache.ensureLoaded()]);

      expect(tdlib.loadChatsCalls, 2);
      expect(cache.isLoaded, isTrue);
    });

    test('a load that fails still lets the first page go', () async {
      final tdlib = _ListTdlib([TdFixtures.chat(id: -1001, mainOrder: 1)])
        ..signedIn = false;
      final cache = ChatCache(tdlib);

      await cache.ensureFirstPage();

      expect(cache.isLoaded, isFalse);
    });
  });
}
