import 'dart:typed_data';

/// A small fragmented MP4 laid out like the long mixes ExoPlayer can't seek
/// in: ftyp, a moov with no length, fragments, and an mfra at the end.
class FragmentedMp4Fixture {
  /// Samples per second, as the track's mdhd says.
  static const int timescale = 44100;

  /// Each sample's length, when a fragment gives one for all.
  static const int defaultDuration = 1024;

  /// The file.
  final Uint8List bytes;

  /// Where the fragments start, just past the moov.
  final int moovEnd;

  /// Each fragment's offset, size (moof and mdat) and duration.
  final List<({int offset, int size, int duration})> fragments;

  /// Where the mfra starts.
  final int mfraAt;

  FragmentedMp4Fixture._(this.bytes, this.moovEnd, this.fragments, this.mfraAt);

  /// [sampleCounts] fragments of that many samples. The last fragment lists
  /// each sample's duration, as some muxers write it, instead of relying on
  /// the default.
  factory FragmentedMp4Fixture({
    List<int> sampleCounts = const [259, 259, 70],
  }) {
    final out = BytesBuilder();
    out.add(_box('ftyp', [..._ascii('M4A '), ..._u32(0), ..._ascii('isom')]));

    final mdhd = _fullBox('mdhd', 0, [
      ..._u32(0), // created
      ..._u32(0), // modified
      ..._u32(timescale),
      ..._u32(0), // no duration: it's in the fragments
      ..._u32(0x55c40000),
    ]);
    final trak = _box('trak', [
      ..._fullBox('tkhd', 0, List.filled(80, 0)),
      ..._box('mdia', mdhd),
    ]);
    final mvex = _box(
      'mvex',
      _fullBox('trex', 0, [..._u32(1), ...List.filled(16, 0)]),
    );
    out.add(
      _box('moov', [
        ..._fullBox('mvhd', 0, List.filled(96, 0)),
        ...trak,
        ...mvex,
      ]),
    );
    final moovEnd = out.length;

    final fragments = <({int offset, int size, int duration})>[];
    final times = <int>[];
    var time = 0;
    for (var f = 0; f < sampleCounts.length; f++) {
      final count = sampleCounts[f];
      final perSample = f == sampleCounts.length - 1;
      final durations = [
        for (var i = 0; i < count; i++)
          defaultDuration + (perSample ? i % 3 : 0),
      ];
      final offset = out.length;
      final tfhd = _fullBox('tfhd', 0x020038, [
        ..._u32(1), // track
        ..._u32(defaultDuration),
        ..._u32(4), // default size
        ..._u32(0x02000000),
      ]);
      final tfdt = _fullBox('tfdt', 0x01000000, [..._u64(time)]);
      final trun = _fullBox('trun', perSample ? 0x000301 : 0x000201, [
        ..._u32(count),
        ..._u32(0), // data offset, unused here
        for (var i = 0; i < count; i++) ...[
          if (perSample) ..._u32(durations[i]),
          ..._u32(4),
        ],
      ]);
      out.add(
        _box('moof', [
          ..._fullBox('mfhd', 0, _u32(f + 1)),
          ..._box('traf', [...tfhd, ...tfdt, ...trun]),
        ]),
      );
      out.add(_box('mdat', List.filled(count * 4, f + 1)));
      final duration = durations.fold(0, (a, b) => a + b);
      fragments.add((
        offset: offset,
        size: out.length - offset,
        duration: duration,
      ));
      times.add(time);
      time += duration;
    }

    final mfraAt = out.length;
    final tfra = _fullBox('tfra', 0x01000000, [
      ..._u32(1), // track
      ..._u32(0x3f), // 4-byte traf, trun and sample numbers
      ..._u32(fragments.length),
      for (var i = 0; i < fragments.length; i++) ...[
        ..._u64(times[i]),
        ..._u64(fragments[i].offset),
        ..._u32(1),
        ..._u32(1),
        ..._u32(1),
      ],
    ]);
    final mfraSize = 8 + tfra.length + 16;
    out.add(_box('mfra', [...tfra, ..._fullBox('mfro', 0, _u32(mfraSize))]));

    return FragmentedMp4Fixture._(out.takeBytes(), moovEnd, fragments, mfraAt);
  }

  static List<int> _box(String type, List<int> body) => [
    ..._u32(8 + body.length),
    ..._ascii(type),
    ...body,
  ];

  /// A full box: [versionAndFlags] packs the version in the top byte.
  static List<int> _fullBox(String type, int versionAndFlags, List<int> body) =>
      _box(type, [..._u32(versionAndFlags), ...body]);

  static List<int> _ascii(String s) => s.codeUnits;

  static List<int> _u32(int v) => [
    (v >> 24) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 8) & 0xFF,
    v & 0xFF,
  ];

  static List<int> _u64(int v) => [..._u32(v >> 32), ..._u32(v & 0xFFFFFFFF)];
}
