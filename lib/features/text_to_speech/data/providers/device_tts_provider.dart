import 'package:flutter_tts/flutter_tts.dart';

import 'tts_provider.dart';

/// Default [TtsProvider]: wraps `flutter_tts`, which talks to the native OS
/// text-to-speech engine on every platform. Free, no API key, fully offline.
class DeviceTtsProvider implements TtsProvider {
  DeviceTtsProvider() {
    _tts.setSpeechRate(0.48);
    _tts.setPitch(1.0);
  }

  final FlutterTts _tts = FlutterTts();

  @override
  Future<void> speak(String text, String languageCode) async {
    await _tts.setLanguage(languageCode);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  void onStart(void Function() callback) => _tts.setStartHandler(callback);

  @override
  void onComplete(void Function() callback) => _tts.setCompletionHandler(callback);

  @override
  void onError(void Function(String message) callback) {
    _tts.setErrorHandler((dynamic message) => callback(message.toString()));
  }
}
