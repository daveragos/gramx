import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

import '../support/td_fixtures.dart';

const _channel = -100500;
const _album = 777;

/// Holds a channel with a three-picture album (ids 10 to 12) between two
/// other posts, and records what is forwarded.
class _AlbumTdlib implements TdlibService {
  final List<td.ForwardMessages> forwards = [];
  final _updates = StreamController<td.TdObject>.broadcast();

  static td.Message _photo(int id, {int albumId = _album}) =>
      TdFixtures.photoMessage(
        id: id,
        chatId: _channel,
        fileIds: [id],
        albumId: albumId,
      );

  @override
  Stream<td.TdObject> get updatesStream => _updates.stream;

  @override
  Future<td.TdObject> sendRequest(
    td.TdFunction function, {
    String? extraId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    switch (function) {
      case td.GetMessage(:final messageId):
        return _photo(messageId);
      case td.GetChatHistory():
        // Newest first, as TDLib answers.
        return td.Messages(
          totalCount: 5,
          messages: [
            _photo(13, albumId: 0),
            _photo(12),
            _photo(11),
            _photo(10),
            _photo(9, albumId: 0),
          ],
        );
      case td.ForwardMessages():
        forwards.add(function);
        return const td.Messages(totalCount: 0, messages: []);
      default:
        return const td.Ok();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _UnusedDatabase implements AppDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _UnusedSync implements SyncService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Post _post({required int messageId, int albumId = 0}) => Post(
  id: '${_channel}_$messageId',
  chatId: _channel,
  channelId: '$_channel',
  messageId: messageId,
  mediaAlbumId: albumId,
  channelTitle: 'Pictures',
  publishedAt: DateTime(2026, 10, 22),
);

void main() {
  late _AlbumTdlib tdlib;
  late FeedRepository repository;

  setUp(() {
    tdlib = _AlbumTdlib();
    repository = FeedRepository(
      tdlib,
      _UnusedDatabase(),
      _UnusedSync(),
      ChatCache(tdlib),
    );
  });

  test('an album post forwards every picture, oldest first', () async {
    await repository.forwardPost(
      post: _post(messageId: 10, albumId: _album),
      toChatId: 42,
    );

    expect(tdlib.forwards.single.messageIds, [10, 11, 12]);
    expect(tdlib.forwards.single.fromChatId, _channel);
  });

  test('a post of one message forwards just that message', () async {
    await repository.forwardPost(post: _post(messageId: 13), toChatId: 42);

    expect(tdlib.forwards.single.messageIds, [13]);
  });
}
