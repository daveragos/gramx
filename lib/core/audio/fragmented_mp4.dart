import 'dart:typed_data';

/// Enough of a fragmented MP4 to give it the index players seek with.
///
/// Some audio, long mixes ripped from the web among them, comes as hundreds
/// of `moof`/`mdat` fragments behind a `moov` that gives no length, with the
/// only index (`mfra`) at the very end. ExoPlayer ignores `mfra`, so it can
/// neither tell how long the track is nor seek in it. A segment index
/// (`sidx`) just after the `moov`, built from the `mfra`, fixes both; it is
/// where streamed MP4 audio usually carries its index anyway.
///
/// Offsets below are from a box's first byte: size (4), type (4), and for a
/// full box version (1) and flags (3), so its fields start at 12.
class FragmentedMp4 {
  FragmentedMp4._();

  /// The type and size of the box starting [bytes], or null when there isn't
  /// a sane one. [remaining] is how much of the file is left from there,
  /// which a size of 0 ("to the end") stands for.
  static ({String type, int size})? boxHeader(
    Uint8List bytes, {
    required int remaining,
  }) {
    if (bytes.length < 8) return null;
    var size = _u32(bytes, 0);
    final type = String.fromCharCodes(bytes, 4, 8);
    if (size == 1) {
      if (bytes.length < 16) return null;
      size = _u64(bytes, 8);
    } else if (size == 0) {
      size = remaining;
    }
    if (size < 8 || size > remaining) return null;
    return (type: type, size: size);
  }

  /// The size of the `mfra` a file ends with, from its last 16 bytes (the
  /// `mfro` box), or null when it doesn't end with one.
  static int? mfraSize(Uint8List tail) {
    if (tail.length < 16) return null;
    final at = tail.length - 16;
    if (_u32(tail, at) != 16) return null;
    if (String.fromCharCodes(tail, at + 4, at + 8) != 'mfro') return null;
    return _u32(tail, at + 12);
  }

  /// The media timescale of the first track in [moov], from its `mdhd`.
  static int? timescale(Uint8List moov) {
    final at = _find(moov, 'mdhd');
    if (at == null || at + 12 > moov.length) return null;
    // After creation and modification times, 4 bytes each, or 8 in v1.
    final field = at + 12 + (moov[at + 8] == 1 ? 16 : 8);
    if (field + 4 > moov.length) return null;
    return _u32(moov, field);
  }

  /// The track and its fragments' start times and `moof` offsets, from the
  /// first `tfra` in [mfra].
  static ({int trackId, List<({int time, int offset})> fragments})? tfra(
    Uint8List mfra,
  ) {
    final at = _find(mfra, 'tfra');
    if (at == null || at + 24 > mfra.length) return null;
    final version = mfra[at + 8];
    final trackId = _u32(mfra, at + 12);
    // The byte widths, less one, of each entry's traf, trun and sample
    // numbers, which come after its time and offset.
    final widths = _u32(mfra, at + 16);
    final count = _u32(mfra, at + 20);
    final numbers =
        ((widths >> 4) & 3) + ((widths >> 2) & 3) + (widths & 3) + 3;
    final field = version == 1 ? 8 : 4;
    final entrySize = field * 2 + numbers;
    var p = at + 24;
    if (count == 0 || p + count * entrySize > mfra.length) return null;

    final fragments = <({int time, int offset})>[];
    for (var i = 0; i < count; i++) {
      final time = version == 1 ? _u64(mfra, p) : _u32(mfra, p);
      final offset = version == 1
          ? _u64(mfra, p + field)
          : _u32(mfra, p + field);
      fragments.add((time: time, offset: offset));
      p += entrySize;
    }
    return (trackId: trackId, fragments: fragments);
  }

  /// How long the fragment whose `moof` is [moof] plays, in the track's
  /// timescale: its samples' durations, given one by one in `trun` or once
  /// as `tfhd`'s default.
  static int? fragmentDuration(Uint8List moof) {
    final tfhd = _find(moof, 'tfhd');
    if (tfhd == null || tfhd + 16 > moof.length) return null;
    final tfhdFlags = _u32(moof, tfhd + 8) & 0xFFFFFF;
    // Past the track id: base data offset (8), description index (4), then
    // the default duration.
    var p = tfhd + 16;
    if (tfhdFlags & 0x01 != 0) p += 8;
    if (tfhdFlags & 0x02 != 0) p += 4;
    final defaultDuration = tfhdFlags & 0x08 != 0 && p + 4 <= moof.length
        ? _u32(moof, p)
        : null;

    var total = 0;
    var from = 0;
    while (true) {
      final trun = _find(moof, 'trun', from: from);
      if (trun == null) break;
      if (trun + 16 > moof.length) return null;
      final flags = _u32(moof, trun + 8) & 0xFFFFFF;
      final count = _u32(moof, trun + 12);
      // Past the count: data offset (4) and first sample flags (4).
      var q = trun + 16;
      if (flags & 0x01 != 0) q += 4;
      if (flags & 0x04 != 0) q += 4;
      if (flags & 0x100 != 0) {
        final stride =
            4 +
            (flags & 0x200 != 0 ? 4 : 0) +
            (flags & 0x400 != 0 ? 4 : 0) +
            (flags & 0x800 != 0 ? 4 : 0);
        if (q + count * stride > moof.length) return null;
        for (var i = 0; i < count; i++) {
          total += _u32(moof, q + i * stride);
        }
      } else if (defaultDuration != null) {
        total += count * defaultDuration;
      } else {
        return null;
      }
      from = trun + 8;
    }
    return total == 0 ? null : total;
  }

  /// A `sidx` box indexing [fragments] (byte size and duration each), the
  /// first of which starts [firstOffset] bytes after the box.
  static Uint8List sidx({
    required int trackId,
    required int timescale,
    required int earliestTime,
    required int firstOffset,
    required List<({int size, int duration})> fragments,
  }) {
    const header = 40;
    final length = header + 12 * fragments.length;
    final box = ByteData(length)
      ..setUint32(0, length)
      ..setUint32(4, 0x73696478) // 'sidx'
      ..setUint32(8, 0x01000000) // version 1, no flags
      ..setUint32(12, trackId)
      ..setUint32(16, timescale)
      ..setUint64(20, earliestTime)
      ..setUint64(28, firstOffset)
      ..setUint16(36, 0) // reserved
      ..setUint16(38, fragments.length);
    var p = header;
    for (final fragment in fragments) {
      box
        ..setUint32(p, fragment.size & 0x7FFFFFFF) // a media reference
        ..setUint32(p + 4, fragment.duration)
        ..setUint32(p + 8, 0x90000000); // starts with a sync sample
      p += 12;
    }
    return box.buffer.asUint8List();
  }

  /// Where the box of [type] starts in [bytes] (its size field), for the
  /// first one whose type is at or after [from] + 4.
  static int? _find(Uint8List bytes, String type, {int from = 0}) {
    final codes = type.codeUnits;
    for (var i = from + 4; i + 4 <= bytes.length; i++) {
      if (bytes[i] == codes[0] &&
          bytes[i + 1] == codes[1] &&
          bytes[i + 2] == codes[2] &&
          bytes[i + 3] == codes[3]) {
        return i - 4;
      }
    }
    return null;
  }

  static int _u32(Uint8List b, int at) =>
      (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];

  static int _u64(Uint8List b, int at) => (_u32(b, at) << 32) | _u32(b, at + 4);
}
