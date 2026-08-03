import '../../domain/translation_result.dart';
import 'translation_provider.dart';

/// Documented extension point for a paid Cloud Translation API — NOT wired
/// up by default. This app ships with [FreeGoogleTranslationProvider]
/// instead, per the on-device/free provider strategy.
///
/// To activate a cloud engine:
/// 1. Add an HTTP client call (e.g. via the existing `dio` dependency) to
///    your provider's REST endpoint, or its official SDK package.
/// 2. Implement [translate] below, mapping the response into
///    [TranslationResult].
/// 3. Store the API key securely (e.g. via `--dart-define`) and read it here.
/// 4. Override `translationProviderImplProvider` in
///    `translation/presentation/providers/translation_providers.dart` to
///    return this class instead of [FreeGoogleTranslationProvider].
class CloudTranslationProviderStub implements TranslationProvider {
  @override
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) {
    throw UnimplementedError(
      'Wire up your cloud translation API key and HTTP client here.',
    );
  }
}
