import 'tts_voice_option.dart';

abstract class TtsRepository {
  Future<void> speak(String text, String languageCode, {String? voiceName});

  Future<void> stop();

  Future<List<TtsVoiceOption>> getVoices(String languageCode);

  void onStart(void Function() callback);

  void onComplete(void Function() callback);

  void onError(void Function(String message) callback);
}
