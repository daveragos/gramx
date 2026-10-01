import 'dart:convert';
import 'dart:typed_data';

/// The bars drawn under a voice message. Telegram doesn't derive these, so a
/// voice note sent without one shows a flat bar. TDLib packs amplitudes at
/// five bits each (0 to 31), low bits first, across byte boundaries, then
/// base64.
abstract class VoiceWaveform {
  /// How many bars Telegram draws. Longer recordings are downsampled to this.
  static const int sampleCount = 100;

  /// The largest value five bits can hold.
  static const int maxAmplitude = 31;

  /// Squeezes a run of amplitudes down to at most [sampleCount], keeping the
  /// peak of each bucket. Averages flatten speech into a low ridge.
  static List<int> downsample(List<int> samples, {int to = sampleCount}) {
    if (samples.isEmpty || samples.length <= to) return samples;

    final out = <int>[];
    for (var i = 0; i < to; i++) {
      final start = (i * samples.length) ~/ to;
      final end = ((i + 1) * samples.length) ~/ to;
      var peak = 0;
      for (var j = start; j < end; j++) {
        if (samples[j] > peak) peak = samples[j];
      }
      out.add(peak);
    }
    return out;
  }

  /// Turns decibel readings (0 at full scale, negative below) into Telegram's
  /// 0 to 31 range. Anything under [floor] counts as silence, so a quiet room
  /// doesn't draw as half-height bars.
  static List<int> fromDecibels(List<double> dbfs, {double floor = -50}) {
    return [
      for (final db in dbfs)
        if (db.isNaN || db <= floor)
          0
        else if (db >= 0)
          maxAmplitude
        else
          ((1 - db / floor) * maxAmplitude).round().clamp(0, maxAmplitude),
    ];
  }

  /// Packs amplitudes five bits each and base64-encodes them, as TDLib wants.
  /// An empty list gives an empty string, which TDLib reads as "no waveform".
  static String encode(List<int> samples) {
    if (samples.isEmpty) return '';

    final bytes = Uint8List(((samples.length * 5) + 7) ~/ 8);
    for (var i = 0; i < samples.length; i++) {
      final value = samples[i].clamp(0, maxAmplitude);
      final bitOffset = i * 5;
      final byte = bitOffset ~/ 8;
      final shift = bitOffset % 8;

      bytes[byte] |= (value << shift) & 0xFF;
      // A sample that starts near the end of a byte spills into the next one.
      if (shift > 3 && byte + 1 < bytes.length) {
        bytes[byte + 1] |= value >> (8 - shift);
      }
    }
    return base64Encode(bytes);
  }
}
