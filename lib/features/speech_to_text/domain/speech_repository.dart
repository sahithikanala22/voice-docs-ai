/// Domain-facing contract for turning speech into text. Presentation code
/// depends on this, never on [SpeechProvider] or the `speech_to_text`
/// package directly.
abstract class SpeechRepository {
  Future<bool> initialize();

  Future<void> startListening({
    required String localeCode,
    required void Function(String transcript, bool isFinal) onResult,
    required void Function(double level) onSoundLevel,
    required void Function(String message) onError,
  });

  Future<void> stopListening();

  Future<void> cancel();

  bool get isListening;
}
