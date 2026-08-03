import 'speech_provider.dart';

/// Documented extension point for a paid, cloud-based speech recognizer
/// (e.g. Google Cloud Speech-to-Text streaming recognize) — NOT wired up by
/// default. This app ships with [OnDeviceSpeechProvider] instead, per the
/// on-device/free provider strategy.
///
/// To activate a cloud engine:
/// 1. Add the relevant SDK/HTTP client to `pubspec.yaml` (e.g. `googleapis`
///    or plain `dio` calls to the REST endpoint).
/// 2. Implement each method below using your provider's streaming or
///    chunked-audio recognize API, keeping the same [SpeechProvider]
///    contract so the rest of the app is untouched.
/// 3. Store the API key securely (e.g. via `--dart-define`, not committed to
///    source control) and read it in [initialize].
/// 4. Override `speechProviderImplProvider` in
///    `speech_to_text/presentation/providers/speech_providers.dart` to
///    return this class instead of [OnDeviceSpeechProvider].
class CloudSpeechProviderStub implements SpeechProvider {
  @override
  Future<bool> initialize() async {
    throw UnimplementedError(
      'Wire up your cloud speech API key and streaming client here.',
    );
  }

  @override
  Future<void> startListening({
    required String localeCode,
    required void Function(String transcript, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
    required void Function(String message) onError,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> stopListening() async => throw UnimplementedError();

  @override
  Future<void> cancel() async => throw UnimplementedError();

  @override
  bool get isListening => false;
}
