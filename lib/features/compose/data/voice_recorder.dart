import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/voice_waveform.dart';

/// Why a recording could not start.
enum VoiceRecordFailure {
  /// The reader declined the microphone, or the OS did.
  noPermission,

  /// The platform refused for some other reason.
  unavailable,
}

/// Records a voice message.
///
/// Owns the platform recorder and the amplitude sampling, and hands back a
/// [ComposeAttachment] the ordinary send path already knows how to upload —
/// which is the point: a voice note is a file with a duration and a waveform,
/// and everything after `stop()` is the same code that sends a photo.
///
/// **The waveform is captured while recording, not derived afterwards.**
/// Telegram carries the bars with the message and every client draws what it
/// is given, so a voice note sent without them is a flat grey bar for whoever
/// receives it. Reading them back off the encoded file would mean decoding
/// Opus on the phone; sampling the amplitude the recorder is already reporting
/// costs nothing and is what the bars actually describe.
class VoiceRecorder {
  /// How often the amplitude is sampled.
  ///
  /// Ten a second: fine enough that a word is two or three bars, coarse enough
  /// that a minute of speech is 600 samples rather than tens of thousands —
  /// and [VoiceWaveform.downsample] takes it the rest of the way to the 100
  /// Telegram draws.
  static const Duration sampleInterval = Duration(milliseconds: 100);

  /// The longest voice message gramX will record.
  ///
  /// Not Telegram's limit — it has none worth naming — but a recorder that runs
  /// until the phone fills up is a bug waiting for somebody to put their phone
  /// in a pocket. Stops itself and keeps what it has, rather than discarding.
  static const Duration maxDuration = Duration(minutes: 10);

  final AudioRecorder _recorder;

  VoiceRecorder({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  StreamSubscription<Amplitude>? _amplitudes;
  final List<double> _decibels = [];
  DateTime? _startedAt;
  String? _path;

  /// Amplitudes captured so far, newest last, already in Telegram's 0–31
  /// range. What the composer draws live.
  List<int> get liveWaveform => VoiceWaveform.fromDecibels(_decibels);

  bool get isRecording => _startedAt != null;

  /// How long the current recording has been running.
  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  /// Starts recording. Returns null on success, or why it could not.
  ///
  /// The microphone is asked for **here** — at the moment somebody taps the
  /// record button — and nowhere else. A permission dialog at launch, with no
  /// context for what it is about, is the one every reader declines.
  Future<VoiceRecordFailure?> start() async {
    if (isRecording) return null;

    try {
      if (!await _recorder.hasPermission()) {
        return VoiceRecordFailure.noPermission;
      }

      final directory = await getTemporaryDirectory();
      final path = p.join(
        directory.path,
        'voice_${DateTime.now().millisecondsSinceEpoch}.ogg',
      );

      await _recorder.start(
        const RecordConfig(
          // Opus in an OGG container is what `inputMessageVoiceNote` wants.
          // Anything else is accepted by Telegram and then shown by every
          // client as an audio *file* — a row with a filename — rather than as
          // a voice message with a waveform and a play head.
          encoder: AudioEncoder.opus,
          // Telegram's own voice settings. Mono at 48 kHz is what Opus is
          // designed around, and a second channel doubles the size of a
          // recording of one person talking for no gain.
          numChannels: 1,
          sampleRate: 48000,
          bitRate: 32000,
        ),
        path: path,
      );

      _path = path;
      _decibels.clear();
      _startedAt = DateTime.now();
      _amplitudes = _recorder
          .onAmplitudeChanged(sampleInterval)
          .listen((amplitude) => _decibels.add(amplitude.current));
      return null;
    } catch (e) {
      debugPrint('[VoiceRecorder] start failed: $e');
      await _reset();
      return VoiceRecordFailure.unavailable;
    }
  }

  /// Stops and returns what was recorded, ready to send.
  ///
  /// Null when there is nothing worth sending: no recording running, the
  /// platform gave back no file, or the file is empty. A zero-byte voice note
  /// is accepted by Telegram and plays as silence, which is worse than nothing
  /// having been sent.
  Future<ComposeAttachment?> stop() async {
    if (!isRecording) return null;

    final seconds = elapsed.inSeconds;
    final samples = VoiceWaveform.downsample(liveWaveform);

    String? path;
    try {
      path = await _recorder.stop();
    } catch (e) {
      debugPrint('[VoiceRecorder] stop failed: $e');
    }
    await _reset();

    path ??= _path;
    if (path == null) return null;

    final size = await _sizeOf(path);
    if (size <= 0) return null;

    return ComposeAttachment(
      path: path,
      kind: ComposeMediaKind.voiceNote,
      width: 0,
      height: 0,
      // At least a second. A recording of 800 ms reports zero, and a voice note
      // whose duration is zero draws as an empty player in every client.
      durationSeconds: seconds < 1 ? 1 : seconds,
      sizeBytes: size,
      waveform: samples,
    );
  }

  /// Stops and throws the recording away, file and all.
  Future<void> cancel() async {
    if (!isRecording) return;
    try {
      await _recorder.cancel();
    } catch (e) {
      debugPrint('[VoiceRecorder] cancel failed: $e');
    }
    final path = _path;
    await _reset();
    if (path != null) await _delete(path);
  }

  Future<void> dispose() async {
    await _amplitudes?.cancel();
    _amplitudes = null;
    await _recorder.dispose();
  }

  Future<void> _reset() async {
    await _amplitudes?.cancel();
    _amplitudes = null;
    _startedAt = null;
  }

  static Future<int> _sizeOf(String path) async {
    try {
      return await File(path).length();
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _delete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[VoiceRecorder] could not delete $path: $e');
    }
  }
}
