import 'dart:typed_data';

/// One sample of a track, where it sits in the source file.
class Mp4Sample {
  final int offset;
  final int size;
  final int duration;

  /// The composition offset from `ctts`, before the edit list's shift.
  final int compositionOffset;
  final bool isSync;

  const Mp4Sample({
    required this.offset,
    required this.size,
    required this.duration,
    required this.compositionOffset,
    required this.isSync,
  });
}

/// A track of a plain (non-fragmented) MP4, with the boxes an init segment
/// copies and the samples a fragment carries.
class Mp4Track {
  final int id;
  final int timescale;

  /// The handler type: "vide" or "soun".
  final String handler;

  /// Whole boxes, header included.
  final Uint8List tkhd;
  final Uint8List mdhd;
  final Uint8List hdlr;

  /// `vmhd`, `smhd` or `nmhd`.
  final Uint8List mediaHeader;
  final Uint8List dinf;
  final Uint8List stsd;

  /// Where presentation starts in the media timeline, from the edit list.
  /// It is the reordering delay for video with B-frames.
  final int editMediaTime;

  final List<Mp4Sample> samples;

  const Mp4Track({
    required this.id,
    required this.timescale,
    required this.handler,
    required this.tkhd,
    required this.mdhd,
    required this.hdlr,
    required this.mediaHeader,
    required this.dinf,
    required this.stsd,
    required this.editMediaTime,
    required this.samples,
  });

  bool get isVideo => handler == 'vide';

  /// The sum of the sample durations, in [timescale] units.
  int get duration => samples.fold<int>(0, (sum, s) => sum + s.duration);
}

/// A plain MP4 whose `moov` holds the full sample tables, as each piece of
/// an RTMP live stream does, rewritten as fragmented MP4 for HLS.
///
/// Box offsets below are from a box's first byte: size (4), type (4), and
/// for a full box version (1) and flags (3), so its fields start at 12.
class Mp4Movie {
  final Uint8List bytes;
  final Uint8List mvhd;
  final List<Mp4Track> tracks;

  const Mp4Movie._(this.bytes, this.mvhd, this.tracks);

  /// Parses [bytes]. Throws a [FormatException] when they aren't an MP4
  /// with a `moov` and at least one audio or video track.
  factory Mp4Movie.parse(Uint8List bytes) {
    final moov = _child(bytes, 0, bytes.length, 'moov');
    if (moov == null) throw const FormatException('No moov box');
    final mvhd = _child(bytes, moov.body, moov.end, 'mvhd');
    if (mvhd == null) throw const FormatException('No mvhd box');

    final tracks = <Mp4Track>[];
    for (final trak in _children(bytes, moov.body, moov.end)) {
      if (trak.type != 'trak') continue;
      final track = _parseTrack(bytes, trak);
      if (track != null) tracks.add(track);
    }
    if (tracks.isEmpty) throw const FormatException('No audio or video track');
    return Mp4Movie._(bytes, _slice(bytes, mvhd), tracks);
  }

  /// What an init segment is built from. Pieces that share it can share an
  /// init segment.
  bool sameLayoutAs(Mp4Movie other) {
    if (tracks.length != other.tracks.length) return false;
    for (var i = 0; i < tracks.length; i++) {
      final a = tracks[i];
      final b = other.tracks[i];
      if (a.id != b.id ||
          a.timescale != b.timescale ||
          a.handler != b.handler ||
          !_sameBytes(a.stsd, b.stsd)) {
        return false;
      }
    }
    return true;
  }

  /// The `ftyp` and `moov` that tell a player the tracks and codecs, with
  /// empty sample tables and an `mvex` announcing fragments.
  Uint8List initSegment() {
    final out = BytesBuilder(copy: false);
    out.add(
      _box('ftyp', [
        _ascii('iso6'),
        _u32(0),
        _ascii('iso6'),
        _ascii('iso5'),
        _ascii('isom'),
        _ascii('mp41'),
      ]),
    );

    final traks = [
      for (final t in tracks)
        _box('trak', [
          _withZeroDuration(t.tkhd, _tkhdDurationOffset(t.tkhd)),
          _box('mdia', [
            _withZeroDuration(t.mdhd, _headerDurationOffset(t.mdhd)),
            t.hdlr,
            _box('minf', [
              t.mediaHeader,
              t.dinf,
              _box('stbl', [
                t.stsd,
                _fullBox('stts', 0, 0, [_u32(0)]),
                _fullBox('stsc', 0, 0, [_u32(0)]),
                _fullBox('stsz', 0, 0, [_u32(0), _u32(0)]),
                _fullBox('stco', 0, 0, [_u32(0)]),
              ]),
            ]),
          ]),
        ]),
    ];
    final trexes = [
      for (final t in tracks)
        _fullBox('trex', 0, 0, [_u32(t.id), _u32(1), _u32(0), _u32(0), _u32(0)]),
    ];
    out.add(
      _box('moov', [
        _withZeroDuration(mvhd, _headerDurationOffset(mvhd)),
        ...traks,
        _box('mvex', trexes),
      ]),
    );
    return out.takeBytes();
  }

  /// A `moof` and `mdat` carrying every sample, numbered [sequence], each
  /// track starting at its entry in [baseDecodeTimes] (track id to time in
  /// that track's timescale). [lastSampleDurations] replaces a track's last
  /// sample duration, which a cut piece of a stream gets wrong.
  ///
  /// Composition offsets are shifted by the edit list and written signed
  /// (`trun` version 1), so presentation starts at the base time without
  /// an edit list in the init segment.
  Uint8List fragment({
    required int sequence,
    required Map<int, int> baseDecodeTimes,
    Map<int, int> lastSampleDurations = const {},
  }) {
    const dataOffsetPresent = 0x000001;
    const durationPresent = 0x000100;
    const sizePresent = 0x000200;
    const flagsPresent = 0x000400;
    const compositionPresent = 0x000800;
    const defaultBaseIsMoof = 0x020000;
    const syncFlags = 0x02000000;
    const nonSyncFlags = 0x01010000;

    // Each traf's trun carries a data offset that depends on the moof's own
    // size, so the moof is built twice: once to measure, once for real.
    final trackDataSizes = [
      for (final t in tracks) t.samples.fold<int>(0, (sum, s) => sum + s.size),
    ];

    Uint8List buildMoof(int moofSize) {
      var dataStart = moofSize + 8;
      final trafs = <Uint8List>[];
      for (var i = 0; i < tracks.length; i++) {
        final t = tracks[i];
        final shifts = t.samples.any(
          (s) => s.compositionOffset - t.editMediaTime != 0,
        );
        final flags =
            dataOffsetPresent |
            durationPresent |
            sizePresent |
            flagsPresent |
            (shifts ? compositionPresent : 0);
        final entries = BytesBuilder(copy: false);
        final lastDuration = lastSampleDurations[t.id];
        for (final s in t.samples) {
          final isLast = identical(s, t.samples.last);
          entries.add(_u32(isLast && lastDuration != null ? lastDuration : s.duration));
          entries.add(_u32(s.size));
          entries.add(_u32(s.isSync ? syncFlags : nonSyncFlags));
          if (shifts) entries.add(_i32(s.compositionOffset - t.editMediaTime));
        }
        trafs.add(
          _box('traf', [
            _fullBox('tfhd', 0, defaultBaseIsMoof, [_u32(t.id)]),
            _fullBox('tfdt', 1, 0, [_u64(baseDecodeTimes[t.id] ?? 0)]),
            _fullBox('trun', 1, flags, [
              _u32(t.samples.length),
              _i32(dataStart),
              entries.takeBytes(),
            ]),
          ]),
        );
        dataStart += trackDataSizes[i];
      }
      return _box('moof', [
        _fullBox('mfhd', 0, 0, [_u32(sequence)]),
        ...trafs,
      ]);
    }

    final measured = buildMoof(0).length;
    final moof = buildMoof(measured);

    final dataSize = trackDataSizes.fold<int>(0, (sum, n) => sum + n);
    final out = BytesBuilder(copy: false)
      ..add(moof)
      ..add(_u32(8 + dataSize))
      ..add(_ascii('mdat'));
    for (final t in tracks) {
      for (final s in t.samples) {
        out.add(Uint8List.sublistView(bytes, s.offset, s.offset + s.size));
      }
    }
    return out.takeBytes();
  }

  static Mp4Track? _parseTrack(Uint8List bytes, _Box trak) {
    final tkhd = _child(bytes, trak.body, trak.end, 'tkhd');
    final mdia = _child(bytes, trak.body, trak.end, 'mdia');
    if (tkhd == null || mdia == null) return null;
    final mdhd = _child(bytes, mdia.body, mdia.end, 'mdhd');
    final hdlr = _child(bytes, mdia.body, mdia.end, 'hdlr');
    final minf = _child(bytes, mdia.body, mdia.end, 'minf');
    if (mdhd == null || hdlr == null || minf == null) return null;

    final handler = String.fromCharCodes(bytes, hdlr.start + 16, hdlr.start + 20);
    if (handler != 'vide' && handler != 'soun') return null;

    final mediaHeader = [
      for (final b in _children(bytes, minf.body, minf.end))
        if (b.type == 'vmhd' || b.type == 'smhd' || b.type == 'nmhd') b,
    ].firstOrNull;
    final dinf = _child(bytes, minf.body, minf.end, 'dinf');
    final stbl = _child(bytes, minf.body, minf.end, 'stbl');
    if (mediaHeader == null || dinf == null || stbl == null) return null;
    final stsd = _child(bytes, stbl.body, stbl.end, 'stsd');
    if (stsd == null) return null;

    final view = ByteData.sublistView(bytes);
    final tkhdVersion = bytes[tkhd.start + 8];
    final trackId = view.getUint32(tkhd.start + (tkhdVersion == 1 ? 28 : 20));
    final mdhdVersion = bytes[mdhd.start + 8];
    final timescale = view.getUint32(mdhd.start + (mdhdVersion == 1 ? 28 : 20));

    return Mp4Track(
      id: trackId,
      timescale: timescale,
      handler: handler,
      tkhd: _slice(bytes, tkhd),
      mdhd: _slice(bytes, mdhd),
      hdlr: _slice(bytes, hdlr),
      mediaHeader: _slice(bytes, mediaHeader),
      dinf: _slice(bytes, dinf),
      stsd: _slice(bytes, stsd),
      editMediaTime: _editMediaTime(bytes, view, trak),
      samples: _samples(bytes, view, stbl),
    );
  }

  /// The first non-empty edit's media time, or 0 without an edit list.
  static int _editMediaTime(Uint8List bytes, ByteData view, _Box trak) {
    final edts = _child(bytes, trak.body, trak.end, 'edts');
    if (edts == null) return 0;
    final elst = _child(bytes, edts.body, edts.end, 'elst');
    if (elst == null) return 0;
    final version = bytes[elst.start + 8];
    final count = view.getUint32(elst.start + 12);
    final entrySize = version == 1 ? 20 : 12;
    for (var i = 0; i < count; i++) {
      final entry = elst.start + 16 + i * entrySize;
      if (entry + entrySize > elst.end) break;
      final mediaTime = version == 1
          ? view.getInt64(entry + 8)
          : view.getInt32(entry + 4);
      // -1 marks an empty edit, a delay before the media starts.
      if (mediaTime >= 0) return mediaTime;
    }
    return 0;
  }

  static List<Mp4Sample> _samples(Uint8List bytes, ByteData view, _Box stbl) {
    final stsz = _child(bytes, stbl.body, stbl.end, 'stsz');
    final stsc = _child(bytes, stbl.body, stbl.end, 'stsc');
    final stts = _child(bytes, stbl.body, stbl.end, 'stts');
    final stco =
        _child(bytes, stbl.body, stbl.end, 'stco') ??
        _child(bytes, stbl.body, stbl.end, 'co64');
    if (stsz == null || stsc == null || stts == null || stco == null) {
      throw const FormatException('Incomplete sample table');
    }
    final ctts = _child(bytes, stbl.body, stbl.end, 'ctts');
    final stss = _child(bytes, stbl.body, stbl.end, 'stss');

    // Sizes.
    final fixedSize = view.getUint32(stsz.start + 12);
    final count = view.getUint32(stsz.start + 16);
    _require(fixedSize != 0 || stsz.start + 20 + count * 4 <= stsz.end);
    int sizeOf(int i) =>
        fixedSize != 0 ? fixedSize : view.getUint32(stsz.start + 20 + i * 4);

    // Chunk offsets.
    final is64 = stco.type == 'co64';
    final chunkCount = view.getUint32(stco.start + 12);
    _require(stco.start + 16 + chunkCount * (is64 ? 8 : 4) <= stco.end);
    int chunkOffset(int i) => is64
        ? view.getUint64(stco.start + 16 + i * 8)
        : view.getUint32(stco.start + 16 + i * 4);

    // Samples per chunk, as runs starting at a 1-based chunk number.
    final runCount = view.getUint32(stsc.start + 12);
    _require(stsc.start + 16 + runCount * 12 <= stsc.end);
    final offsets = List<int>.filled(count, 0);
    var sample = 0;
    for (var run = 0; run < runCount && sample < count; run++) {
      final entry = stsc.start + 16 + run * 12;
      final firstChunk = view.getUint32(entry) - 1;
      final perChunk = view.getUint32(entry + 4);
      final lastChunk = run + 1 < runCount
          ? view.getUint32(entry + 12) - 1
          : chunkCount;
      for (var chunk = firstChunk; chunk < lastChunk && sample < count; chunk++) {
        var offset = chunkOffset(chunk);
        for (var k = 0; k < perChunk && sample < count; k++) {
          offsets[sample] = offset;
          offset += sizeOf(sample);
          sample++;
        }
      }
    }
    _require(sample == count);

    // Durations, as runs.
    final durations = _expandRuns(bytes, view, stts, count, signed: false);
    _require(durations != null);

    // Composition offsets: signed in version 1, unsigned in version 0.
    final compositions = ctts == null
        ? List<int>.filled(count, 0)
        : _expandRuns(
                bytes,
                view,
                ctts,
                count,
                signed: bytes[ctts.start + 8] == 1,
              ) ??
              List<int>.filled(count, 0);

    // Sync samples, 1-based. Without `stss` every sample is one.
    Set<int>? sync;
    if (stss != null) {
      final n = view.getUint32(stss.start + 12);
      _require(stss.start + 16 + n * 4 <= stss.end);
      sync = {for (var i = 0; i < n; i++) view.getUint32(stss.start + 16 + i * 4) - 1};
    }

    return [
      for (var i = 0; i < count; i++)
        Mp4Sample(
          offset: offsets[i],
          size: sizeOf(i),
          duration: durations![i],
          compositionOffset: compositions[i],
          isSync: sync == null || sync.contains(i),
        ),
    ].where((s) => s.offset + s.size <= bytes.length).toList();
  }

  /// Expands a run-length table of (count, value) pairs to [count] values,
  /// padding with the last value if it comes up short.
  static List<int>? _expandRuns(
    Uint8List bytes,
    ByteData view,
    _Box box,
    int count, {
    required bool signed,
  }) {
    final runs = view.getUint32(box.start + 12);
    if (box.start + 16 + runs * 8 > box.end) return null;
    final values = <int>[];
    for (var i = 0; i < runs && values.length < count; i++) {
      final entry = box.start + 16 + i * 8;
      final n = view.getUint32(entry);
      final value = signed ? view.getInt32(entry + 4) : view.getUint32(entry + 4);
      for (var k = 0; k < n && values.length < count; k++) {
        values.add(value);
      }
    }
    if (values.isEmpty) return null;
    while (values.length < count) {
      values.add(values.last);
    }
    return values;
  }
}

/// A box's type and extent: [start] is its first byte, [body] the first
/// byte after its header, [end] one past its last byte.
class _Box {
  final String type;
  final int start;
  final int body;
  final int end;

  const _Box(this.type, this.start, this.body, this.end);
}

Iterable<_Box> _children(Uint8List bytes, int start, int end) sync* {
  final view = ByteData.sublistView(bytes);
  var offset = start;
  while (offset + 8 <= end) {
    var size = view.getUint32(offset);
    var header = 8;
    if (size == 1) {
      if (offset + 16 > end) return;
      size = view.getUint64(offset + 8);
      header = 16;
    } else if (size == 0) {
      size = end - offset;
    }
    if (size < header || offset + size > end) return;
    yield _Box(
      String.fromCharCodes(bytes, offset + 4, offset + 8),
      offset,
      offset + header,
      offset + size,
    );
    offset += size;
  }
}

_Box? _child(Uint8List bytes, int start, int end, String type) {
  for (final box in _children(bytes, start, end)) {
    if (box.type == type) return box;
  }
  return null;
}

Uint8List _slice(Uint8List bytes, _Box box) =>
    Uint8List.fromList(Uint8List.sublistView(bytes, box.start, box.end));

void _require(bool ok) {
  if (!ok) throw const FormatException('Malformed sample table');
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Where the duration sits in `mvhd` and `mdhd`, which share a layout up to
/// it: 4-byte times in version 0, 8-byte ones in version 1.
int _headerDurationOffset(Uint8List box) => box[8] == 1 ? 32 : 24;

/// Where the duration sits in `tkhd`, after the times, track id and a
/// reserved field.
int _tkhdDurationOffset(Uint8List box) => box[8] == 1 ? 36 : 28;

/// A copy of [box] with the duration at [offset] zeroed, 8 bytes wide in
/// version 1, 4 in version 0. Fragmented files leave durations to the
/// fragments.
Uint8List _withZeroDuration(Uint8List box, int offset) {
  final copy = Uint8List.fromList(box);
  final width = box[8] == 1 ? 8 : 4;
  if (offset + width <= copy.length) copy.fillRange(offset, offset + width, 0);
  return copy;
}

Uint8List _box(String type, List<Uint8List> children) {
  final size = 8 + children.fold<int>(0, (sum, c) => sum + c.length);
  final out = BytesBuilder(copy: false)
    ..add(_u32(size))
    ..add(_ascii(type));
  for (final c in children) {
    out.add(c);
  }
  return out.takeBytes();
}

Uint8List _fullBox(String type, int version, int flags, List<Uint8List> fields) {
  final header = Uint8List(4)
    ..[0] = version
    ..[1] = (flags >> 16) & 0xff
    ..[2] = (flags >> 8) & 0xff
    ..[3] = flags & 0xff;
  return _box(type, [header, ...fields]);
}

Uint8List _ascii(String s) => Uint8List.fromList(s.codeUnits);

Uint8List _u32(int v) => Uint8List(4)..buffer.asByteData().setUint32(0, v);

Uint8List _i32(int v) => Uint8List(4)..buffer.asByteData().setInt32(0, v);

Uint8List _u64(int v) => Uint8List(8)..buffer.asByteData().setUint64(0, v);
