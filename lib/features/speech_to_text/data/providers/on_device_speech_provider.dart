import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'speech_provider.dart';

/// Default [SpeechProvider]: wraps the `speech_to_text` plugin, which talks
/// to the native OS speech recognizer (Android `SpeechRecognizer`, iOS
/// `Speech` framework). Free, no API key, works offline where the OS engine
/// supports it.
class OnDeviceSpeechProvider implements SpeechProvider {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  void Function(String message)? _currentOnError;

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (SpeechRecognitionError error) => _currentOnError?.call(error.errorMsg),
      onStatus: (_) {},
    );
    return _initialized;
  }

  @override
  Future<void> startListening({
    required String localeCode,
    required void Function(String transcript, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
    required void Function(String message) onError,
  }) async {
    _currentOnError = onError;

    if (!_initialized) {
      final ok = await initialize();
      if (!ok) {
        onError('Speech recognition is not available on this device.');
        return;
      }
    }

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      onSoundLevelChange: onSoundLevel,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
        localeId: localeCode,
      ),
    );
  }

  @override
  Future<void> stopListening() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();

  @override
  bool get isListening => _speech.isListening;
}
