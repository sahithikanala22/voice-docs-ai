/// Modular extension point for speech recognition backends.
///
/// The app ships [OnDeviceSpeechProvider] (native OS speech recognizer, free,
/// offline, wired by default). To switch to a paid cloud engine, implement
/// this interface (see `cloud_speech_provider_stub.dart`) and override
/// `speechProviderImplProvider` in `speech_providers.dart` — nothing else in
/// the app needs to change, since [SpeechRepositoryImpl] only depends on this
/// abstraction.
abstract class SpeechProvider {
  /// Requests the underlying engine/permissions and reports whether speech
  /// recognition can be used on this device.
  Future<bool> initialize();

  /// Starts a listening session for [localeCode] (e.g. `en-US`).
  ///
  /// [onResult] is invoked with each partial/final transcript as the user
  /// speaks (real-time updates). [onSoundLevel] is invoked with a rough
  /// microphone amplitude, used to animate the mic button.
  Future<void> startListening({
    required String localeCode,
    required void Function(String transcript, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
    required void Function(String message) onError,
  });

  Future<void> stopListening();

  Future<void> cancel();

  bool get isListening;
}
