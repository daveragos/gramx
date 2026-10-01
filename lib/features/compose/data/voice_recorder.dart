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
  /// The user or the OS denied microphone access.
  noPermission,

  /// The platform refused for some other reason.
  unavailable,
}

/// Records a voice message as a [ComposeAttachment]. The waveform Telegram
/// sends with it is sampled from the amplitude while recording, rather than
/// decoded from the Opus file afterwards.
class VoiceRecorder {
  /// How often the amplitude is sampled. [VoiceWaveform.downsample] reduces
  /// the samples to the size Telegram uses.
  static const Duration sampleInterval = Duration(milliseconds: 100);

  /// Maximum recording length, so a forgotten recording doesn't run on.
  static const Duration maxDuration = Duration(minutes: 10);

  final AudioRecorder _recorder;

  VoiceRecorder({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  StreamSubscription<Amplitude>? _amplitudes;
  final List<double> _decibels = [];
  DateTime? _startedAt;
  String? _path;

  /// Amplitudes captured so far, newest last, in Telegram's 0 to 31 range.
  List<int> get liveWaveform => VoiceWaveform.fromDecibels(_decibels);

  bool get isRecording => _startedAt != null;

  /// How long the current recording has been running.
  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  /// Starts recording. Returns null on success, or the reason it failed.
  /// Microphone permission is requested here, when the user starts recording.
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
          // `inputMessageVoiceNote` expects Opus in OGG; other formats are
          // shown as an audio file rather than a voice message.
          encoder: AudioEncoder.opus,
          // Mono at 48 kHz, matching Telegram's voice settings.
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

  /// Stops and returns the recording. Null when nothing was recorded or the
  /// file is empty, which Telegram would otherwise send as silence.
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
      // At least a second; a zero duration draws as an empty player.
      durationSeconds: seconds < 1 ? 1 : seconds,
      sizeBytes: size,
      waveform: samples,
    );
  }

  /// Stops and deletes the recording.
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
