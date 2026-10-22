import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Turns a question spoken to Trok into words, with the phone's own speech
/// recognition. gramX keeps no recording; only the words reach Trok, when
/// the reader sends them.
abstract interface class TrokVoice {
  /// Starts listening, in [language] (`am` or `en`) when the phone can hear
  /// it, else in the phone's own language. [onWords] gets the words heard so
  /// far each time they change, and `done` once listening has ended. False
  /// when the phone can't listen, or the reader didn't allow it.
  Future<bool> listen({
    required String language,
    required void Function(String words, bool done) onWords,
  });

  /// Stops listening and keeps the words heard.
  Future<void> stop();
}

class DeviceTrokVoice implements TrokVoice {
  final _speech = SpeechToText();
  bool _ready = false;
  void Function(String words, bool done)? _onWords;

  /// A pause this long ends the question.
  static const _pause = Duration(seconds: 3);

  /// The longest question listened to.
  static const _longest = Duration(minutes: 1);

  /// Asks for the microphone and speech recognition the first time. A
  /// refusal isn't kept, so the reader can allow it and try again.
  Future<bool> _init() async {
    if (_ready) return true;
    return _ready = await _speech.initialize(
      onError: _error,
      onStatus: _status,
    );
  }

  @override
  Future<bool> listen({
    required String language,
    required void Function(String words, bool done) onWords,
  }) async {
    try {
      if (!await _init()) return false;
      _onWords = onWords;
      await _speech.listen(
        onResult: _result,
        listenOptions: SpeechListenOptions(
          localeId: await _localeFor(language),
          listenMode: ListenMode.dictation,
          partialResults: true,
          pauseFor: _pause,
          listenFor: _longest,
          cancelOnError: true,
        ),
      );
      return true;
    } on Object catch (e) {
      debugPrint('[Trok] could not listen: $e');
      _ready = false;
      return false;
    }
  }

  @override
  Future<void> stop() => _speech.stop();

  /// The phone's locale for [language], if it has one.
  Future<String?> _localeFor(String language) async {
    final system = await _speech.systemLocale();
    if (system != null && system.localeId.startsWith(language)) {
      return system.localeId;
    }
    for (final locale in await _speech.locales()) {
      if (locale.localeId.toLowerCase().startsWith(language)) {
        return locale.localeId;
      }
    }
    return system?.localeId;
  }

  void _result(SpeechRecognitionResult result) =>
      _onWords?.call(result.recognizedWords, result.finalResult);

  void _status(String status) {
    if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      final onWords = _onWords;
      _onWords = null;
      onWords?.call(_speech.lastRecognizedWords, true);
    }
  }

  void _error(SpeechRecognitionError error) {
    debugPrint('[Trok] listening failed: ${error.errorMsg}');
    final onWords = _onWords;
    _onWords = null;
    onWords?.call(_speech.lastRecognizedWords, true);
  }
}

final trokVoiceProvider = Provider<TrokVoice>((ref) => DeviceTrokVoice());
