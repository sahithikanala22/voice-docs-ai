import '../../domain/tts_voice_option.dart';

/// Modular extension point for text-to-speech backends, mirroring
/// [SpeechProvider]'s pattern. [DeviceTtsProvider] (native OS TTS engine) is
/// wired by default; a cloud voice API can be dropped in later by
/// implementing this interface.
abstract class TtsProvider {
  /// [voiceName] is one of [TtsVoiceOption.name] from [getVoices] for this
  /// same [languageCode] — null uses whatever the platform's default voice
  /// is for that language. An unrecognized name is ignored rather than
  /// erroring, falling back to the default voice.
  Future<void> speak(String text, String languageCode, {String? voiceName});

  Future<void> stop();

  /// Lists the voices the device's TTS engine offers for [languageCode]
  /// (matched the same tolerant way speech recognition resolves locales —
  /// exact match first, then same primary subtag).
  Future<List<TtsVoiceOption>> getVoices(String languageCode);

  void onStart(void Function() callback);

  void onComplete(void Function() callback);

  void onError(void Function(String message) callback);
}
