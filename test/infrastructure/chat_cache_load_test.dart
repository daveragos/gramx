import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

import '../support/td_fixtures.dart';

/// Answers `LoadChats` like TDLib: chats arrive as updates, then `Ok` or 404.
class _ListTdlib implements TdlibService {
  final List<td.Chat> chats;
  final _updates = StreamController<td.TdObject>.broadcast();
  int loadChatsCalls = 0;
  bool signedIn = true;

  /// When set, the second `LoadChats` waits on it, like a slow server page.
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
  // Several repositories ask for the chat list at startup and share one load.
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

      // One round that loaded and one that answered 404, not per caller.
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

    // Requests fail before sign-in, and that empty result is not "no chats".
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

  // The feed paints after the first page; later rounds can take seconds.
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

    test('the next round arrives, and so does the end of the load', () async {
      final tdlib = _ListTdlib([TdFixtures.chat(id: -1001, mainOrder: 1)])
        ..holdSecondPage = Completer<void>();
      final cache = ChatCache(tdlib);
      await cache.ensureFirstPage();
      expect(cache.isLoading, isTrue);

      final next = cache.nextRound();
      tdlib.holdSecondPage!.complete();
      await next;
      await cache.ensureLoaded();

      expect(cache.isLoading, isFalse);
      // Nothing in flight: asking again does not wait.
      await cache.nextRound();
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
