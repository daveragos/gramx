import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/live/data/live_stream_session.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';
import 'package:handy_tdlib/api.dart' as td;

import '../support/live_stream_fixture.dart';

/// Answers a live session's requests like Telegram does for an RTMP stream
/// whose newest piece ends at [newestMs], with pieces cut up to [lastPieceMs].
class _StreamTdlib implements TdlibService {
  final _updates = StreamController<td.TdObject>.broadcast();
  final List<td.TdFunction> asked = [];

  String joinAnswer;
  final int newestMs = 298400;
  final int lastPieceMs = 299000;

  /// Errors to answer piece requests with, first to last.
  final List<TdlibRequestException> pieceErrors = [];

  _StreamTdlib({
    this.joinAnswer =
        '{"stream":true,"rtmp":true,"rtmp_stream_key":"do-not-log-this"}',
  });

  List<int> get pieceTimes => [
    for (final f in asked.whereType<td.GetGroupCallStreamSegment>())
      f.timeOffset,
  ];

  @override
  Stream<td.TdObject> get updatesStream => _updates.stream;

  @override
  Future<td.TdObject> sendRequest(
    td.TdFunction function, {
    String? extraId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    asked.add(function);
    await Future<void>.delayed(Duration.zero);
    switch (function) {
      case td.JoinGroupCall():
        return td.Text(text: joinAnswer);
      case td.GetGroupCallStreams():
        return td.GroupCallStreams(
          streams: [
            td.GroupCallStream(channelId: 1, scale: 0, timeOffset: newestMs),
          ],
        );
      case td.GetGroupCallStreamSegment():
        if (pieceErrors.isNotEmpty) throw pieceErrors.removeAt(0);
        if (function.timeOffset > lastPieceMs) {
          throw const TdlibRequestException(400, 'TIME_TOO_BIG');
        }
        return td.FilePart(data: base64Encode(LiveStreamFixture.piece()));
      case td.LeaveGroupCall():
        return const td.Ok();
      default:
        throw const TdlibRequestException(400, 'UNEXPECTED');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 400 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue);
}

Future<String> _get(Uri url) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(url)).close();
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close();
  }
}

void main() {
  late List<String> logs;
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    logs = [];
    originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
  });

  tearDown(() => debugPrint = originalDebugPrint);

  test('plays an RTMP stream from just behind its newest piece', () async {
    final tdlib = _StreamTdlib();
    final session = LiveStreamSession(tdlib, groupCallId: 5);

    await session.start();
    await _until(() => session.status == LiveStreamStatus.playing);

    final join = tdlib.asked.whereType<td.JoinGroupCall>().single;
    expect(join.isMuted, isTrue);
    expect(join.isMyVideoEnabled, isFalse);
    expect(tdlib.pieceTimes.take(2), [296000, 297000]);
    expect(
      tdlib.asked.whereType<td.GetGroupCallStreamSegment>().first.videoQuality,
      isA<td.GroupCallVideoQualityFull>(),
    );

    final playlist = await _get(session.playlistUrl!);
    expect(playlist, contains('#EXT-X-MAP:URI="init1.mp4"'));
    expect(playlist, contains('0.m4s'));

    await session.close();
    expect(tdlib.asked.last, isA<td.LeaveGroupCall>());
    expect(tdlib.asked.whereType<td.LeaveGroupCall>(), hasLength(1));
    // The join answer carries the RTMP key for admins.
    expect(logs.where((l) => l.contains('do-not-log-this')), isEmpty);
  });

  test('leaves a video chat that answers with WebRTC', () async {
    final tdlib = _StreamTdlib(joinAnswer: '{"transport":{"ufrag":"x"}}');
    final session = LiveStreamSession(tdlib, groupCallId: 5);

    await session.start();

    expect(session.status, LiveStreamStatus.unsupported);
    expect(tdlib.asked.whereType<td.LeaveGroupCall>(), hasLength(1));
    expect(tdlib.pieceTimes, isEmpty);
    await session.close();
    expect(tdlib.asked.whereType<td.LeaveGroupCall>(), hasLength(1));
  });

  test('retries a piece that isn\'t cut or is rate-limited', () async {
    final tdlib = _StreamTdlib()
      ..pieceErrors.addAll([
        const TdlibRequestException(400, 'TIME_TOO_BIG'),
        const TdlibRequestException(429, 'Too Many Requests: retry after 44'),
      ]);
    final session = LiveStreamSession(tdlib, groupCallId: 5);

    await session.start();
    await _until(() => session.status == LiveStreamStatus.playing);

    expect(tdlib.pieceTimes.take(4), [296000, 296000, 296000, 297000]);
    await session.close();
  });

  test('catches up with the stream after falling behind it', () async {
    final tdlib = _StreamTdlib()
      ..pieceErrors.add(const TdlibRequestException(400, 'TIME_TOO_SMALL'));
    final session = LiveStreamSession(tdlib, groupCallId: 5);

    await session.start();
    await _until(() => session.status == LiveStreamStatus.playing);

    expect(tdlib.asked.whereType<td.GetGroupCallStreams>().length, 2);
    await session.close();
  });

  test('gives up on pieces it can\'t read', () async {
    final tdlib = _NotMp4Tdlib();
    final session = LiveStreamSession(tdlib, groupCallId: 5);

    await session.start();
    await _until(() => session.status == LiveStreamStatus.unsupported);

    expect(tdlib.asked.whereType<td.LeaveGroupCall>(), hasLength(1));
  });

  test('starts two seconds behind the newest whole piece', () {
    expect(LiveStreamSession.startTime(298400), 296000);
    expect(LiveStreamSession.startTime(300000), 298000);
  });

  test('joins with a payload in the documented shape', () {
    final payload = LiveStreamSession.joinPayload(Random(1));
    final json = jsonDecode(payload.json) as Map<String, dynamic>;

    expect(json['ssrc'], payload.ssrc);
    expect(payload.ssrc, greaterThan(0));
    expect(json['ufrag'], hasLength(4));
    expect(json['pwd'], hasLength(24));
    final fingerprint = (json['fingerprints'] as List).single as Map;
    expect(fingerprint['hash'], 'sha-256');
    expect(
      fingerprint['fingerprint'],
      matches(RegExp(r'^([0-9A-F]{2}:){31}[0-9A-F]{2}$')),
    );
  });

  test('piece requests skip the app-wide flood gate', () {
    expect(
      TdlibService.isStreamRequest(
        const td.GetGroupCallStreamSegment(
          groupCallId: 1,
          timeOffset: 0,
          scale: 0,
          channelId: 1,
        ),
      ),
      isTrue,
    );
    expect(
      TdlibService.isStreamRequest(const td.GetGroupCallStreams(groupCallId: 1)),
      isFalse,
    );
  });
}

/// A stream whose pieces aren't MP4.
class _NotMp4Tdlib extends _StreamTdlib {
  @override
  Future<td.TdObject> sendRequest(
    td.TdFunction function, {
    String? extraId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (function is td.GetGroupCallStreamSegment) {
      asked.add(function);
      return td.FilePart(data: base64Encode(List.filled(64, 1)));
    }
    return super.sendRequest(function, extraId: extraId, timeout: timeout);
  }
}
