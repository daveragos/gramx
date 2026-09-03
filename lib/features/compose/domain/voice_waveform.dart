import 'dart:convert';
import 'dart:typed_data';

/// The bars drawn under a voice message.
///
/// Telegram carries the waveform *with* the message rather than deriving it,
/// and every client draws what it is given — so a voice note sent without one
/// is a flat grey bar for the person who receives it, in every Telegram client
/// there is. It is the difference between a voice message and an audio file
/// with a play button.
///
/// The encoding is TDLib's: amplitudes packed at **five bits each**, little
/// end first, then base64. Five bits means each sample is 0–31, and the
/// packing crosses byte boundaries — sample 1 occupies the top three bits of
/// byte 0 and the bottom two of byte 1 — which is the part that is easy to get
/// silently wrong and produces bars that look like noise.
///
/// Pure and self-contained so the packing can be tested against known bytes
/// rather than by sending a voice message and looking at it.
abstract class VoiceWaveform {
  /// How many bars Telegram's own clients draw. Longer recordings are
  /// downsampled to this; shorter ones are sent as they are.
  static const int sampleCount = 100;

  /// The largest value five bits can hold.
  static const int maxAmplitude = 31;

  /// Squeezes a run of amplitudes down to at most [sampleCount].
  ///
  /// Takes the **peak** of each bucket rather than the mean. A voice recording
  /// averaged over its buckets flattens into a low ridge; the peaks are what
  /// make speech look like speech.
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

  /// Turns decibel readings into the 0–31 range Telegram uses.
  ///
  /// [dbfs] is what a recorder reports: 0 at full scale and negative below it.
  /// Anything under [floor] is silence as far as a voice note is concerned —
  /// clamping there rather than at the true noise floor is what keeps a quiet
  /// room from drawing as a wall of half-height bars.
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
  ///
  /// An empty list encodes to an empty string, which is TDLib's own spelling of
  /// "no waveform" — not a zero-length one.
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
