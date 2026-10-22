import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/live/data/live_hls.dart';
import 'package:gramx/features/live/data/mp4_fragmenter.dart';
import 'package:gramx/features/live/data/stream_segment.dart';

import '../support/live_stream_fixture.dart';

typedef F = LiveStreamFixture;

void main() {
  group('StreamSegment', () {
    test('skips Telegram\'s header to the MP4 it carries', () {
      final segment = StreamSegment.parse(F.piece())!;

      expect(segment.container, 'mp4');
      expect(segment.payload, F.movie());
    });

    test('is null for bytes without the header', () {
      expect(StreamSegment.parse(F.piece(header: false)), isNull);
      expect(StreamSegment.parse(Uint8List(8)), isNull);
    });

    test('is null for a container other than MP4', () {
      final piece = F.piece();
      piece.setAll(4, [3, 0x6f, 0x67, 0x67]); // "ogg"

      expect(StreamSegment.parse(piece), isNull);
    });
  });

  group('Mp4Movie.parse', () {
    final movie = Mp4Movie.parse(F.movie());
    final video = movie.tracks.firstWhere((t) => t.isVideo);
    final audio = movie.tracks.firstWhere((t) => !t.isVideo);

    test('reads both tracks with their timescales and edit', () {
      expect(video.id, F.videoTrackId);
      expect(video.timescale, F.videoTimescale);
      expect(video.editMediaTime, F.videoEditMediaTime);
      expect(audio.id, F.audioTrackId);
      expect(audio.timescale, F.audioTimescale);
      expect(audio.editMediaTime, 0);
    });

    test('finds every sample across interleaved chunks', () {
      final bytes = F.movie();
      for (final (i, s) in video.samples.indexed) {
        expect(s.size, F.videoSize(i));
        expect(bytes[s.offset], F.videoMarker(i));
        expect(bytes[s.offset + s.size - 1], F.videoMarker(i));
      }
      for (final (i, s) in audio.samples.indexed) {
        expect(s.size, F.audioSize(i));
        expect(bytes[s.offset], F.audioMarker(i));
      }
      expect(audio.samples, hasLength(47));
    });

    test('reads durations, composition offsets and sync samples', () {
      expect([for (final s in video.samples) s.duration], F.videoDurations);
      expect(
        [for (final s in video.samples) s.compositionOffset],
        F.videoCompositionOffsets,
      );
      expect([for (final s in video.samples) s.isSync], [
        true,
        for (var i = 1; i < F.videoFrames; i++) false,
      ]);
      expect(audio.samples.every((s) => s.isSync), isTrue);
    });

    test('rejects bytes with no movie box', () {
      expect(
        () => Mp4Movie.parse(Uint8List(64)),
        throwsA(isA<FormatException>()),
      );
    });

    test('tells pieces with other codec setup apart', () {
      expect(movie.sameLayoutAs(Mp4Movie.parse(F.movie())), isTrue);
      expect(
        movie.sameLayoutAs(Mp4Movie.parse(F.movie(avcLevel: 40))),
        isFalse,
      );
    });
  });

  group('Mp4Movie.initSegment', () {
    final movie = Mp4Movie.parse(F.movie());
    final init = Mp4Reader(movie.initSegment());

    test('is an ftyp and a moov announcing fragments', () {
      expect(init.topLevel, ['ftyp', 'moov']);
      final mvex = init.find(['moov', 'mvex'])!;
      final trexIds = [
        for (final t in init.all('trex', mvex)) init.u32(t.$1 + 12),
      ];
      expect(trexIds, [F.videoTrackId, F.audioTrackId]);
    });

    test('keeps each sample description and empties the tables', () {
      final moov = init.find(['moov'])!;
      final traks = init.all('trak', moov);
      expect(traks, hasLength(2));
      for (final (i, trak) in traks.indexed) {
        final stbl = init.find(
          ['mdia', 'minf', 'stbl'],
          start: trak.$1 + 8,
          end: trak.$2,
        )!;
        final stsd = init.all('stsd', stbl).single;
        expect(
          init.bytes.sublist(stsd.$1, stsd.$2),
          movie.tracks[i].stsd,
        );
        final stts = init.all('stts', stbl).single;
        expect(init.u32(stts.$1 + 12), 0);
        // No edit list: the fragments shift timestamps themselves.
        expect(init.all('edts', trak), isEmpty);
      }
    });
  });

  group('Mp4Movie.fragment', () {
    final movie = Mp4Movie.parse(F.movie());
    final fragment = Mp4Reader(
      movie.fragment(
        sequence: 7,
        baseDecodeTimes: {F.videoTrackId: 160000, F.audioTrackId: 480000},
        lastSampleDurations: {F.videoTrackId: 528, F.audioTrackId: 1024},
      ),
    );
    final moof = fragment.find(['moof'])!;
    final trafs = fragment.all('traf', moof);

    ({int base, int flags, int count, int dataOffset, int entriesAt}) traf(
      int index,
    ) {
      final t = trafs[index];
      final tfdt = fragment.all('tfdt', t).single;
      final trun = fragment.all('trun', t).single;
      return (
        base: fragment.u64(tfdt.$1 + 12),
        flags: fragment.u32(trun.$1 + 8) & 0xffffff,
        count: fragment.u32(trun.$1 + 12),
        dataOffset: fragment.i32(trun.$1 + 16),
        entriesAt: trun.$1 + 20,
      );
    }

    test('is a numbered moof followed by an mdat', () {
      expect(fragment.topLevel, ['moof', 'mdat']);
      final mfhd = fragment.all('mfhd', moof).single;
      expect(fragment.u32(mfhd.$1 + 12), 7);
      expect(trafs, hasLength(2));
    });

    test('starts each track at its base decode time', () {
      expect(traf(0).base, 160000);
      expect(traf(1).base, 480000);
    });

    test('points each track at its own samples, laid out in order', () {
      for (final (index, marker) in [
        (0, F.videoMarker(0)),
        (1, F.audioMarker(0)),
      ]) {
        final t = traf(index);
        expect(fragment.bytes[moof.$1 + t.dataOffset], marker);
      }
      final videoData = movie.tracks.first.samples.fold<int>(
        0,
        (sum, s) => sum + s.size,
      );
      expect(traf(1).dataOffset - traf(0).dataOffset, videoData);
    });

    test('repairs the last duration and shifts composition by the edit', () {
      final video = traf(0);
      expect(video.count, F.videoFrames);
      expect(video.flags & 0x800, 0x800);
      const entrySize = 16;
      int field(int sample, int at) =>
          video.entriesAt + sample * entrySize + at;

      expect(fragment.u32(field(0, 0)), F.videoDurations.first);
      expect(fragment.u32(field(F.videoFrames - 1, 0)), 528);
      expect(fragment.u32(field(0, 4)), F.videoSize(0));
      expect(fragment.u32(field(0, 8)), 0x02000000);
      expect(fragment.u32(field(1, 8)), 0x01010000);
      // 1056 is the edit's media time, so the first frame shows at once and
      // a frame with no reordering delay gets a negative offset.
      expect(fragment.i32(field(0, 12)), 0);
      expect(fragment.i32(field(3, 12)), -F.videoEditMediaTime);

      final audio = traf(1);
      expect(audio.flags & 0x800, 0);
      const audioEntry = 12;
      expect(
        fragment.u32(audio.entriesAt + (audio.count - 1) * audioEntry),
        1024,
      );
    });
  });

  group('LiveHlsWindow', () {
    String playlist(LiveHlsWindow w) => w.playlist(
      initUri: (id) => 'init$id.mp4',
      segmentUri: (s) => '$s.m4s',
    );

    test('lists its segments behind their init segment', () {
      final w = LiveHlsWindow()
        ..addInit(1, Uint8List(1))
        ..add(Uint8List(2), initId: 1, duration: 1)
        ..add(Uint8List(3), initId: 1, duration: 0.98);

      expect(
        playlist(w),
        '#EXTM3U\n'
        '#EXT-X-VERSION:7\n'
        '#EXT-X-TARGETDURATION:1\n'
        '#EXT-X-MEDIA-SEQUENCE:0\n'
        '#EXT-X-DISCONTINUITY-SEQUENCE:0\n'
        '#EXT-X-MAP:URI="init1.mp4"\n'
        '#EXTINF:1.000,\n'
        '0.m4s\n'
        '#EXTINF:0.980,\n'
        '1.m4s\n',
      );
      expect(w.segment(1), hasLength(3));
      expect(w.init(1), hasLength(1));
    });

    test('slides, counting the discontinuities that leave it', () {
      final w = LiveHlsWindow(capacity: 2)
        ..addInit(1, Uint8List(1))
        ..add(Uint8List(1), initId: 1, duration: 1)
        ..addInit(2, Uint8List(1))
        ..add(Uint8List(1), initId: 2, duration: 1, discontinuity: true)
        ..add(Uint8List(1), initId: 2, duration: 1)
        ..add(Uint8List(1), initId: 2, duration: 1);

      final text = playlist(w);
      expect(text, contains('#EXT-X-MEDIA-SEQUENCE:2\n'));
      expect(text, contains('#EXT-X-DISCONTINUITY-SEQUENCE:1\n'));
      expect(text, isNot(contains('#EXT-X-DISCONTINUITY\n')));
      expect(text, contains('#EXT-X-MAP:URI="init2.mp4"\n'));
      expect(w.segment(0), isNull);
      // The first init segment is no longer named, so it is dropped.
      expect(w.init(1), isNull);
    });
  });

  group('LiveRemuxer', () {
    const t0 = 296000;

    ({int video, int audio}) bases(LiveHlsWindow w, int sequence) {
      final r = Mp4Reader(w.segment(sequence)!);
      final trafs = r.all('traf', r.find(['moof'])!);
      int base(int i) => r.u64(r.all('tfdt', trafs[i]).single.$1 + 12);
      return (video: base(0), audio: base(1));
    }

    test('lays consecutive pieces end to end on the stream clock', () {
      final w = LiveHlsWindow();
      final remuxer = LiveRemuxer(w);
      for (var i = 0; i < 3; i++) {
        expect(remuxer.add(F.piece(), t0 + i * 1000), isTrue);
      }

      // Video fills each second exactly; audio runs on frame by frame.
      for (var i = 0; i < 3; i++) {
        expect(bases(w, i).video, (t0 + i * 1000) * 16);
        expect(bases(w, i).audio, t0 * 48 + i * 47 * 1024);
      }
      final text = w.playlist(initUri: (_) => 'i', segmentUri: (_) => 's');
      expect(text, isNot(contains('#EXT-X-DISCONTINUITY\n')));
      expect('#EXT-X-MAP'.allMatches(text), hasLength(1));
      expect(text, contains('#EXTINF:1.000,'));
    });

    test('puts audio back on the clock once it drifts', () {
      final w = LiveHlsWindow();
      final remuxer = LiveRemuxer(w);
      // 46 frames fall 896 ticks short of a second each time.
      for (var i = 0; i < 5; i++) {
        remuxer.add(F.piece(audioFrames: 46), t0 + i * 1000);
      }

      expect(bases(w, 3).audio, t0 * 48 + 3 * 46 * 1024);
      expect(bases(w, 4).audio, (t0 + 4000) * 48);
    });

    test('restarts timestamps after a gap, behind a discontinuity', () {
      final w = LiveHlsWindow();
      final remuxer = LiveRemuxer(w)
        ..add(F.piece(), t0)
        ..add(F.piece(), t0 + 5000);

      expect(bases(w, 1).video, (t0 + 5000) * 16);
      expect(bases(w, 1).audio, (t0 + 5000) * 48);
      final text = w.playlist(initUri: (_) => 'i', segmentUri: (_) => 's');
      expect('#EXT-X-DISCONTINUITY\n'.allMatches(text), hasLength(1));
      expect(remuxer.add(F.piece(), t0 + 6000), isTrue);
    });

    test('starts a new init segment when the codec setup changes', () {
      final w = LiveHlsWindow();
      LiveRemuxer(w)
        ..add(F.piece(), t0)
        ..add(F.piece(avcLevel: 40), t0 + 1000);

      final text = w.playlist(
        initUri: (id) => 'init$id.mp4',
        segmentUri: (s) => '$s.m4s',
      );
      expect(text, contains('#EXT-X-MAP:URI="init1.mp4"'));
      expect(text, contains('#EXT-X-MAP:URI="init2.mp4"'));
      expect('#EXT-X-DISCONTINUITY\n'.allMatches(text), hasLength(1));
    });

    test('turns down a piece it can\'t read', () {
      final w = LiveHlsWindow();
      expect(LiveRemuxer(w).add(Uint8List(40), t0), isFalse);
      expect(w.length, 0);
    });
  });
}
