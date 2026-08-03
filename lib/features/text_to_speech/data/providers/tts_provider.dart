/// Modular extension point for text-to-speech backends, mirroring
/// [SpeechProvider]'s pattern. [DeviceTtsProvider] (native OS TTS engine) is
/// wired by default; a cloud voice API can be dropped in later by
/// implementing this interface.
abstract class TtsProvider {
  Future<void> speak(String text, String languageCode);

  Future<void> stop();

  void onStart(void Function() callback);

  void onComplete(void Function() callback);

  void onError(void Function(String message) callback);
}
