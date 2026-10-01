import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/compose/domain/voice_waveform.dart';

/// Reads the 5-bit samples back out of an encoded waveform. Written apart from
/// the encoder so a packing bug cannot cancel itself out.
List<int> decode(String encoded, int count) {
  final bytes = base64Decode(encoded);
  return [
    for (var i = 0; i < count; i++)
      () {
        final bitOffset = i * 5;
        var value = 0;
        for (var bit = 0; bit < 5; bit++) {
          final absolute = bitOffset + bit;
          final byte = absolute ~/ 8;
          if (byte >= bytes.length) break;
          final isSet = (bytes[byte] >> (absolute % 8)) & 1;
          value |= isSet << bit;
        }
        return value;
      }(),
  ];
}

void main() {
  group('encoding', () {
    // TDLib expects an empty string for no waveform; zeroes draw a flat bar.
    test('nothing encodes to nothing', () {
      expect(VoiceWaveform.encode(const []), '');
    });

    test('samples survive the five-bit packing', () {
      const samples = [0, 31, 1, 30, 17, 8, 24, 3];
      expect(decode(VoiceWaveform.encode(samples), samples.length), samples);
    });

    // Five bits do not divide eight, so samples straddle byte boundaries.
    test('samples that straddle a byte boundary survive', () {
      final samples = List<int>.generate(100, (i) => i % 32);
      expect(decode(VoiceWaveform.encode(samples), samples.length), samples);
    });

    test('a sample above the five-bit ceiling is clamped, not wrapped', () {
      // Wrapped, 40 would become 8 and a loud moment would look quiet.
      expect(decode(VoiceWaveform.encode(const [40]), 1), const [31]);
    });
  });

  group('downsampling', () {
    test('a short recording is left alone', () {
      const samples = [1, 2, 3];
      expect(VoiceWaveform.downsample(samples, to: 10), samples);
    });

    // Peaks, not means: averaging flattens speech into a low ridge.
    test('each bucket keeps its loudest sample', () {
      expect(
        VoiceWaveform.downsample(const [0, 31, 0, 0, 0, 20], to: 2),
        const [31, 20],
      );
    });

    test('a long recording comes back at the target length', () {
      final samples = List<int>.generate(6000, (i) => i % 32);
      expect(VoiceWaveform.downsample(samples).length, 100);
    });
  });

  group('decibels', () {
    test('silence is zero and full scale is the ceiling', () {
      expect(VoiceWaveform.fromDecibels(const [-60, 0]), const [
        0,
        VoiceWaveform.maxAmplitude,
      ]);
    });

    test('anything at or below the floor is silence', () {
      expect(VoiceWaveform.fromDecibels(const [-50, -80]), const [0, 0]);
    });

    test('halfway down the floor is halfway up the scale', () {
      expect(VoiceWaveform.fromDecibels(const [-25]).single, 16);
    });

    // Recorders report NaN before the first buffer arrives.
    test('a NaN reading is silence, not a crash', () {
      expect(VoiceWaveform.fromDecibels(const [double.nan]), const [0]);
    });
  });
}
