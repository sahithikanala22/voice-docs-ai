import '../../domain/translation_result.dart';

/// Modular extension point for translation backends, mirroring
/// [SpeechProvider]'s pattern. [FreeGoogleTranslationProvider] (unofficial,
/// free, no API key) is wired by default; a paid Cloud Translation API can
/// be dropped in later by implementing this interface.
abstract class TranslationProvider {
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  });
}
