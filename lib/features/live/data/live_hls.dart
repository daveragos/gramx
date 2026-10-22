import 'dart:math';
import 'dart:typed_data';

import 'package:gramx/features/live/data/mp4_fragmenter.dart';
import 'package:gramx/features/live/data/stream_segment.dart';

/// One media segment of a live HLS playlist.
class LiveHlsSegment {
  final int sequence;
  final int initId;
  final Uint8List bytes;

  /// In seconds.
  final double duration;

  /// Whether timestamps or the init segment change at this segment.
  final bool discontinuity;

  const LiveHlsSegment({
    required this.sequence,
    required this.initId,
    required this.bytes,
    required this.duration,
    required this.discontinuity,
  });
}

/// The last few seconds of a live stream as fragmented-MP4 HLS: the
/// playlist, the init segments and the media segments it names.
///
/// Players poll the playlist and fetch new segments as they appear, so only
/// a short window is kept.
class LiveHlsWindow {
  /// How many segments the playlist keeps.
  final int capacity;

  /// Every segment is about one second, Telegram's piece length.
  static const int targetDuration = 1;

  final List<LiveHlsSegment> _segments = [];
  final Map<int, Uint8List> _inits = {};
  int _nextSequence = 0;
  int _discontinuitySequence = 0;

  LiveHlsWindow({this.capacity = 12});

  int get length => _segments.length;

  /// The sequence number the next segment gets.
  int get nextSequence => _nextSequence;

  void addInit(int id, Uint8List bytes) => _inits[id] = bytes;

  void add(
    Uint8List bytes, {
    required int initId,
    required double duration,
    bool discontinuity = false,
  }) {
    _segments.add(
      LiveHlsSegment(
        sequence: _nextSequence++,
        initId: initId,
        bytes: bytes,
        duration: duration,
        discontinuity: discontinuity,
      ),
    );
    while (_segments.length > capacity) {
      final dropped = _segments.removeAt(0);
      // The playlist counts the discontinuities that slid out of it.
      if (dropped.discontinuity) _discontinuitySequence++;
    }
    final inUse = {for (final s in _segments) s.initId};
    _inits.removeWhere((id, _) => !inUse.contains(id));
  }

  Uint8List? init(int id) => _inits[id];

  Uint8List? segment(int sequence) {
    for (final s in _segments) {
      if (s.sequence == sequence) return s.bytes;
    }
    return null;
  }

  /// The media playlist, with no end tag since the stream goes on.
  String playlist({
    required String Function(int initId) initUri,
    required String Function(int sequence) segmentUri,
  }) {
    final out = StringBuffer()
      ..writeln('#EXTM3U')
      ..writeln('#EXT-X-VERSION:7')
      ..writeln('#EXT-X-TARGETDURATION:$targetDuration')
      ..writeln(
        '#EXT-X-MEDIA-SEQUENCE:${_segments.isEmpty ? _nextSequence : _segments.first.sequence}',
      )
      ..writeln('#EXT-X-DISCONTINUITY-SEQUENCE:$_discontinuitySequence');
    int? lastInit;
    for (final s in _segments) {
      if (s.discontinuity) out.writeln('#EXT-X-DISCONTINUITY');
      if (s.initId != lastInit) {
        out.writeln('#EXT-X-MAP:URI="${initUri(s.initId)}"');
        lastInit = s.initId;
      }
      out
        ..writeln('#EXTINF:${s.duration.toStringAsFixed(3)},')
        ..writeln(segmentUri(s.sequence));
    }
    return out.toString();
  }
}

/// Turns Telegram's live-stream pieces into [window]'s segments.
///
/// Each piece is a plain MP4 whose timestamps start at zero, cut from the
/// stream every [stepMs], and its last sample's duration is cut short (one
/// tick for video). So each track's last duration is repaired: video fills
/// out to the next cut, since every piece starts on a frame at its cut;
/// audio frames straddle the cuts, so audio takes its usual frame length
/// and runs on from the previous piece. A track that drifts more than a few
/// samples from the piece's stream time is put back on it. After a gap, or
/// when the codecs change, timestamps restart from the piece's stream time
/// behind a discontinuity.
class LiveRemuxer {
  final LiveHlsWindow window;

  /// How far apart consecutive pieces are, in milliseconds.
  final int stepMs;

  Mp4Movie? _layout;
  int _initId = 0;
  int _fragmentSequence = 1;
  int? _lastTimeMs;
  final Map<int, int> _nextDecodeTime = {};

  LiveRemuxer(this.window, {this.stepMs = 1000});

  /// Adds the piece for [timeMs], a stream time in milliseconds. Returns
  /// false when the piece isn't an MP4 this can read.
  bool add(Uint8List piece, int timeMs) {
    final segment = StreamSegment.parse(piece);
    if (segment == null) return false;
    final Mp4Movie movie;
    try {
      movie = Mp4Movie.parse(segment.payload);
    } on FormatException {
      return false;
    }

    var discontinuity = false;
    final layout = _layout;
    if (layout == null || !movie.sameLayoutAs(layout)) {
      discontinuity = layout != null;
      _initId++;
      window.addInit(_initId, movie.initSegment());
      _layout = movie;
      _nextDecodeTime.clear();
    }

    final last = _lastTimeMs;
    final contiguous =
        !discontinuity && last != null && timeMs == last + stepMs;
    if (!contiguous) {
      if (last != null) discontinuity = true;
      for (final t in movie.tracks) {
        _nextDecodeTime[t.id] = timeMs * t.timescale ~/ 1000;
      }
    }

    final bases = <int, int>{};
    final lastDurations = <int, int>{};
    final lengths = <int, int>{};
    for (final t in movie.tracks) {
      final samples = t.samples;
      if (samples.isEmpty) continue;
      final expected = timeMs * t.timescale ~/ 1000;
      final allButLast = t.duration - samples.last.duration;
      final usual = samples.length > 1
          ? (allButLast / (samples.length - 1)).round()
          : samples.last.duration;

      var base = _nextDecodeTime[t.id] ?? expected;
      if ((base - expected).abs() > 3 * usual) base = expected;

      var last = usual;
      if (t.isVideo) {
        final fill = expected + stepMs * t.timescale ~/ 1000 - base - allButLast;
        if (fill > usual / 2 && fill < usual * 2) last = fill;
      }
      bases[t.id] = base;
      lastDurations[t.id] = last;
      lengths[t.id] = allButLast + last;
      _nextDecodeTime[t.id] = base + allButLast + last;
    }

    final fragment = movie.fragment(
      sequence: _fragmentSequence++,
      baseDecodeTimes: bases,
      lastSampleDurations: lastDurations,
    );

    final timed = movie.tracks.firstWhere(
      (t) => t.isVideo,
      orElse: () => movie.tracks.first,
    );
    final seconds = timed.timescale == 0
        ? stepMs / 1000
        : (lengths[timed.id] ?? 0) / timed.timescale;
    window.add(
      fragment,
      initId: _initId,
      duration: max(seconds, 0.001),
      discontinuity: discontinuity,
    );
    _lastTimeMs = timeMs;
    return true;
  }
}
