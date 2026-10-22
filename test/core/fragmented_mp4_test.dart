import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/core/audio/fragmented_mp4.dart';

import '../support/fragmented_mp4_fixture.dart';

/// Reading a fragmented MP4 well enough to give it an index, so a long mix
/// in fragments can be seeked in.
void main() {
  final fixture = FragmentedMp4Fixture();
  final bytes = fixture.bytes;

  Uint8List slice(int from, int to) => Uint8List.sublistView(bytes, from, to);

  test('box headers give type and size, and refuse nonsense', () {
    expect(FragmentedMp4.boxHeader(slice(0, 16), remaining: bytes.length), (
      type: 'ftyp',
      size: 20,
    ));
    // A size bigger than what is left of the file.
    expect(FragmentedMp4.boxHeader(slice(0, 16), remaining: 10), isNull);
    expect(FragmentedMp4.boxHeader(Uint8List(4), remaining: 100), isNull);
  });

  test('the trailing mfro says how big the mfra is', () {
    expect(
      FragmentedMp4.mfraSize(slice(bytes.length - 16, bytes.length)),
      bytes.length - fixture.mfraAt,
    );
    expect(FragmentedMp4.mfraSize(slice(0, 16)), isNull);
  });

  test('the timescale comes from the track header', () {
    expect(
      FragmentedMp4.timescale(slice(20, fixture.moovEnd)),
      FragmentedMp4Fixture.timescale,
    );
  });

  test('the mfra lists every fragment with its start', () {
    final table = FragmentedMp4.tfra(slice(fixture.mfraAt, bytes.length))!;
    expect(table.trackId, 1);
    expect(
      [for (final f in table.fragments) f.offset],
      [for (final f in fixture.fragments) f.offset],
    );
    expect(table.fragments.first.time, 0);
    expect(table.fragments[1].time, fixture.fragments[0].duration);
  });

  // The mfra has no end time, so the last fragment's length comes from its
  // samples, whether the fragment gives one default or each its own.
  test('a fragment\'s length adds up its samples', () {
    for (final fragment in fixture.fragments) {
      expect(
        FragmentedMp4.fragmentDuration(
          slice(fragment.offset, fragment.offset + fragment.size),
        ),
        fragment.duration,
      );
    }
  });

  test('the index has one entry per fragment, sized and timed', () {
    final sidx = FragmentedMp4.sidx(
      trackId: 1,
      timescale: FragmentedMp4Fixture.timescale,
      earliestTime: 0,
      firstOffset: 0,
      fragments: [
        for (final f in fixture.fragments) (size: f.size, duration: f.duration),
      ],
    );
    final data = ByteData.sublistView(sidx);

    expect(data.getUint32(0), sidx.length);
    expect(String.fromCharCodes(sidx, 4, 8), 'sidx');
    expect(data.getUint8(8), 1);
    expect(data.getUint32(16), FragmentedMp4Fixture.timescale);
    expect(data.getUint16(38), fixture.fragments.length);
    for (var i = 0; i < fixture.fragments.length; i++) {
      final entry = 40 + 12 * i;
      expect(data.getUint32(entry), fixture.fragments[i].size);
      expect(data.getUint32(entry + 4), fixture.fragments[i].duration);
      // A sync sample first, which every audio fragment starts with.
      expect(data.getUint32(entry + 8), 0x90000000);
    }
  });
}
