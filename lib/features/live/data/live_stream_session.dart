import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:gramx/features/live/data/live_hls.dart';
import 'package:gramx/features/live/data/live_hls_server.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';
import 'package:handy_tdlib/api.dart' as td;

enum LiveStreamStatus {
  /// Joining the stream as a muted viewer.
  joining,

  /// Joined, fetching the first pieces.
  buffering,

  /// [LiveStreamSession.playlistUrl] is ready for the player.
  playing,

  /// The stream is a video chat Telegram won't send as pieces, so it needs
  /// a call engine gramX doesn't have.
  unsupported,

  ended,
  failed,
}

/// Watching one live stream without a call engine.
///
/// gramX joins muted, with a join payload that no media engine backs. For an
/// RTMP stream Telegram answers in stream mode, and the stream then arrives
/// as one-second MP4 pieces through `getGroupCallStreamSegment`. Those are
/// rewrapped as live HLS ([LiveRemuxer]) and served to the platform player
/// over loopback ([LiveHlsServer]). Ordinary video chats get a WebRTC
/// answer instead, which is [LiveStreamStatus.unsupported].
class LiveStreamSession extends ChangeNotifier {
  final TdlibService _tdlib;
  final int groupCallId;

  /// RTMP streams send audio and video muxed in this channel.
  static const int unifiedChannel = 1;

  /// How far behind the stream's newest piece to start, as Telegram's docs
  /// advise for RTMP streams.
  static const int startBehindMs = 2000;

  /// Waits between requests, from Telegram's docs on downloading pieces.
  static const Duration notReadyRetry = Duration(milliseconds: 150);
  static const Duration rateLimitRetry = Duration(milliseconds: 100);

  /// Pieces in a row that can't be read before giving up.
  static const int maxUnreadable = 5;

  /// Pieces gathered before the player is pointed at the playlist.
  static const int startSegments = 2;

  final LiveHlsWindow _window = LiveHlsWindow();
  late final LiveRemuxer _remuxer = LiveRemuxer(_window);
  late final LiveHlsServer _server = LiveHlsServer(_window);

  LiveStreamStatus _status = LiveStreamStatus.joining;
  Uri? _playlistUrl;
  int? _viewerCount;
  bool _joined = false;
  bool _closed = false;
  bool _disposed = false;
  StreamSubscription<td.TdObject>? _updates;

  LiveStreamSession(this._tdlib, {required this.groupCallId});

  LiveStreamStatus get status => _status;

  /// Where the player reads the stream, once [status] is
  /// [LiveStreamStatus.playing].
  Uri? get playlistUrl => _playlistUrl;

  /// People watching, as Telegram counts them, when known.
  int? get viewerCount => _viewerCount;

  Future<void> start() async {
    _updates = _tdlib.updatesStream.listen(_onUpdate);
    unawaited(_loadViewerCount());

    final Map<String, dynamic>? mode;
    try {
      mode = await _join();
    } catch (e) {
      debugPrint('[Live] join failed: $e');
      _setStatus(LiveStreamStatus.failed);
      return;
    }
    if (_closed) return;
    // The answer can carry the stream's RTMP key for admins, so none of it
    // is ever logged.
    if (mode?['stream'] != true || mode?['rtmp'] != true) {
      await _leave();
      _setStatus(LiveStreamStatus.unsupported);
      return;
    }
    _setStatus(LiveStreamStatus.buffering);
    unawaited(_pump());
  }

  /// Leaves the stream and stops serving it. Safe to call more than once.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _updates?.cancel();
    await _server.close();
    await _leave();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(close());
    super.dispose();
  }

  /// Joins muted and returns Telegram's answer, which says whether the
  /// stream comes as pieces.
  Future<Map<String, dynamic>?> _join() async {
    final payload = joinPayload(Random.secure());
    Future<td.TdObject> join() => _tdlib.sendRequest(
      td.JoinGroupCall(
        groupCallId: groupCallId,
        audioSourceId: payload.ssrc,
        payload: payload.json,
        isMuted: true,
        isMyVideoEnabled: false,
        inviteHash: '',
      ),
      timeout: const Duration(seconds: 30),
    );

    td.TdObject answer;
    try {
      answer = await join();
    } on TdlibRequestException catch (e) {
      // Left over from a session that never left, so leave and try again.
      if (!e.message.contains('ALREADY')) rethrow;
      await _tdlib.sendRequest(td.LeaveGroupCall(groupCallId: groupCallId));
      answer = await join();
    }
    _joined = true;
    if (_closed) {
      await _leave();
      return null;
    }
    if (answer is! td.Text) return null;
    final decoded = jsonDecode(answer.text);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<void> _leave() async {
    if (!_joined) return;
    _joined = false;
    try {
      await _tdlib.sendRequest(td.LeaveGroupCall(groupCallId: groupCallId));
    } catch (e) {
      debugPrint('[Live] leave failed: $e');
    }
  }

  /// Fetches pieces one after another until closed.
  Future<void> _pump() async {
    int? time;
    var unreadable = 0;
    while (!_closed) {
      time ??= await _liveEdge();
      if (_closed) return;
      if (time == null) {
        await Future<void>.delayed(const Duration(seconds: 1));
        continue;
      }

      try {
        final piece = await _tdlib.sendRequest(
          td.GetGroupCallStreamSegment(
            groupCallId: groupCallId,
            timeOffset: time,
            scale: 0,
            channelId: unifiedChannel,
            videoQuality: const td.GroupCallVideoQualityFull(),
          ),
          timeout: const Duration(seconds: 10),
        );
        if (_closed) return;
        final added =
            piece is td.FilePart &&
            _remuxer.add(base64Decode(piece.data), time);
        time += 1000;
        if (!added) {
          if (++unreadable >= maxUnreadable) {
            await close();
            _setStatus(LiveStreamStatus.unsupported);
            return;
          }
          continue;
        }
        unreadable = 0;
        if (_playlistUrl == null && _window.length >= startSegments) {
          _playlistUrl = await _server.start();
          _setStatus(LiveStreamStatus.playing);
        }
      } on TdlibRequestException catch (e) {
        final message = e.message;
        if (message.contains('TIME_TOO_BIG')) {
          // Not cut yet.
          await Future<void>.delayed(notReadyRetry);
        } else if (e.isFloodWait) {
          await Future<void>.delayed(rateLimitRetry);
        } else if (message.contains('GROUPCALL_JOIN_MISSING') ||
            message.contains('GROUPCALL_FORBIDDEN')) {
          await _rejoin();
          time = null;
        } else {
          // TIME_TOO_SMALL and the rest: the stream moved on, so catch up.
          time = null;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      } on TimeoutException {
        time = null;
      }
    }
  }

  /// Where to start fetching: just behind the newest piece, or null while
  /// the stream has none yet.
  Future<int?> _liveEdge() async {
    try {
      final streams = await _tdlib.sendRequest(
        td.GetGroupCallStreams(groupCallId: groupCallId),
      );
      if (streams is! td.GroupCallStreams) return null;
      for (final s in streams.streams) {
        if (s.channelId == unifiedChannel) {
          return startTime(s.timeOffset);
        }
      }
    } catch (e) {
      debugPrint('[Live] streams: $e');
    }
    return null;
  }

  Future<void> _rejoin() async {
    await _leave();
    try {
      await _join();
    } catch (e) {
      debugPrint('[Live] rejoin failed: $e');
    }
  }

  Future<void> _loadViewerCount() async {
    try {
      final call = await _tdlib.sendRequest(
        td.GetGroupCall(groupCallId: groupCallId),
      );
      if (call is td.GroupCall) _onGroupCall(call);
    } catch (_) {}
  }

  void _onUpdate(td.TdObject update) {
    if (update is td.UpdateGroupCall && update.groupCall.id == groupCallId) {
      _onGroupCall(update.groupCall);
    }
  }

  void _onGroupCall(td.GroupCall call) {
    if (_closed) return;
    if (!call.isActive && call.scheduledStartDate == 0) {
      unawaited(close());
      _setStatus(LiveStreamStatus.ended);
      return;
    }
    if (call.needRejoin && _joined) unawaited(_rejoin());
    if (call.participantCount != _viewerCount) {
      _viewerCount = call.participantCount;
      if (!_disposed) notifyListeners();
    }
  }

  void _setStatus(LiveStreamStatus status) {
    if (_status == status) return;
    _status = status;
    if (!_disposed) notifyListeners();
  }

  /// The piece to start from for a stream whose newest piece ends at
  /// [newestMs]: rounded down to a whole piece, [startBehindMs] back.
  @visibleForTesting
  static int startTime(int newestMs) => (newestMs ~/ 1000) * 1000 - startBehindMs;

  /// A join payload in the documented shape: a random audio source, ICE
  /// credentials and a DTLS fingerprint. Nothing ever connects with them.
  @visibleForTesting
  static ({int ssrc, String json}) joinPayload(Random random) {
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+/';
    String token(int length) => List.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    final fingerprint = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0').toUpperCase(),
    ).join(':');
    final ssrc = 1 + random.nextInt(0x7ffffffe);
    final json = jsonEncode({
      'ufrag': token(4),
      'pwd': token(24),
      'fingerprints': [
        {'hash': 'sha-256', 'setup': 'passive', 'fingerprint': fingerprint},
      ],
      'ssrc': ssrc,
    });
    return (ssrc: ssrc, json: json);
  }
}
