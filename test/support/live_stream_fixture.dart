import 'dart:typed_data';

/// A one-second live-stream piece shaped like the ones Telegram sends for
/// RTMP streams: its header, then a plain MP4 with a 30 fps video track and
/// an AAC-like audio track whose samples sit in interleaved chunks, the full
/// tables in a `moov` at the end, and each track's last sample duration cut
/// short.
///
/// Every sample's bytes are filled with its own marker ([videoMarker] or
/// [audioMarker]), so tests can tell where each one ended up. As in
/// Telegram's pieces, the sample descriptions carry the piece's own bitrate,
/// in a `btrt` box on each track and in the audio's `esds`.
class LiveStreamFixture {
  static const int videoTrackId = 1;
  static const int audioTrackId = 2;
  static const int videoTimescale = 16000;
  static const int audioTimescale = 48000;

  /// The B-frame delay the video's edit list skips.
  static const int videoEditMediaTime = 1056;

  static const int videoFrames = 30;

  /// Durations as a 30 fps video cut at one second gives them, 528 and 544
  /// ticks in turn, the last frame cut to one tick. All but the last add up
  /// to 15472, so the last really lasts 528.
  static final List<int> videoDurations = [
    for (var i = 0; i < videoFrames - 1; i++) i % 3 == 1 ? 544 : 528,
    1,
  ];

  static final List<int> videoCompositionOffsets = [
    for (var i = 0; i < videoFrames; i++) const [1056, 2672, 1072, 0, 528][i % 5],
  ];

  /// AAC frames of 1024 samples, the last cut short. A second holds 46.875,
  /// so pieces carry 46 or 47.
  static List<int> audioDurations(int frames) => [
    for (var i = 0; i < frames - 1; i++) 1024,
    960,
  ];

  static int videoMarker(int index) => 0x10 + index;
  static int audioMarker(int index) => 0x80 + index;
  static int videoSize(int index) => 40 + index;
  static int audioSize(int index) => 12 + index % 7;

  LiveStreamFixture._();

  /// The piece, with [header] Telegram's prefix (or none), and [avcLevel]
  /// and [bitrate] written into the sample descriptions, so pieces can
  /// differ in codec setup or only in bitrate.
  static Uint8List piece({
    bool header = true,
    int avcLevel = 31,
    int bitrate = 2344543,
    int audioFrames = 47,
  }) {
    final mp4 = movie(
      avcLevel: avcLevel,
      bitrate: bitrate,
      audioFrames: audioFrames,
    );
    if (!header) return mp4;
    final head = Uint8List(32);
    ByteData.sublistView(head).setUint32(0, 0xA12E810D, Endian.little);
    head.setAll(4, [3, 0x6d, 0x70, 0x34]); // "\x03mp4"
    head[12] = 1;
    return Uint8List.fromList([...head, ...mp4]);
  }

  /// Just the MP4.
  static Uint8List movie({
    int avcLevel = 31,
    int bitrate = 2344543,
    int audioFrames = 47,
  }) {
    final ftyp = _box('ftyp', [_ascii('isom'), _u32(512), _ascii('isom')]);

    // Chunks in file order: the first 16 video frames, the first 24 audio
    // frames, then the rest of each.
    final videoChunks = [
      [for (var i = 0; i < 16; i++) i],
      [for (var i = 16; i < videoFrames; i++) i],
    ];
    final audioChunks = [
      [for (var i = 0; i < 24; i++) i],
      [for (var i = 24; i < audioFrames; i++) i],
    ];
    final data = BytesBuilder();
    final videoChunkOffsets = <int>[];
    final audioChunkOffsets = <int>[];
    final mdatStart = ftyp.length + 8;
    for (var c = 0; c < 2; c++) {
      videoChunkOffsets.add(mdatStart + data.length);
      for (final i in videoChunks[c]) {
        data.add(List.filled(videoSize(i), videoMarker(i)));
      }
      audioChunkOffsets.add(mdatStart + data.length);
      for (final i in audioChunks[c]) {
        data.add(List.filled(audioSize(i), audioMarker(i)));
      }
    }
    final mdat = _box('mdat', [data.toBytes()]);

    final video = _trak(
      id: videoTrackId,
      timescale: videoTimescale,
      handler: 'vide',
      mediaHeader: _fullBox('vmhd', 0, 1, [Uint8List(8)]),
      sampleEntry: _box('avc1', [
        Uint8List(6),
        _u16(1),
        Uint8List(70),
        _box('avcC', [
          Uint8List.fromList([1, 0x64, 0, avcLevel, 0xff, 0xe0, 0]),
        ]),
        _btrt(bitrate),
      ]),
      durations: videoDurations,
      compositionOffsets: videoCompositionOffsets,
      syncSamples: const [1],
      sizes: [for (var i = 0; i < videoFrames; i++) videoSize(i)],
      chunkRuns: [(1, 16), (2, videoFrames - 16)],
      chunkOffsets: videoChunkOffsets,
      editMediaTime: videoEditMediaTime,
    );
    final audio = _trak(
      id: audioTrackId,
      timescale: audioTimescale,
      handler: 'soun',
      mediaHeader: _fullBox('smhd', 0, 0, [Uint8List(4)]),
      sampleEntry: _box('mp4a', [
        Uint8List(6),
        _u16(1),
        Uint8List(20),
        _esds(bitrate ~/ 18),
        _btrt(bitrate ~/ 18),
      ]),
      durations: audioDurations(audioFrames),
      sizes: [for (var i = 0; i < audioFrames; i++) audioSize(i)],
      chunkRuns: [(1, 24), (2, audioFrames - 24)],
      chunkOffsets: audioChunkOffsets,
    );
    final moov = _box('moov', [
      _fullBox('mvhd', 0, 0, [
        _u32(0),
        _u32(0),
        _u32(1000),
        _u32(1000),
        Uint8List(76),
        _u32(3),
      ]),
      video,
      audio,
    ]);
    return Uint8List.fromList([...ftyp, ...mdat, ...moov]);
  }

  static Uint8List _trak({
    required int id,
    required int timescale,
    required String handler,
    required Uint8List mediaHeader,
    required Uint8List sampleEntry,
    required List<int> durations,
    List<int>? compositionOffsets,
    List<int>? syncSamples,
    required List<int> sizes,
    required List<(int, int)> chunkRuns,
    required List<int> chunkOffsets,
    int? editMediaTime,
  }) {
    final total = durations.fold<int>(0, (a, b) => a + b);
    return _box('trak', [
      _fullBox('tkhd', 0, 3, [
        _u32(0),
        _u32(0),
        _u32(id),
        _u32(0),
        _u32(total * 1000 ~/ timescale),
        Uint8List(60),
      ]),
      if (editMediaTime != null)
        _box('edts', [
          _fullBox('elst', 0, 0, [
            _u32(1),
            _u32(total * 1000 ~/ timescale),
            _u32(editMediaTime),
            _u32(0x00010000),
          ]),
        ]),
      _box('mdia', [
        _fullBox('mdhd', 0, 0, [
          _u32(0),
          _u32(0),
          _u32(timescale),
          _u32(total),
          _u32(0),
        ]),
        _fullBox('hdlr', 0, 0, [
          _u32(0),
          _ascii(handler),
          Uint8List(12),
          Uint8List(1),
        ]),
        _box('minf', [
          mediaHeader,
          _box('dinf', [
            _fullBox('dref', 0, 0, [
              _u32(1),
              _fullBox('url ', 0, 1, []),
            ]),
          ]),
          _box('stbl', [
            _fullBox('stsd', 0, 0, [_u32(1), sampleEntry]),
            _fullBox('stts', 0, 0, [
              _u32(durations.length),
              for (final d in durations) ...[_u32(1), _u32(d)],
            ]),
            if (compositionOffsets != null)
              _fullBox('ctts', 0, 0, [
                _u32(compositionOffsets.length),
                for (final o in compositionOffsets) ...[_u32(1), _u32(o)],
              ]),
            if (syncSamples != null)
              _fullBox('stss', 0, 0, [
                _u32(syncSamples.length),
                for (final s in syncSamples) _u32(s),
              ]),
            _fullBox('stsc', 0, 0, [
              _u32(chunkRuns.length),
              for (final (first, perChunk) in chunkRuns) ...[
                _u32(first),
                _u32(perChunk),
                _u32(1),
              ],
            ]),
            _fullBox('stsz', 0, 0, [
              _u32(0),
              _u32(sizes.length),
              for (final s in sizes) _u32(s),
            ]),
            _fullBox('stco', 0, 0, [
              _u32(chunkOffsets.length),
              for (final o in chunkOffsets) _u32(o),
            ]),
          ]),
        ]),
      ]),
    ]);
  }

  /// Buffer size, max bitrate and average bitrate.
  static Uint8List _btrt(int bitrate) =>
      _box('btrt', [_u32(0), _u32(bitrate), _u32(bitrate)]);

  /// An AAC decoder config as a muxer writes it, each descriptor's size
  /// taking four bytes: an ES descriptor holding a decoder config with
  /// [bitrate] and the AudioSpecificConfig, then the sync-layer config.
  static Uint8List _esds(int bitrate) {
    List<int> descriptor(int tag, List<int> body) =>
        [tag, 0x80, 0x80, 0x80, body.length, ...body];
    final config = descriptor(4, [
      0x40, // AAC
      0x15, // audio stream
      0, 0, 0, // buffer size
      ..._u32(bitrate),
      ..._u32(bitrate),
      ...descriptor(5, [0x11, 0x90]),
    ]);
    return _fullBox('esds', 0, 0, [
      descriptor(3, [0, 2, 0, ...config, ...descriptor(6, [2])]),
    ]);
  }

  static Uint8List _box(String type, List<List<int>> parts) {
    final body = [for (final p in parts) ...p];
    return Uint8List.fromList([..._u32(8 + body.length), ..._ascii(type), ...body]);
  }

  static Uint8List _fullBox(
    String type,
    int version,
    int flags,
    List<List<int>> parts,
  ) => _box(type, [
    [version, (flags >> 16) & 0xff, (flags >> 8) & 0xff, flags & 0xff],
    ...parts,
  ]);

  static Uint8List _ascii(String s) => Uint8List.fromList(s.codeUnits);
  static Uint8List _u16(int v) =>
      Uint8List(2)..buffer.asByteData().setUint16(0, v);
  static Uint8List _u32(int v) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, v);
}

/// Reads boxes back out of the remuxer's output.
class Mp4Reader {
  final Uint8List bytes;
  late final ByteData _view = ByteData.sublistView(bytes);

  Mp4Reader(this.bytes);

  /// The top-level box types, in order.
  List<String> get topLevel => [for (final b in _boxes(0, bytes.length)) b.$1];

  /// The first box at [path], as (start, end) of the whole box.
  (int, int)? find(List<String> path, {int start = 0, int? end}) {
    final children = _boxes(start, end ?? bytes.length);
    for (final (type, s, e) in children) {
      if (type != path.first) continue;
      if (path.length == 1) return (s, e);
      return find(path.sublist(1), start: s + 8, end: e);
    }
    return null;
  }

  /// Every box called [type] directly under [parent].
  List<(int, int)> all(String type, (int, int) parent) => [
    for (final (t, s, e) in _boxes(parent.$1 + 8, parent.$2))
      if (t == type) (s, e),
  ];

  int u32(int offset) => _view.getUint32(offset);
  int i32(int offset) => _view.getInt32(offset);
  int u64(int offset) => _view.getUint64(offset);

  List<(String, int, int)> _boxes(int start, int end) {
    final out = <(String, int, int)>[];
    var o = start;
    while (o + 8 <= end) {
      final size = _view.getUint32(o);
      if (size < 8 || o + size > end) break;
      out.add((String.fromCharCodes(bytes, o + 4, o + 8), o, o + size));
      o += size;
    }
    return out;
  }
}
