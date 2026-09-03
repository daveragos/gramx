import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/compose/domain/voice_waveform.dart';

/// Reads the 5-bit samples back out of an encoded waveform.
///
/// The test's own decoder rather than a second copy of the encoder: a round
/// trip through code that shares the packing logic would pass with the packing
/// wrong in both directions, which is exactly the bug this is guarding.
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
    // TDLib's own spelling of "no waveform" is an empty string, not a run of
    // zeroes — and a voice note sent with zeroes draws a flat bar rather than
    // letting the client fall back.
    test('nothing encodes to nothing', () {
      expect(VoiceWaveform.encode(const []), '');
    });

    test('samples survive the five-bit packing', () {
      const samples = [0, 31, 1, 30, 17, 8, 24, 3];
      expect(decode(VoiceWaveform.encode(samples), samples.length), samples);
    });

    // The case that is easy to get silently wrong: five bits do not divide into
    // eight, so sample 1 straddles bytes 0 and 1 and every later one is offset
    // differently again.
    test('samples that straddle a byte boundary survive', () {
      final samples = List<int>.generate(100, (i) => i % 32);
      expect(decode(VoiceWaveform.encode(samples), samples.length), samples);
    });

    test('a sample above the five-bit ceiling is clamped, not wrapped', () {
      // 40 wrapped into five bits would be 8 — a loud moment drawn as a quiet
      // one, which is worse than a clipped bar.
      expect(decode(VoiceWaveform.encode(const [40]), 1), const [31]);
    });
  });

  group('downsampling', () {
    test('a short recording is left alone', () {
      const samples = [1, 2, 3];
      expect(VoiceWaveform.downsample(samples, to: 10), samples);
    });

    // The peak, not the mean. Averaged buckets flatten speech into a low ridge;
    // the peaks are what make a waveform look like somebody talking.
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
      expect(
        VoiceWaveform.fromDecibels(const [-60, 0]),
        const [0, VoiceWaveform.maxAmplitude],
      );
    });

    test('anything at or below the floor is silence', () {
      expect(VoiceWaveform.fromDecibels(const [-50, -80]), const [0, 0]);
    });

    test('halfway down the floor is halfway up the scale', () {
      expect(VoiceWaveform.fromDecibels(const [-25]).single, 16);
    });

    // Recorders report NaN before the first buffer arrives, and a NaN through
    // the arithmetic becomes a clamp failure rather than a quiet bar.
    test('a NaN reading is silence, not a crash', () {
      expect(VoiceWaveform.fromDecibels(const [double.nan]), const [0]);
    });
  });
}
